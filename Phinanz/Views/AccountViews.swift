//
//  AccountViews.swift
//  Phinanz
//
//  Accounts (checking, cash, credit card, savings): balances in Plan,
//  account details, editing and transfers between accounts.
//

import SwiftUI
import SwiftData

/// "Accounts" section for the Plan tab.
struct AccountsSection: View {
    let expenses: [Expense]
    @Query private var accounts: [Account]
    @Query(sort: \Transfer.date, order: .reverse) private var transfers: [Transfer]
    @State private var showTransfer = false

    private var balances: [AccountBalance] {
        AccountLedger.balances(accounts: accounts, entries: expenses, transfers: transfers)
    }

    private var total: Double {
        AccountLedger.total(accounts: accounts, entries: expenses)
    }

    var body: some View {
        Section {
            ForEach(balances) { item in
                NavigationLink {
                    AccountDetailView(accountID: item.accountID, expenses: expenses)
                } label: {
                    AccountRow(name: item.name, kind: item.kind, balance: item.balance)
                }
            }
            if accounts.count > 1 {
                HStack {
                    Text("Total")
                        .font(.headline)
                    Spacer()
                    Text(Money.format(total))
                        .font(Theme.amount(.headline))
                        .monospacedDigit()
                        .accessibilityIdentifier("accounts-total")
                }
                Button {
                    showTransfer = true
                } label: {
                    Label("Transfer Between Accounts", systemImage: "arrow.left.arrow.right")
                }
            }
            NavigationLink {
                AccountsListView()
            } label: {
                Label("Manage Accounts", systemImage: "list.bullet")
            }
        } header: {
            Text("Accounts")
        }
        .sheet(isPresented: $showTransfer) {
            TransferEditorView()
        }
    }
}

struct AccountRow: View {
    let name: String
    let kind: AccountKind
    let balance: Double

