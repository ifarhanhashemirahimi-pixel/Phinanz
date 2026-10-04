//
//  SettingsView.swift
//  Phbank
//

import SwiftUI
import SwiftData
import UIKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let expenses: [Expense]
    let year: Int

    @AppStorage(SettingsKeys.lockEnabled) private var lockEnabled = false
    @AppStorage(SettingsKeys.aiConsent) private var aiConsent = false
    @AppStorage(SettingsKeys.geminiModel) private var model = GeminiService.defaultModel
    @AppStorage(SettingsKeys.startingBalance) private var startingBalance = 0.0

    @State private var balanceText = ""
    @FocusState private var balanceFocused: Bool

    @State private var apiKeyInput = ""
    @State private var hasStoredKey = !(KeychainStore.get(SettingsKeys.apiKeyAccount) ?? "").isEmpty
    @State private var keyError: String?
    @State private var exportURL: URL?
    @State private var exportError: String?
    @State private var confirmWipe = false
    private let lockAvailable = AppLock.canAuthenticate

    private var yearExpenses: [Expense] {
        expenses.filter { Calendar.current.component(.year, from: $0.date) == year }
    }

    private var lockBinding: Binding<Bool> {
        Binding(
            get: { lockEnabled },
            set: { newValue in
                if newValue {
                    // Confirm the user can actually unlock before turning the lock on.
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

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Currency", value: "EUR (€)")
                    HStack {
                        Text("Starting balance")
                        Spacer()
                        TextField("0,00", text: $balanceText)
                            .keyboardType(.numbersAndPunctuation)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 140)
                            .focused($balanceFocused)
                            .onSubmit(saveBalance)
                        Text(verbatim: "€").foregroundStyle(.secondary)
                    }
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        LabeledContent("Language", value: Locale.current.localizedString(forLanguageCode: Locale.current.language.languageCode?.identifier ?? "en") ?? "")
                    }
                    .foregroundStyle(.primary)
                } header: {
                    Text("Preferences")
                } footer: {
                    Text("The starting balance is what was in your account before your first entry. Change the language in the iOS Settings app (English, Deutsch, فارسی).")
                }

                Section("Planning") {
                    NavigationLink {
                        BudgetsView()
                    } label: {
                        Label("Monthly budgets", systemImage: "gauge.with.dots.needle.33percent")
                    }
                    NavigationLink {
                        RecurringListView()
                    } label: {
                        Label("Recurring payments", systemImage: "arrow.triangle.2.circlepath")
                    }
                }

                Section {
                    Toggle(isOn: lockBinding) {
                        Label("Face ID lock", systemImage: "faceid")
                    }
                    .disabled(!lockAvailable)
                } header: {
                    Text("Security")
                } footer: {
                    if lockAvailable {
                        Text("Locks the journal whenever you leave the app. Uses Face ID or Touch ID, with your device passcode as backup.")
                    } else {
                        Text("Set a device passcode in the iOS Settings app to use the lock.")
                    }
                }

                aiSection

                Section {
                    Button("Prepare \(String(year)) tax report (CSV)", action: prepareExport)
                    if let exportURL {
                        ShareLink(item: exportURL) {
                            Label("Share \(String(year)).csv", systemImage: "square.and.arrow.up")
                        }
                    }
                    if let exportError {
                        Text(exportError).font(.footnote).foregroundStyle(.red)
                    }
                } header: {
                    Text("Export")
                } footer: {
                    Text("\(yearExpenses.count) entries in \(String(year)). Semicolon-separated with decimal comma, ready for German Excel.")
                }

                Section {
                    Button("Delete all entries", role: .destructive) { confirmWipe = true }
                } header: {
                    Text("Data")
                } footer: {
                    Text("Your journal is stored only on this device.")
                }

                Section("About") {
                    LabeledContent("Version", value: appVersion)
                }
            }
            .onAppear { balanceText = startingBalance == 0 ? "" : Money.input(startingBalance) }
            .onChange(of: balanceFocused) { _, focused in if !focused { saveBalance() } }
            .onDisappear(perform: saveBalance)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Delete all \(expenses.count) entries?",
                isPresented: $confirmWipe,
                titleVisibility: .visible
            ) {
                Button("Delete everything", role: .destructive, action: wipe)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
            }
        }
        .tint(JournalTheme.gold)
    }

    // MARK: AI section

    private var aiSection: some View {
        Section {
            Toggle("Allow AI import", isOn: $aiConsent)

            if hasStoredKey {
                Label("API key saved in Keychain", systemImage: "checkmark.shield")
                Button("Remove API key", role: .destructive) {
                    KeychainStore.set("", for: SettingsKeys.apiKeyAccount)
                    hasStoredKey = false
                }
            } else {
                SecureField("Gemini API key", text: $apiKeyInput)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Button("Save API key", action: saveKey)
                    .disabled(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if let keyError {
                    Text(keyError).font(.footnote).foregroundStyle(.red)
                }
                if let url = URL(string: "https://aistudio.google.com/apikey") {
                    Link("Get a key from Google AI Studio", destination: url)
                }
            }

            TextField("Model", text: $model)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !GeminiService.isValidModelName(model) {
                Text("Use letters, numbers, “-”, “.” or “_” only.")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("AI import")
        } footer: {
            Text("When you analyse a voice note, receipt photo or PDF statement, that file is sent to Google's Gemini API to extract entries. Nothing is sent otherwise, and nothing is saved until you confirm it. Your key stays in the iOS Keychain on this device.")
        }
    }

    // MARK: Actions

    private func saveBalance() {
        let trimmed = balanceText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            startingBalance = 0
            return
        }
        // Allow a negative starting balance (overdraft), e.g. "-120,50".
        let negative = trimmed.hasPrefix("-") || trimmed.hasPrefix("−")
        let digits = negative ? String(trimmed.dropFirst()) : trimmed
        if let value = Money.parse(digits) {
            startingBalance = negative ? -value : value
        }
    }

    private func saveKey() {
        let key = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if KeychainStore.set(key, for: SettingsKeys.apiKeyAccount) {
            apiKeyInput = ""
            keyError = nil
            hasStoredKey = true
        } else {
            keyError = String(localized: "The key could not be saved to the Keychain.")
        }
    }

    private func prepareExport() {
        do {
            exportURL = try CSVExporter.writeFile(for: yearExpenses, year: year)
            exportError = nil
        } catch {
            exportURL = nil
            exportError = String(localized: "Export failed: \(error.localizedDescription)")
        }
    }

    private func wipe() {
        try? context.delete(model: Expense.self)
        try? context.save()
        exportURL = nil
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
