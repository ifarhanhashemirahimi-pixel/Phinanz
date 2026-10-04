//
//  OnboardingView.swift
//  Phbank
//
//  First-launch welcome: what PHINANZ is, privacy, and a short setup.
//

import SwiftUI

struct OnboardingView: View {
    var onFinish: () -> Void

    @AppStorage(SettingsKeys.startingBalance) private var startingBalance = 0.0
    @AppStorage(SettingsKeys.lockEnabled) private var lockEnabled = false

    @State private var page = 0
    @State private var balanceText = ""
    private let lockAvailable = AppLock.canAuthenticate

    var body: some View {
        ZStack {
            JournalTheme.shell.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    welcome.tag(0)
                    privacy.tag(1)
                    setup.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                Button(action: next) {
                    Text(page < 2 ? LocalizedStringKey("Continue") : LocalizedStringKey("Open my journal"))
                        .font(JournalTheme.classicBold(18, relativeTo: .headline))
                        .foregroundStyle(JournalTheme.shell)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(JournalTheme.gold, in: RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
                .accessibilityIdentifier("onboarding-continue")
            }
        }
        .foregroundStyle(JournalTheme.ivory)
        .tint(JournalTheme.gold)
    }

    // MARK: Pages

    private var welcome: some View {
        infoPage(
            icon: "book.closed.fill",
            title: "Your money, written like a diary",
            text: "PHINANZ gives every day of the year its own notebook page. Write down what you spend and earn, and see where your money goes."
        )
    }

    private var privacy: some View {
        infoPage(
            icon: "lock.shield",
            title: "Private by design",
            text: "Your journal stays on this iPhone. AI import with Google Gemini is optional, off by default, and only sends the file you choose."
        )
    }

    private var setup: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 54, weight: .thin))
                .foregroundStyle(JournalTheme.gold)
                .accessibilityHidden(true)
            Text("Quick setup")
                .font(JournalTheme.classicBold(28, relativeTo: .title))

            VStack(alignment: .leading, spacing: 8) {
                Text("Current account balance (optional)")
                    .font(.footnote)
                    .foregroundStyle(JournalTheme.ivory.opacity(0.7))
                HStack {
                    TextField("0,00", text: $balanceText)
                        .keyboardType(.numbersAndPunctuation)
                        .font(JournalTheme.classicBold(22, relativeTo: .title2))
                    Text(verbatim: "€")
                }
                .padding(14)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            }

            if lockAvailable {
                Toggle(isOn: lockBinding) {
                    Label("Protect with Face ID", systemImage: "faceid")
                }
                .padding(14)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            }
            Spacer()
        }
        .padding(.horizontal, 28)
        .environment(\.colorScheme, .dark)
    }

    private func infoPage(icon: String, title: LocalizedStringKey, text: LocalizedStringKey) -> some View {
        VStack(spacing: 22) {
            Spacer()
            ZStack {
                Circle().stroke(JournalTheme.gold, lineWidth: 1.5).frame(width: 120, height: 120)
                Image(systemName: icon)
                    .font(.system(size: 48, weight: .thin))
                    .foregroundStyle(JournalTheme.gold)
            }
            .accessibilityHidden(true)
            Text(title)
                .font(JournalTheme.classicBold(28, relativeTo: .title))
                .multilineTextAlignment(.center)
            Text(text)
                .font(JournalTheme.classic(17))
                .multilineTextAlignment(.center)
                .foregroundStyle(JournalTheme.ivory.opacity(0.8))
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: Actions

    private var lockBinding: Binding<Bool> {
        Binding(
            get: { lockEnabled },
            set: { newValue in
                if newValue {
                    Task {
                        if await AppLock.authenticate(reason: String(localized: "Turn on the PHINANZ lock")) {
                            lockEnabled = true
                        }
                    }
                } else {
                    lockEnabled = false
                }
            }
        )
    }

    private func next() {
        if page < 2 {
            withAnimation { page += 1 }
            return
        }
        let trimmed = balanceText.trimmingCharacters(in: .whitespacesAndNewlines)
        let negative = trimmed.hasPrefix("-") || trimmed.hasPrefix("−")
        if let value = Money.parse(negative ? String(trimmed.dropFirst()) : trimmed) {
            startingBalance = negative ? -value : value
        }
        onFinish()
    }
}
