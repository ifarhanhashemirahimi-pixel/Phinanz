//
//  OnDeviceReading.swift
//  Phinanz
//
//  Turns recordings, photos and PDFs into plain text on the iPhone — speech
//  recognition, Vision text recognition and PDFKit — so Apple Intelligence
//  can read them without anything leaving the device.
//

import Foundation
import Speech
import Vision
import PDFKit
import UIKit

enum OnDeviceReadingError: LocalizedError, Equatable {
    case speechUnavailable
    case speechNotAllowed
    case noText

    var errorDescription: String? {
        switch self {
        case .speechUnavailable:
            String(localized: "Speech recognition on this iPhone doesn't support this language yet.")
        case .speechNotAllowed:
            String(localized: "PHINANZ may not use speech recognition. Allow it in the iOS Settings app.")
        case .noText:
            String(localized: "No text was found.")
        }
    }
}

/// Speech to text, on the device only.
nonisolated enum OnDeviceSpeech {
    static func localeIdentifier(for languageCode: String) -> String {
        switch languageCode {
        case "de": "de-DE"
        case "fa": "fa-IR"
        default: "en-US"
        }
    }

    static func transcribe(url: URL, languageCode: String) async throws -> String {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier(for: languageCode))),
              recognizer.supportsOnDeviceRecognition
        else { throw OnDeviceReadingError.speechUnavailable }

        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard status == .authorized else { throw OnDeviceReadingError.speechNotAllowed }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = true // never Apple's servers
        request.shouldReportPartialResults = false
        request.addsPunctuation = true

        let text: String = try await withCheckedThrowingContinuation { continuation in
            let gate = ResumeGate()
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    if gate.claim() { continuation.resume(throwing: error) }
                } else if let result, result.isFinal {
                    if gate.claim() { continuation.resume(returning: result.bestTranscription.formattedString) }
                }
            }
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw OnDeviceReadingError.noText }
        return trimmed
    }
}

/// Resumes a continuation exactly once, whichever callback comes first.
nonisolated final class ResumeGate: @unchecked Sendable {
    private let lock = NSLock()
    private var used = false

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if used { return false }
        used = true
        return true
    }
}

/// Text recognition with Vision, on the device.
nonisolated enum OnDeviceOCR {
    static func text(in image: CGImage) async throws -> String {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = [Locale.Language(identifier: "de-DE"), Locale.Language(identifier: "en-US")]
        let observations = try await request.perform(on: image)
        return observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }

    static func text(in image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage ?? render(image) else { throw OnDeviceReadingError.noText }
        return try await text(in: cgImage)
    }

    private static func render(_ image: UIImage) -> CGImage? {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in image.draw(at: .zero) }.cgImage
    }
}

/// The text of a PDF statement: PDFKit for text PDFs, Vision for scanned pages.
nonisolated enum PDFText {
    static let maxPages = 12

    static func pages(in data: Data) async throws -> [String] {
        guard let document = PDFDocument(data: data) else { throw OnDeviceReadingError.noText }
        var pages: [String] = []
        for index in 0..<min(document.pageCount, maxPages) {
            guard let page = document.page(at: index) else { continue }
            let text = (page.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if text.count >= 20 {
                pages.append(text)
            } else if let image = page.thumbnail(of: CGSize(width: 1_600, height: 2_200), for: .mediaBox).cgImage {
                pages.append(try await OnDeviceOCR.text(in: image))
            }
        }
        guard pages.contains(where: { !$0.isEmpty }) else { throw OnDeviceReadingError.noText }
        return pages
    }

    /// Splits text into pieces of at most `limit` characters at line breaks,
    /// so each piece fits the on-device model's context window.
    static func chunks(_ text: String, limit: Int = 3_500) -> [String] {
        var result: [String] = []
        var current = ""
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            var rest = Substring(trimmed)
            while rest.count > limit {
                if !current.isEmpty { result.append(current); current = "" }
                result.append(String(rest.prefix(limit)))
                rest = rest.dropFirst(limit)
            }
            if !current.isEmpty && current.count + 1 + rest.count > limit {
                result.append(current)
                current = ""
            }
            current += current.isEmpty ? String(rest) : "\n" + rest
        }
        if !current.isEmpty { result.append(current) }
        return result
    }
}