    var body: some View {
        HStack(spacing: 12) {
            SettingsIcon(systemName: kind.symbol, color: kind.color, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).lineLimit(1)
                Text(kind.title)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(Money.format(balance))
                .monospacedDigit()
                .foregroundStyle(balance < 0 ? Color.red : Color.primary)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Detail

struct AccountDetailView: View {
    let accountID: String
    let expenses: [Expense]

    @Query private var accounts: [Account]
    @Query(sort: \Transfer.date, order: .reverse) private var transfers: [Transfer]
    @State private var editing: Account?

    private var account: Account? { accounts.first { $0.id == accountID } }

    private var entries: [Expense] {
        expenses
            .filter { AccountLedger.accountID(for: $0.accountID, accounts: accounts) == accountID }
            .sorted { $0.date > $1.date }
    }

    private var accountTransfers: [Transfer] {
        transfers.filter {
            AccountLedger.accountID(for: $0.fromAccountID, accounts: accounts) == accountID
                || AccountLedger.accountID(for: $0.toAccountID, accounts: accounts) == accountID
        }
    }

    private func name(of id: String) -> String {
        let resolved = AccountLedger.accountID(for: id, accounts: accounts)
        return accounts.first { $0.id == resolved }?.name ?? ""
    }

    var body: some View {
        List {
            if let account {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(account.kind.title, systemImage: account.kind.symbol)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(account.kind.color)
                        Text(Money.format(AccountLedger.balance(of: account, accounts: accounts, entries: expenses, transfers: transfers)))
                            .font(Theme.amount(.largeTitle, weight: .bold))
                            .monospacedDigit()
                        Text("Opening balance \(Money.format(account.openingBalance))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }

                if !accountTransfers.isEmpty {
                    Section("Transfers") {
                        ForEach(accountTransfers.prefix(20)) { transfer in
                            let incoming = AccountLedger.accountID(for: transfer.toAccountID, accounts: accounts) == accountID
                            HStack(spacing: 12) {
                                SettingsIcon(systemName: "arrow.left.arrow.right", color: .gray, size: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(incoming ? name(of: transfer.fromAccountID) : name(of: transfer.toAccountID))
                                    Text(transfer.note.isEmpty
                                         ? transfer.date.formatted(.dateTime.day().month(.abbreviated))
                                         : "\(transfer.date.formatted(.dateTime.day().month(.abbreviated))) · \(transfer.note)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Text(verbatim: (incoming ? "+" : "−") + Money.format(transfer.amount))
                                    .monospacedDigit()
                                    .foregroundStyle(incoming ? Theme.income : Color.primary)
                            }
                            .accessibilityElement(children: .combine)
                        }
                        .onDelete { offsets in
                            let items = Array(accountTransfers.prefix(20))
                            for index in offsets { items[index].modelContext?.delete(items[index]) }
                        }
                    }
                }

                Section("Entries") {
                    if entries.isEmpty {
                        Text("No entries in this account yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(entries.prefix(100)) { entry in
                            EntryRow(entry: entry, showsDate: true)
                        }
                    }
                }
            } else {
                ContentUnavailableView("Account Not Found", systemImage: "questionmark.folder")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(account?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let account {
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") { editing = account }
                }
            }
        }
        .sheet(item: $editing) { account in
            AccountEditorView(account: account)
        }
    }
}

// MARK: - List and editor

struct AccountsListView: View {
    @Environment(\.modelContext) private var context
    @Query private var accounts: [Account]
    @State private var editing: Account?
    @State private var showNew = false
    @State private var pendingDelete: Account?

    private var sorted: [Account] { AccountLedger.sorted(accounts) }
    private var primaryID: String? { AccountLedger.primary(accounts)?.id }

    var body: some View {
        List {
            Section {
                ForEach(sorted) { account in
                    Button {
                        editing = account
                    } label: {
                        HStack(spacing: 12) {
                            SettingsIcon(systemName: account.kind.symbol, color: account.kind.color, size: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(account.name).foregroundStyle(Color.primary)
                                Text(account.id == primaryID ? String(localized: "Main account") : account.kind.title)
                                    .font(.footnote)
                                    .foregroundStyle(Color.secondary)
                            }
                        }
                    }
                    .deleteDisabled(account.id == primaryID)
                }
                .onDelete { offsets in
                    pendingDelete = offsets.map { sorted[$0] }.first
                }
                .onMove { from, to in
                    var items = sorted
                    items.move(fromOffsets: from, toOffset: to)
                    for (index, item) in items.enumerated() { item.sortOrder = index }
                }
            } footer: {
                Text("The first account is your main account. Entries from Siri, widgets and older versions go there. Drag to reorder.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Accounts")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showNew = true
                } label: {
                    Label("Add Account", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
        }
        .sheet(item: $editing) { AccountEditorView(account: $0) }
        .sheet(isPresented: $showNew) { AccountEditorView(account: nil, sortOrder: accounts.count) }
        .confirmationDialog(
            "Delete this account?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete Account", role: .destructive) {
                if let account = pendingDelete { AccountStore.delete(account, in: context) }
                pendingDelete = nil
            }
        } message: {
            Text("Its entries and payments move to your main account. Nothing is lost.")
        }
    }
}

struct AccountEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let account: Account?
    var sortOrder = 0

    @State private var name: String
    @State private var kind: AccountKind
    @State private var openingText: String

    init(account: Account?, sortOrder: Int = 0) {
        self.account = account
        self.sortOrder = sortOrder
        _name = State(initialValue: account?.name ?? "")
        _kind = State(initialValue: account?.kind ?? .checking)
        _openingText = State(initialValue: account.map { $0.openingBalance == 0 ? "" : Money.input($0.openingBalance) } ?? "")
    }

    private var opening: Double? {
        openingText.trimmingCharacters(in: .whitespaces).isEmpty ? 0 : Money.parseSigned(openingText)
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSave: Bool { !trimmedName.isEmpty && opening != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name, e.g. Sparkasse", text: $name)
                        .accessibilityIdentifier("account-name")
                    Picker("Type", selection: $kind) {
                        ForEach(AccountKind.allCases) { kind in
                            Label(kind.title, systemImage: kind.symbol).tag(kind)
                        }
                    }
                }
                Section {
                    LabeledContent("Opening Balance") {
                        HStack(spacing: 4) {
                            TextField("0,00", text: $openingText)
                                .keyboardType(.numbersAndPunctuation)
                                .multilineTextAlignment(.trailing)
                            Text(verbatim: "€").foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    if opening == nil {
                        Text("Enter an amount like 1.250,00 or -80.").foregroundStyle(.red)
                    } else {
                        Text("What was in the account before your first entry in PHINANZ. Negative for a credit card you owe.")
                    }
                }
            }
            .navigationTitle(account == nil ? "New Account" : "Edit Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!canSave)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        guard let opening else { return }
        let value = Money.roundCents(opening)
        if let account {
            account.name = String(trimmedName.prefix(60))
            account.kind = kind
            account.openingBalance = value
        } else {
            context.insert(Account(name: String(trimmedName.prefix(60)), kind: kind, openingBalance: value, sortOrder: sortOrder))
        }
        try? context.save()
        dismiss()
    }
}

// MARK: - Transfer

struct TransferEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var accounts: [Account]

    @State private var fromID = ""
    @State private var toID = ""
    @State private var amountText = ""
    @State private var date = Date()
    @State private var note = ""

    private var sorted: [Account] { AccountLedger.sorted(accounts) }

    private var amount: Double? {
        guard let value = Money.parse(amountText), value > 0, value < 1_000_000 else { return nil }
        return value
    }

    private var canSave: Bool { amount != nil && !fromID.isEmpty && !toID.isEmpty && fromID != toID }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("From", selection: $fromID) {
                        ForEach(sorted) { Text($0.name).tag($0.id) }
                    }
                    Picker("To", selection: $toID) {
                        ForEach(sorted) { Text($0.name).tag($0.id) }
                    }
                } footer: {
                    if !fromID.isEmpty && fromID == toID {
                        Text("Choose two different accounts.").foregroundStyle(.red)
                    } else {
                        Text("For example cash from an ATM or money moved to savings. Transfers don't count as spending or income.")
                    }
                }
                Section {
                    LabeledContent("Amount") {
                        HStack(spacing: 4) {
                            TextField("0,00", text: $amountText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                            Text(verbatim: "€").foregroundStyle(.secondary)
                        }
                    }
                    DatePicker("Date", selection: $date)
                    TextField("Optional note", text: $note)
                }
            }
            .navigationTitle("Transfer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!canSave)
                }
            }
            .onAppear {
                if fromID.isEmpty { fromID = sorted.first?.id ?? "" }
                if toID.isEmpty { toID = sorted.dropFirst().first?.id ?? "" }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        guard let amount, canSave else { return }
        context.insert(Transfer(from: fromID, to: toID, amount: Money.roundCents(amount), date: date,
                                note: String(note.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))))
        try? context.save()
        dismiss()
    }
}

/// Account picker for editors; hidden when there is only one account.
struct AccountPicker: View {
    @Binding var accountID: String
    @Query private var accounts: [Account]

    var body: some View {
        if accounts.count > 1 {
            Picker(selection: $accountID) {
                ForEach(AccountLedger.sorted(accounts)) { account in
                    Label(account.name, systemImage: account.kind.symbol).tag(account.id)
                }
            } label: {
                Text("Account")
            }
            .onAppear {
                // Empty or unknown ids mean the main account; show it as selected.
                accountID = AccountLedger.accountID(for: accountID, accounts: accounts)
            }
        }
    }
}
