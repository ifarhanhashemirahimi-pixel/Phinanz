//
//  VoiceInputView.swift
//  Phinanz
//
//  Voice note capture in the style of Voice Memos.
//

import SwiftUI

struct VoiceInputView: View {
    @Environment(\.dismiss) private var dismiss

    let importer: ImportController
    let fallbackDate: Date

    @State private var recorder = VoiceRecorder()
    @State private var issue = AIReadiness.issue(for: .voice)
    @State private var onDevice = AIReadiness.engines(for: .voice).first == .apple
    @State private var handedOff = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let issue { AISetupBanner(issue: issue) }

                Spacer(minLength: 0)

                Image(systemName: "waveform")
                    .font(.system(size: 54, weight: .light))
                    .foregroundStyle(recorder.isRecording ? Color.red : Color.secondary)
                    .symbolEffect(.variableColor.iterative, isActive: recorder.isRecording)
                    .accessibilityHidden(true)

                Text(recorder.statusMessage)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 320)

                Button {
                    Task { await recorder.toggle() }
                } label: {
                    ZStack {
                        Circle()
                            .strokeBorder(Color.secondary.opacity(0.4), lineWidth: 4)
                            .frame(width: 84, height: 84)
                        RoundedRectangle(cornerRadius: recorder.isRecording ? 8 : 34, style: .continuous)
                            .fill(Color.red)
                            .frame(width: recorder.isRecording ? 32 : 68, height: recorder.isRecording ? 32 : 68)
                    }
                    .animation(.spring(duration: 0.3), value: recorder.isRecording)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(recorder.isRecording ? Text("Stop Recording") : Text("Start Recording"))
                .accessibilityIdentifier("record-button")
                .sensoryFeedback(.impact, trigger: recorder.isRecording)

                Spacer(minLength: 0)

                Button(action: analyse) {
                    Label(onDevice ? LocalizedStringKey("Analyse on This iPhone") : LocalizedStringKey("Analyse with Gemini"),
                          systemImage: onDevice ? "apple.intelligence" : "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(recorder.recordingURL == nil || recorder.isRecording || issue != nil)
            }
            .padding(24)
            .navigationTitle("Voice Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                issue = AIReadiness.issue(for: .voice)
                onDevice = AIReadiness.engines(for: .voice).first == .apple
            }
            .onDisappear { if !handedOff { recorder.discard() } }
        }
        .presentationDetents([.medium, .large])
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
