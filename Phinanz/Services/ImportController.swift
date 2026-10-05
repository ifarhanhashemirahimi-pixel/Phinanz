//
//  ImportController.swift
//  Phinanz
//
//  Drives voice / receipt / PDF imports — Apple Intelligence on the iPhone
//  first, Google Gemini as the fallback (consent + API key) — and bank CSV
//  imports (on the device), and hands the suggested entries to the review
//  sheet. Nothing is saved automatically.
//

import Foundation
import Observation
import UIKit

/// What an AI import reads: the original file for Gemini, plus what the
/// on-device readers need.
enum ImportPayload {
    case audio(url: URL, data: Data)
    case image(UIImage, jpeg: Data)
    case pdf(Data)

    var geminiAttachment: GeminiAttachment {
        switch self {
        case .audio(_, let data): GeminiAttachment(mimeType: "audio/wav", data: data)
        case .image(_, let jpeg): GeminiAttachment(mimeType: "image/jpeg", data: jpeg)
        case .pdf(let data): GeminiAttachment(mimeType: "application/pdf", data: data)
        }
    }
}

enum GeminiReadiness {
    /// The first thing that prevents using Gemini, or nil when ready.
    static func issue() -> GeminiError? {
        if !UserDefaults.standard.bool(forKey: SettingsKeys.aiConsent) { return .consentRequired }
        let key = KeychainStore.get(SettingsKeys.apiKeyAccount) ?? ""
        if key.isEmpty { return .missingAPIKey }
        return nil
    }
}

@Observable
final class ImportController {
    enum Phase: Equatable {
        case idle
        case processing
        case failed(String)
    }

    /// Where the entries on the review screen came from.
    enum Origin: Equatable {
        case ai, bankFile
    }

    var phase: Phase = .idle
    var drafts: [DraftExpense] = []
    var showReview = false
    var origin: Origin = .ai
    /// Which AI is reading right now (for the progress overlay).
    var activeEngine: AIEngine = .apple

    var failureMessage: String {
        if case let .failed(message) = phase { return message }
        return ""
    }

    func dismissError() {
        if case .failed = phase { phase = .idle }
    }

    // MARK: Entry points

    func processVoice(url: URL, fallbackDate: Date) async {
        defer { try? FileManager.default.removeItem(at: url) } // recordings never stay on disk
        guard let data = try? Data(contentsOf: url) else {
            phase = .failed(String(localized: "The recording could not be read."))
            return
        }
        await process(kind: .voice, payload: .audio(url: url, data: data), fallbackDate: fallbackDate)
    }

    func processImage(_ image: UIImage, fallbackDate: Date) async {
        guard let data = Self.jpegData(from: image) else {
            phase = .failed(String(localized: "The image could not be prepared."))
            return
        }
        await process(kind: .receipt, payload: .image(image, jpeg: data), fallbackDate: fallbackDate)
    }

    func processPDF(url: URL, fallbackDate: Date) async {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            phase = .failed(String(localized: "The PDF could not be read."))
            return
        }
        await process(kind: .statement, payload: .pdf(data), fallbackDate: fallbackDate)
    }

    /// Bank CSV export: read on the device — no AI, no network, no API key needed.
    func processBankCSV(url: URL, history: [Expense]) {
        origin = .bankFile
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            guard let data = try? Data(contentsOf: url) else { throw BankCSVImporter.ImportError.unreadable }
            let bookings = try BankCSVImporter.bookings(in: data)
            drafts = BankCSVImporter.drafts(from: bookings, history: history)
            phase = .idle
            showReview = true
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    // MARK: Core

    private func process(kind: ImportKind, payload: ImportPayload, fallbackDate: Date) async {
        origin = .ai
        let engines = AIReadiness.engines(for: AITask(kind))
        guard !engines.isEmpty else {
            phase = .failed(AIReadiness.issue(for: AITask(kind))?.localizedDescription ?? String(localized: "No AI is set up yet."))
            return
        }

        phase = .processing
        var lastError: Error?
        // Apple Intelligence first (on the iPhone); Gemini only if that fails and is allowed.
        for engine in engines {
            activeEngine = engine
            do {
                let parsed: [ParsedExpense]
                switch engine {
                case .apple:
                    parsed = try await AppleIntelligence.extract(kind: kind, payload: payload)
                case .gemini:
                    let apiKey = KeychainStore.get(SettingsKeys.apiKeyAccount) ?? ""
                    let storedModel = UserDefaults.standard.string(forKey: SettingsKeys.geminiModel) ?? ""
                    let model = storedModel.isEmpty ? GeminiService.defaultModel : storedModel
                    parsed = try await GeminiService(apiKey: apiKey, model: model)
                        .extractExpenses(kind: kind, attachment: payload.geminiAttachment)
                }
                guard !parsed.isEmpty else { continue }
                drafts = parsed.map { DraftExpense(parsed: $0, source: kind.source, fallbackDate: fallbackDate) }
                phase = .idle
                showReview = true
                return
            } catch {
                lastError = error
            }
        }
        var message = lastError?.localizedDescription ?? String(localized: "No entries were found in this \(kind.label).")
        if lastError is AppleAIError, !engines.contains(.gemini) {
            message += " " + String(localized: "You can set up Google Gemini in Settings as a fallback.")
        }
        phase = .failed(message)
    }

    /// Downscales large photos so the request stays small and fast.
    /// `maxDimension` is measured in pixels.
    static func jpegData(from image: UIImage, maxDimension: CGFloat = 2000, quality: CGFloat = 0.7) -> Data? {
        let pixelSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let longest = max(pixelSize.width, pixelSize.height)
        guard longest > 0 else { return nil }
        if longest <= maxDimension { return image.jpegData(compressionQuality: quality) }

        let ratio = maxDimension / longest
        let target = CGSize(width: (pixelSize.width * ratio).rounded(), height: (pixelSize.height * ratio).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1 // target is in pixels, not points
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: target)) }
        return resized.jpegData(compressionQuality: quality)
    }
}
