//
//  TabBar.swift
//  Phbank
//
//  Floating bottom bar + the branded loading overlay.
//

import SwiftUI

struct LiquidGlassTabBar: View {
    var onSettings: () -> Void
    var onSearch: () -> Void
    var onVoice: () -> Void
    var onScan: () -> Void
    var onSummary: () -> Void
    var onToday: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            TabBarButton(icon: "gearshape", label: "Settings", id: "tab-settings", action: onSettings)
            Spacer(minLength: 0)
            TabBarButton(icon: "magnifyingglass", label: "Search", id: "tab-search", action: onSearch)
            Spacer(minLength: 0)
            TabBarButton(icon: "mic.fill", label: "Voice note", id: "tab-voice", action: onVoice)
            Spacer(minLength: 0)
            TabBarButton(icon: "camera.viewfinder", label: "Scan or import", id: "tab-scan", action: onScan)
            Spacer(minLength: 0)
            TabBarButton(icon: "chart.pie", label: "Summary", id: "tab-summary", action: onSummary)
            Spacer(minLength: 0)
            TabBarButton(icon: "calendar.day.timeline.left", label: "Jump to today", id: "tab-today", action: onToday)
        }
        .padding(.horizontal, 14)
        .frame(height: 64)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(JournalTheme.gold.opacity(0.45), lineWidth: 0.75))
        .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 10)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .environment(\.colorScheme, .dark)
    }
}

struct TabBarButton: View {
    let icon: String
    let label: LocalizedStringKey
    let id: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(JournalTheme.ivory)
                .frame(width: 46, height: 46)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
        .accessibilityIdentifier(id)
    }
}

struct PHLoadingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 25) {
                ZStack {
                    Text("PH")
                        .font(JournalTheme.classicBold(30, relativeTo: .title))
                        .kerning(3)
                        .foregroundStyle(JournalTheme.ivory)

                    Circle()
                        .trim(from: 0.0, to: 0.3)
                        .stroke(JournalTheme.gold, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(rotation))

                    Circle()
                        .trim(from: 0.5, to: 0.8)
                        .stroke(JournalTheme.gold.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(rotation))
                }
                Text("Analysing with Gemini…")
                    .font(JournalTheme.classic(16, relativeTo: .callout))
                    .foregroundStyle(JournalTheme.ivory.opacity(0.85))
            }
        }
        .contentShape(Rectangle()) // blocks taps while processing
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Analysing with Gemini")
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) { rotation = 360 }
        }
    }
}

struct LockScreenView: View {
    let lock: AppLock

    var body: some View {
        ZStack {
            JournalTheme.shell.ignoresSafeArea()
            VStack(spacing: 28) {
                ZStack {
                    Circle().stroke(JournalTheme.gold, lineWidth: 1.5).frame(width: 96, height: 96)
                    Text("PH")
                        .font(JournalTheme.classicBold(34, relativeTo: .largeTitle))
                        .kerning(3)
                        .foregroundStyle(JournalTheme.ivory)
                }
                .accessibilityHidden(true)

                Text("PHINANZ")
                    .font(JournalTheme.classicBold(28, relativeTo: .title))
                    .kerning(4)
                    .foregroundStyle(JournalTheme.ivory)

                Button {
                    Task { await lock.unlock() }
                } label: {
                    Label("Unlock", systemImage: "faceid")
                        .font(JournalTheme.classicBold(18, relativeTo: .headline))
                        .foregroundStyle(JournalTheme.shell)
                        .padding(.horizontal, 28)
                        .frame(minHeight: 48)
                        .background(JournalTheme.gold, in: Capsule())
                }
                .opacity(lock.isLocked ? 1 : 0) // hidden when only the privacy cover is shown
                .accessibilityIdentifier("unlock-button")
            }
        }
    }
}
