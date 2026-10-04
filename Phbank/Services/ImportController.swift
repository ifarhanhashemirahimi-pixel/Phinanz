//
//  ImportController.swift
//  Phbank
//
//  Drives voice / receipt / PDF imports: checks consent + API key, calls Gemini,
//  and hands the suggested entries to the review sheet. Nothing is saved
//  automatically.
//

import Foundation
import Observation
import UIKit

enum AIReadiness {
    /// The first thing that prevents an AI import, or nil when ready.
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

    var phase: Phase = .idle
    var drafts: [DraftExpense] = []
    var showReview = false

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
        await process(kind: .voice, attachment: GeminiAttachment(mimeType: "audio/wav", data: data), fallbackDate: fallbackDate)
    }

    func processImage(_ image: UIImage, fallbackDate: Date) async {
        guard let data = Self.jpegData(from: image) else {
            phase = .failed(String(localized: "The image could not be prepared."))
            return
        }
        await process(kind: .receipt, attachment: GeminiAttachment(mimeType: "image/jpeg", data: data), fallbackDate: fallbackDate)
    }

    func processPDF(url: URL, fallbackDate: Date) async {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            phase = .failed(String(localized: "The PDF could not be read."))
            return
        }
        await process(kind: .statement, attachment: GeminiAttachment(mimeType: "application/pdf", data: data), fallbackDate: fallbackDate)
    }

    // MARK: Core

    private func process(kind: ImportKind, attachment: GeminiAttachment, fallbackDate: Date) async {
        if let issue = AIReadiness.issue() {
            phase = .failed(issue.localizedDescription)
            return
        }
        let apiKey = KeychainStore.get(SettingsKeys.apiKeyAccount) ?? ""
        let storedModel = UserDefaults.standard.string(forKey: SettingsKeys.geminiModel) ?? ""
        let model = storedModel.isEmpty ? GeminiService.defaultModel : storedModel

        phase = .processing
        do {
            let service = GeminiService(apiKey: apiKey, model: model)
            let parsed = try await service.extractExpenses(kind: kind, attachment: attachment)
            guard !parsed.isEmpty else {
                phase = .failed(String(localized: "No entries were found in this \(kind.label)."))
                return
            }
            drafts = parsed.map { DraftExpense(parsed: $0, source: kind.source, fallbackDate: fallbackDate) }
            phase = .idle
            showReview = true
        } catch {
            phase = .failed(error.localizedDescription)
        }
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
