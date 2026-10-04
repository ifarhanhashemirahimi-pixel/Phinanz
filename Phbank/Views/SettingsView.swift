//
//  SettingsView.swift
//  Phbank
//
//  Settings in the style of the iOS Settings app: grouped list with
//  coloured icons.
//

import SwiftUI
import SwiftData
import UIKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let expenses: [Expense]
    let year: Int

    @AppStorage(SettingsKeys.lockEnabled) private var lockEnabled = false
    @AppStorage(SettingsKeys.aiConsent) private var aiConsent = false
    @AppStorage(SettingsKeys.geminiModel) private var model = GeminiService.defaultModel
    @AppStorage(SettingsKeys.startingBalance) private var startingBalance = 0.0
    @AppStorage(SettingsKeys.dailyReminder) private var dailyReminder = false
    @AppStorage(SettingsKeys.dailyReminderMinutes) private var dailyReminderMinutes = 20 * 60
    @AppStorage(SettingsKeys.paymentReminders) private var paymentReminders = false

    @State private var notificationsDenied = false
    @State private var backupURL: URL?
    @State private var showRestorePicker = false
    @State private var pendingRestore: BackupFile?
    @State private var backupMessage: String?

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

    private var languageName: String {
        let code = Locale.current.language.languageCode?.identifier ?? "en"
        return Locale.current.localizedString(forLanguageCode: code)?.capitalized ?? code
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
                generalSection
                securitySection
                remindersSection
                aiSection
                exportSection
                backupSection
                dataSection

                Section {
                    LabeledContent("Version", value: appVersion)
                } footer: {
                    Text("Your journal is stored only on this device.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { balanceText = startingBalance == 0 ? "" : Money.input(startingBalance) }
            .onChange(of: balanceFocused) { _, focused in if !focused { saveBalance() } }
            .onDisappear(perform: saveBalance)
            .fileImporter(isPresented: $showRestorePicker, allowedContentTypes: [.json]) { result in
                loadBackup(result)
            }
            .confirmationDialog(
                "Replace your journal with this backup?",
                isPresented: restoreDialogBinding,
                titleVisibility: .visible
            ) {
                Button("Restore", role: .destructive, action: performRestore)
                Button("Cancel", role: .cancel) { pendingRestore = nil }
            } message: {
                if let pendingRestore {
                    Text("The backup from \(pendingRestore.exportedAt.formatted(date: .abbreviated, time: .shortened)) contains \(pendingRestore.entries.count) entries. Your current entries will be replaced.")
                }
            }
            .confirmationDialog(
                "Delete all \(expenses.count) entries?",
                isPresented: $confirmWipe,
                titleVisibility: .visible
            ) {
                Button("Delete Everything", role: .destructive, action: wipe)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
            }
        }
    }

    // MARK: Sections

    private var generalSection: some View {
        Section {
            LabeledContent {
                Text(verbatim: "EUR (€)")
            } label: {
                SettingsLabel(title: "Currency", systemName: "eurosign", color: .green)
            }

            LabeledContent {
                TextField("0,00", text: $balanceText)
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.trailing)
                    .focused($balanceFocused)
                    .onSubmit(saveBalance)
            } label: {
                SettingsLabel(title: "Starting Balance", systemName: "building.columns.fill", color: .indigo)
            }

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                LabeledContent {
                    Text(verbatim: languageName)
                } label: {
                    SettingsLabel(title: "Language", systemName: "globe", color: .gray)
                }
            }
            .foregroundStyle(.primary)
        } footer: {
            Text("The starting balance is what was in your account before your first entry. Change the language in the iOS Settings app (English, Deutsch, فارسی).")
        }
    }

    private var securitySection: some View {
        Section {
            Toggle(isOn: lockBinding) {
                SettingsLabel(title: "Face ID Lock", systemName: "faceid", color: .green)
            }
            .disabled(!lockAvailable)
        } footer: {
            if lockAvailable {
                Text("Locks the journal whenever you leave the app. Uses Face ID or Touch ID, with your device passcode as backup.")
            } else {
                Text("Set a device passcode in the iOS Settings app to use the lock.")
            }
        }
    }

    private var remindersSection: some View {
        Section {
            Toggle(isOn: reminderBinding($dailyReminder)) {
                SettingsLabel(title: "Daily Reminder", systemName: "bell.badge.fill", color: .red)
            }
            if dailyReminder {
                DatePicker("Time", selection: reminderTimeBinding, displayedComponents: .hourAndMinute)
            }
            Toggle(isOn: reminderBinding($paymentReminders)) {
                SettingsLabel(title: "Payment Reminders", systemName: "calendar.badge.clock", color: .orange)
            }
        } header: {
            Text("Reminders")
        } footer: {
            if notificationsDenied {
                Text("Notifications are turned off for PHINANZ. Turn them on in the iOS Settings app.")
            } else {
                Text("A short reminder in the evening to write down your spending, and a note the day before rent, subscriptions or salary.")
            }
        }
    }

    private var backupSection: some View {
        Section {
            Button(action: prepareBackup) {
                SettingsLabel(title: "Back Up Journal", systemName: "externaldrive.fill", color: .blue)
            }
            .foregroundStyle(.primary)
            if let backupURL {
                ShareLink(item: backupURL) {
                    SettingsLabel(title: "Save Backup File", systemName: "square.and.arrow.up", color: .blue)
                }
            }
            Button {
                showRestorePicker = true
            } label: {
                SettingsLabel(title: "Restore from Backup", systemName: "arrow.counterclockwise", color: .teal)
            }
            .foregroundStyle(.primary)
            if let backupMessage {
                Text(backupMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Backup")
        } footer: {
            Text("Keep the backup file in iCloud Drive or the Files app. Restoring replaces everything in your journal.")
        }
    }

    private var aiSection: some View {
        Section {
            Toggle(isOn: $aiConsent) {
                SettingsLabel(title: "AI Import", systemName: "sparkles", color: .purple)
            }

            if hasStoredKey {
                LabeledContent("Gemini API Key") {
                    Label("Saved in Keychain", systemImage: "checkmark.seal.fill")
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(.green)
                }
                Button("Remove API Key", role: .destructive) {
                    KeychainStore.set("", for: SettingsKeys.apiKeyAccount)
                    hasStoredKey = false
                }
            } else {
                SecureField("Gemini API Key", text: $apiKeyInput)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Button("Save API Key", action: saveKey)
                    .disabled(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if let keyError {
                    Text(keyError).font(.footnote).foregroundStyle(.red)
                }
                if let url = URL(string: "https://aistudio.google.com/apikey") {
                    Link("Get a Key from Google AI Studio", destination: url)
                }
            }

            LabeledContent("Model") {
                TextField("Model", text: $model)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.secondary)
            }
            if !GeminiService.isValidModelName(model) {
                Text("Use letters, numbers, “-”, “.” or “_” only.")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("AI Import")
        } footer: {
            Text("When you analyse a voice note, receipt photo or PDF statement, that file is sent to Google's Gemini API to extract entries. Nothing is sent otherwise, and nothing is saved until you confirm it. Your key stays in the iOS Keychain on this device.")
        }
    }

    private var exportSection: some View {
        Section {
            Button(action: prepareExport) {
                SettingsLabel(title: "Prepare \(String(year)) Tax Report (CSV)", systemName: "doc.text.fill", color: .blue)
            }
            .foregroundStyle(.primary)
            if let exportURL {
                ShareLink(item: exportURL) {
                    SettingsLabel(title: "Share \(String(year)).csv", systemName: "square.and.arrow.up", color: .blue)
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
    }

    private var dataSection: some View {
        Section {
            Button(role: .destructive) {
                confirmWipe = true
            } label: {
                SettingsLabel(title: "Delete All Entries", systemName: "trash.fill", color: .red)
            }
            .foregroundStyle(.red)
        }
    }

    // MARK: Actions

    private func reminderBinding(_ setting: Binding<Bool>) -> Binding<Bool> {
        Binding(
            get: { setting.wrappedValue },
            set: { newValue in
                Task {
                    if newValue {
                        let allowed = await NotificationScheduler.requestAuthorization()
                        notificationsDenied = !allowed
                        setting.wrappedValue = allowed
                    } else {
                        setting.wrappedValue = false
                    }
                    await NotificationScheduler.refresh(context: context)
                }
            }
        )
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: dailyReminderMinutes / 60,
                    minute: dailyReminderMinutes % 60,
                    second: 0,
                    of: Date()
                ) ?? Date()
            },
            set: { newValue in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                dailyReminderMinutes = (parts.hour ?? 20) * 60 + (parts.minute ?? 0)
                Task { await NotificationScheduler.refresh(context: context) }
            }
        )
    }

    private var restoreDialogBinding: Binding<Bool> {
        Binding(
            get: { pendingRestore != nil },
            set: { if !$0 { pendingRestore = nil } }
        )
    }

    private func prepareBackup() {
        do {
            backupURL = try BackupService.writeBackup(from: context, startingBalance: startingBalance)
            backupMessage = nil
        } catch {
            backupURL = nil
            backupMessage = String(localized: "Backup failed: \(error.localizedDescription)")
        }
    }

    private func loadBackup(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                pendingRestore = try BackupService.decode(data)
            } catch {
                backupMessage = error.localizedDescription
            }
        case .failure(let error):
            backupMessage = error.localizedDescription
        }
    }

    private func performRestore() {
        guard let backup = pendingRestore else { return }
        pendingRestore = nil
        do {
            let summary = try BackupService.restore(backup, into: context)
            balanceText = startingBalance == 0 ? "" : Money.input(startingBalance)
            backupMessage = String(localized: "Restored \(summary.entries) entries, \(summary.budgets) budgets and \(summary.recurring) recurring payments.")
            WidgetBridge.refresh(from: context)
            Task { await NotificationScheduler.refresh(context: context) }
        } catch {
            backupMessage = String(localized: "Restore failed: \(error.localizedDescription)")
        }
    }

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
