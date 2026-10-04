//
//  VoiceRecorder.swift
//  Phbank
//
//  Records a short mono WAV (16 kHz, 16-bit) — a format Gemini accepts directly.
//

import AVFoundation
import Observation

@Observable
final class VoiceRecorder {
    static let maxDuration: TimeInterval = 60
    static var idleMessage: String { String(localized: "Tap record and say what you spent, e.g. “Rewe, 23 euros, groceries, yesterday”.") }

    var recordingURL: URL?
    var isRecording = false
    var statusMessage = VoiceRecorder.idleMessage

    private var recorder: AVAudioRecorder?
    private var autoStop: Task<Void, Never>?

    func toggle() async {
        if isRecording { stop() } else { await start() }
    }

    func start() async {
        discard()
        let granted = await AVAudioApplication.requestRecordPermission()
        guard granted else {
            statusMessage = String(localized: "Microphone access is off. Turn it on in Settings → Privacy → Microphone.")
            return
        }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .default)
            try session.setActive(true)

            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("voice-\(UUID().uuidString).wav")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: 16_000,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false
            ]
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            guard recorder.record() else {
                statusMessage = String(localized: "Recording could not start.")
                return
            }
            self.recorder = recorder
            recordingURL = url
            isRecording = true
            statusMessage = String(localized: "Recording… tap again to finish (max. \(Int(Self.maxDuration)) s).")

            autoStop = Task { [weak self] in
                try? await Task.sleep(for: .seconds(Self.maxDuration))
                guard !Task.isCancelled else { return }
                self?.stop()
            }
        } catch {
            statusMessage = String(localized: "Recording failed: \(error.localizedDescription)")
        }
    }

    func stop() {
        autoStop?.cancel()
        autoStop = nil
        recorder?.stop()
        recorder = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false)
        if recordingURL != nil {
            statusMessage = String(localized: "Recording ready. Tap “Analyse with Gemini”.")
        }
    }

    /// Stops and deletes any recording that has not been handed off.
    func discard() {
        if isRecording { stop() }
        if let url = recordingURL { try? FileManager.default.removeItem(at: url) }
        recordingURL = nil
        statusMessage = Self.idleMessage
    }
}
