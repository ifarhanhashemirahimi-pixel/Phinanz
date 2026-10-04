//
//  VoiceInputView.swift
//  Phbank
//

import SwiftUI

struct AISetupBanner: View {
    let issue: GeminiError

    var body: some View {
        Label(issue.localizedDescription, systemImage: "exclamationmark.triangle.fill")
            .font(.footnote)
            .foregroundStyle(.primary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct VoiceInputView: View {
    @Environment(\.dismiss) private var dismiss

    let importer: ImportController
    let fallbackDate: Date

    @State private var recorder = VoiceRecorder()
    @State private var issue = AIReadiness.issue()
    @State private var handedOff = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let issue { AISetupBanner(issue: issue) }

                Spacer()

                Image(systemName: recorder.isRecording ? "waveform.circle.fill" : "mic.circle")
                    .font(.system(size: 80, weight: .ultraLight))
                    .foregroundStyle(recorder.isRecording ? Color.red : JournalTheme.gold)
                    .symbolEffect(.pulse, isActive: recorder.isRecording)
                    .accessibilityHidden(true)

                Text(recorder.statusMessage)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                Button {
                    Task { await recorder.toggle() }
                } label: {
                    Text(recorder.isRecording ? "Stop recording" : "Start recording")
                        .font(.headline)
                        .foregroundStyle(recorder.isRecording ? Color.white : JournalTheme.shell)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(recorder.isRecording ? JournalTheme.danger : JournalTheme.gold)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .accessibilityIdentifier("record-button")

                Button(action: analyse) {
                    Text("Analyse with Gemini")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Color.gray.opacity(0.25))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(recorder.recordingURL == nil || recorder.isRecording || issue != nil)

                Spacer()
            }
            .padding(24)
            .navigationTitle("Voice note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { issue = AIReadiness.issue() }
            .onDisappear { if !handedOff { recorder.discard() } }
        }
        .tint(JournalTheme.gold)
    }

    private func analyse() {
        guard let url = recorder.recordingURL else { return }
        handedOff = true
        let importer = importer
        let date = fallbackDate
        dismiss()
        Task { await importer.processVoice(url: url, fallbackDate: date) }
    }
}
