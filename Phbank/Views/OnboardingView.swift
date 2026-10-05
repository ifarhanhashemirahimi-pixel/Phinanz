//
//  OnboardingView.swift
//  Phbank
//
//  First-launch welcome in the style of Apple's own apps:
//  big title, three feature rows, one prominent button.
//

import SwiftUI

struct OnboardingView: View {
    var onFinish: () -> Void

    @Environment(\.modelContext) private var context
    @AppStorage(SettingsKeys.lockEnabled) private var lockEnabled = false

    @State private var step = 0
    @State private var balanceText = ""
    private let lockAvailable = AppLock.canAuthenticate

    var body: some View {
        NavigationStack {
            Group {
                if step == 0 { welcome } else { setup }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: next) {
                    Text(step == 0 ? LocalizedStringKey("Continue") : LocalizedStringKey("Get Started"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
                .accessibilityIdentifier("onboarding-continue")
            }
            .animation(.snappy, value: step)
        }
        .interactiveDismissDisabled()
    }

    // MARK: Pages

    private var welcome: some View {
        ScrollView {
            VStack(spacing: 36) {
                VStack(spacing: 14) {
                    SettingsIcon(systemName: "book.pages.fill", color: .blue, size: 88)
                    Text("Welcome to PHINANZ")
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 48)

                VStack(alignment: .leading, spacing: 26) {
                    FeatureRow(
                        systemName: "book.pages",
                        color: .blue,
                        title: "A Page for Every Day",
                        text: "Write down what you spend and earn. Every day of the year has its own page."
                    )
                    FeatureRow(
                        systemName: "chart.pie.fill",
                        color: .orange,
                        title: "See Where Your Money Goes",
                        text: "Summaries, budgets and recurring payments show the whole month at a glance."
                    )
                    FeatureRow(
                        systemName: "lock.shield.fill",
                        color: .green,
                        title: "Private by Design",
                        text: "Your journal stays on this iPhone. AI import is optional and off by default."
                    )
                }
                .padding(.horizontal, 8)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
    }

    private var setup: some View {
        Form {
            Section {
                VStack(spacing: 10) {
                    SettingsIcon(systemName: "slider.horizontal.3", color: .gray, size: 64)
                    Text("Quick Setup")
                        .font(.title.bold())
                    Text("You can change this later in Settings.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            Section {
                LabeledContent {
                    TextField("0,00", text: $balanceText)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.trailing)
                } label: {
                    SettingsLabel(title: "Current Balance", systemName: "building.columns.fill", color: .indigo)
                }
            } footer: {
                Text("Optional. Used to show your balance in Summary and the widget.")
            }

            if lockAvailable {
                Section {
                    Toggle(isOn: lockBinding) {
                        SettingsLabel(title: "Face ID Lock", systemName: "faceid", color: .green)
                    }
                } footer: {
                    Text("Recommended. Locks the journal whenever you leave the app.")
                }
            }
        }
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
        if step == 0 {
            step = 1
            return
        }
        // The balance becomes the opening balance of the main account.
        if let value = Money.parseSigned(balanceText), let account = AccountStore.ensurePrimaryAccount(in: context) {
            account.openingBalance = Money.roundCents(value)
            try? context.save()
        }
        onFinish()
    }
}

private struct FeatureRow: View {
    let systemName: String
    let color: Color
    let title: LocalizedStringKey
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: systemName)
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(color)
                .frame(width: 44)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
