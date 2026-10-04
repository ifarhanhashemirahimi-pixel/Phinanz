//
//  Overlays.swift
//  Phbank
//
//  Lock screen, privacy cover and the "Analysing" HUD.
//

import SwiftUI

struct LockScreenView: View {
    let lock: AppLock

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 46, weight: .semibold))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text("PHINANZ Is Locked")
                    .font(.title2.bold())
                Text("Unlock to view your journal.")
                    .font(.body)
                    .foregroundStyle(.secondary)

                Button {
                    Task { await lock.unlock() }
                } label: {
                    Label("Unlock", systemImage: "faceid")
                        .frame(minWidth: 160)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 8)
                .opacity(lock.isLocked ? 1 : 0) // only the privacy cover while inactive
                .accessibilityIdentifier("unlock-button")
            }
            .padding(32)
        }
    }
}

struct AnalysingHUD: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.15).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)
                Text("Analysing…")
                    .font(.headline)
                Text("Gemini is reading your file")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .contentShape(Rectangle()) // block taps while processing
        .accessibilityElement(children: .combine)
    }
}

struct AISetupBanner: View {
    let issue: GeminiError

    var body: some View {
        Label {
            Text(issue.localizedDescription)
                .font(.footnote)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
