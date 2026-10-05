//
//  SecurityViews.swift
//  Phbank
//
//  "Security & Privacy" overview, and the password sheets for protected
//  backups.
//

import SwiftUI
import SwiftData

struct SecurityOverviewView: View {
    @AppStorage(SettingsKeys.lockEnabled) private var lockEnabled = false
    @AppStorage(SettingsKeys.widgetHideAmounts) private var widgetHideAmounts = false
    @AppStorage(SettingsKeys.aiConsent) private var aiConsent = false

    var body: some View {
        List {
            Section {
                SecurityRow(
                    title: "Encrypted on This iPhone",
                    detail: "Your journal uses iOS Data Protection: it can only be read while your iPhone is unlocked.",
                    systemName: "lock.iphone", color: .blue, isOn: true
                )
                SecurityRow(
                    title: "Face ID Lock",
                    detail: lockEnabled
                        ? "PHINANZ locks when you leave it and hides its content in the app switcher."
                        : "Off. Turn it on in Settings so nobody else can open your journal.",
                    systemName: "faceid", color: .green, isOn: lockEnabled
                )
                SecurityRow(
                    title: "Widgets",
                    detail: widgetHideAmounts
                        ? "Amounts are hidden; no numbers are shared with widgets."
                        : "Widgets show amounts. On the Lock Screen they are hidden while your iPhone is locked.",
                    systemName: "rectangle.on.rectangle", color: .orange, isOn: widgetHideAmounts
                )
                SecurityRow(
                    title: "Siri and Shortcuts",
                    detail: "Siri asks you to unlock your iPhone before it adds entries or tells you amounts.",
                    systemName: "mic.fill", color: .purple, isOn: true
                )
            } header: {
                Text("On Your iPhone")
            }

            Section {
                SecurityRow(
                    title: "Password-Protected Backups",
                    detail: "Backups can be encrypted with AES-256. Without the password nobody can read them — not even PHINANZ.",
                    systemName: "externaldrive.badge.checkmark", color: .teal, isOn: true
                )
                SecurityRow(
                    title: "Bank CSV Import",
                    detail: "Bank exports are read on this iPhone and never uploaded.",
                    systemName: "building.columns.fill", color: .green, isOn: true
                )
                SecurityRow(
                    title: "AI Import",
                    detail: aiConsent
                        ? "On. Only a file you choose is sent to Google Gemini, over an encrypted connection, and nothing is cached."
                        : "Off. Nothing is sent to any AI service.",
                    systemName: "sparkles", color: .purple, isOn: true
                )
                SecurityRow(
                    title: "iCloud Sync",
                    detail: CloudSync.isActive
                        ? "On. Your journal syncs through your private iCloud database."
                        : "Off. Your journal stays on this device.",
                    systemName: "icloud.fill", color: .blue, isOn: true
                )
            } header: {
                Text("Leaving Your iPhone")
            }

            Section {
                SecurityRow(
                    title: "No Ads, No Tracking",
                    detail: "No account, no analytics, no advertising. PHINANZ doesn't know who you are.",
                    systemName: "hand.raised.fill", color: .indigo, isOn: true
                )
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Security & Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SecurityRow: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let systemName: String
    let color: Color
    let isOn: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            SettingsIcon(systemName: systemName, color: color, size: 32)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title).font(.body.weight(.semibold))
                    Spacer()
                    Image(systemName: isOn ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundStyle(isOn ? Color.green : Color.orange)
                        .accessibilityHidden(true)
                }
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Backup password

/// Asks whether and how to protect a new backup, then creates the file.
struct BackupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    var onCreated: (URL) -> Void

    @State private var protect = true
    @State private var password = ""
    @State private var confirmation = ""
    @State private var working = false
    @State private var error: String?

    private var passwordProblem: LocalizedStringKey? {
        guard protect else { return nil }
        if password.count < BackupCrypto.minimumPasswordLength { return "Use at least 8 characters." }
        if password != confirmation { return "The passwords don't match." }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Protect with Password", isOn: $protect.animation())
                    if protect {
                        SecureField("Password", text: $password)
                            .textContentType(.newPassword)
                            .accessibilityIdentifier("backup-password")
                        SecureField("Repeat Password", text: $confirmation)
                            .textContentType(.newPassword)
                            .accessibilityIdentifier("backup-password-repeat")
                    }
                } footer: {
                    if protect {
                        if let passwordProblem, !password.isEmpty {
                            Text(passwordProblem).foregroundStyle(.red)
                        } else {
                            Text("The backup is encrypted with AES-256. Keep the password safe: without it the backup cannot be restored.")
                        }
                    } else {
                        Text("Anyone who gets the file can read your finances. Protect it unless you keep it somewhere safe.")
                            .foregroundStyle(.orange)
                    }
                }
                if let error {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Back Up Journal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if working {
                        ProgressView()
                    } else {
                        Button("Create", action: create)
                            .disabled(passwordProblem != nil)
                            .accessibilityIdentifier("create-backup")
                    }
                }
            }
            .interactiveDismissDisabled(working)
        }
        .presentationDetents([.medium, .large])
    }

    private func create() {
        working = true
        error = nil
        let secret = protect ? password : nil
        Task {
            do {
                let url = try await BackupService.writeBackup(from: context, password: secret)
                password = ""
                confirmation = ""
                onCreated(url)
                dismiss()
            } catch {
                self.error = String(localized: "Backup failed: \(error.localizedDescription)")
            }
            working = false
        }
    }
}

/// Asks for the password of a protected backup and decrypts it.
struct RestorePasswordSheet: View {
    @Environment(\.dismiss) private var dismiss
    let data: Data
    var onDecrypted: (BackupFile) -> Void

    @State private var password = ""
    @State private var working = false
    @State private var error: String?
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .focused($focused)
                        .onSubmit(unlock)
                        .accessibilityIdentifier("restore-password")
                } footer: {
                    if let error {
                        Text(error).foregroundStyle(.red)
                    } else {
                        Text("This backup is protected with a password.")
                    }
                }
            }
            .navigationTitle("Open Backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if working {
                        ProgressView()
                    } else {
                        Button("Open", action: unlock).disabled(password.isEmpty)
                    }
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.height(260)])
    }

    private func unlock() {
        guard !password.isEmpty, !working else { return }
        working = true
        error = nil
        let secret = password
        Task {
            do {
                let backup = try await BackupService.load(data, password: secret)
                password = ""
                dismiss()
                onDecrypted(backup)
            } catch {
                self.error = error.localizedDescription
            }
            working = false
        }
    }
}
