//
//  BackupService.swift
//  Phinanz
//
//  Full backup of the journal (entries, budgets, recurring payments,
//  accounts, transfers, savings goals) as JSON, optionally encrypted with a
//  password (see BackupCrypto), and restore from such a file.
//

import Foundation
import SwiftData

struct BackupFile: Codable, Equatable {
    struct Entry: Codable, Equatable {
        var store: String
        var amount: Double
        var category: String
        var date: Date
        var note: String
        var source: String
        var isIncome: Bool
        var accountID: String? = nil
    }

    struct Budget: Codable, Equatable {
        var category: String
        var monthlyLimit: Double
    }

    struct Recurring: Codable, Equatable {
        var name: String
        var amount: Double
        var category: String
        var isIncome: Bool
        var dayOfMonth: Int
        var startDate: Date
        var lastGenerated: Date?
        var isActive: Bool
        var note: String
        var accountID: String? = nil
    }

    struct AccountItem: Codable, Equatable {
        var id: String
        var name: String
        var kind: String
        var openingBalance: Double
        var sortOrder: Int
        var createdAt: Date
    }

    struct TransferItem: Codable, Equatable {
        var from: String
        var to: String
        var amount: Double
        var date: Date
        var note: String
    }

    struct GoalItem: Codable, Equatable {
        var name: String
        var target: Double
        var saved: Double
        var deadline: Date?
        var symbol: String
        var color: String
        var createdAt: Date
    }

    /// 1: entries, budgets, recurring payments. 2: + accounts, transfers, savings goals.
    static let currentVersion = 2

    var app = "PHINANZ"
    var version = BackupFile.currentVersion
    var exportedAt: Date
    /// Version 1 only: the single starting balance before accounts existed.
    var startingBalance: Double
    var entries: [Entry]
    var budgets: [Budget]
    var recurring: [Recurring]
    var accounts: [AccountItem]? = nil
    var transfers: [TransferItem]? = nil
    var goals: [GoalItem]? = nil
}

enum BackupError: LocalizedError, Equatable {
    case notABackup
    case newerVersion
    case passwordRequired
    case tooLarge

    var errorDescription: String? {
        switch self {
        case .notABackup: String(localized: "This file is not a PHINANZ backup.")
        case .newerVersion: String(localized: "This backup was made by a newer version of PHINANZ.")
        case .passwordRequired: String(localized: "This backup is protected with a password.")
        case .tooLarge: String(localized: "This file is too large to be a PHINANZ backup.")
        }
    }
}

struct RestoreSummary: Equatable {
    var entries: Int
    var budgets: Int
    var recurring: Int
    var accounts: Int = 0
    var goals: Int = 0
}

enum BackupService {
    static let maxFileSize = 50_000_000

    static func makeBackup(
        entries: [Expense],
        budgets: [CategoryBudget],
        recurring: [RecurringPayment],
        accounts: [Account] = [],
        transfers: [Transfer] = [],
        goals: [SavingsGoal] = [],
        startingBalance: Double = 0,
        now: Date = Date()
    ) -> BackupFile {
        BackupFile(
            exportedAt: now,
            startingBalance: startingBalance,
            entries: entries.sorted { $0.date < $1.date }.map {
                .init(store: $0.store, amount: $0.amount, category: $0.categoryRaw, date: $0.date,
                      note: $0.note, source: $0.sourceRaw, isIncome: $0.isIncome,
                      accountID: $0.accountID.isEmpty ? nil : $0.accountID)
            },
            budgets: budgets.map { .init(category: $0.categoryRaw, monthlyLimit: $0.monthlyLimit) },
            recurring: recurring.map {
                .init(name: $0.name, amount: $0.amount, category: $0.categoryRaw, isIncome: $0.isIncome,
                      dayOfMonth: $0.dayOfMonth, startDate: $0.startDate, lastGenerated: $0.lastGenerated,
                      isActive: $0.isActive, note: $0.note,
                      accountID: $0.accountID.isEmpty ? nil : $0.accountID)
            },
            accounts: AccountLedger.sorted(accounts).map {
                .init(id: $0.id, name: $0.name, kind: $0.kindRaw, openingBalance: $0.openingBalance,
                      sortOrder: $0.sortOrder, createdAt: $0.createdAt)
            },
            transfers: transfers.sorted { $0.date < $1.date }.map {
                .init(from: $0.fromAccountID, to: $0.toAccountID, amount: $0.amount, date: $0.date, note: $0.note)
            },
            goals: goals.sorted { $0.createdAt < $1.createdAt }.map {
                .init(name: $0.name, target: $0.target, saved: $0.saved, deadline: $0.deadline,
                      symbol: $0.symbol, color: $0.colorName, createdAt: $0.createdAt)
            }
        )
    }

    static func encode(_ backup: BackupFile) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }

    /// Reads a plain or password-protected backup.
    static func decode(_ data: Data, password: String? = nil) throws -> BackupFile {
        guard data.count <= maxFileSize else { throw BackupError.tooLarge }
        var json = data
        if BackupCrypto.isEncrypted(data) {
            guard let password, !password.isEmpty else { throw BackupError.passwordRequired }
            json = try BackupCrypto.decrypt(data, password: password)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let backup = try? decoder.decode(BackupFile.self, from: json), backup.app == "PHINANZ" else {
            throw BackupError.notABackup
        }
        guard backup.version <= BackupFile.currentVersion else { throw BackupError.newerVersion }
        return backup
    }

    /// Writes the backup for the share sheet. With a password the file is
    /// encrypted (AES-256-GCM); either way it gets complete file protection
    /// and is deleted when the app goes to the background.
    @MainActor
    static func writeBackup(from context: ModelContext, password: String?, now: Date = Date()) async throws -> URL {
        let backup = makeBackup(
            entries: try context.fetch(FetchDescriptor<Expense>()),
            budgets: try context.fetch(FetchDescriptor<CategoryBudget>()),
            recurring: try context.fetch(FetchDescriptor<RecurringPayment>()),
            accounts: try context.fetch(FetchDescriptor<Account>()),
            transfers: try context.fetch(FetchDescriptor<Transfer>()),
            goals: try context.fetch(FetchDescriptor<SavingsGoal>()),
            now: now
        )
        let json = try encode(backup)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let day = formatter.string(from: now)

        if let password {
            // Key derivation takes a moment; keep the interface responsive.
            let encrypted = try await Task.detached(priority: .userInitiated) {
                try BackupCrypto.encrypt(json, password: password)
            }.value
            return try DataProtection.writeExport(encrypted, named: "Backup-\(day).phinanz")
        }
        return try DataProtection.writeExport(json, named: "Backup-\(day).json")
    }

    /// Decrypts and reads a backup off the main thread.
    static func load(_ data: Data, password: String?) async throws -> BackupFile {
        let plain: Data
        if BackupCrypto.isEncrypted(data) {
            guard let password, !password.isEmpty else { throw BackupError.passwordRequired }
            plain = try await Task.detached(priority: .userInitiated) {
                try BackupCrypto.decrypt(data, password: password)
            }.value
        } else {
            plain = data
        }
        return try decode(plain)
    }

    /// Replaces everything in the store with the backup. Invalid rows are skipped.
    @MainActor
    @discardableResult
    static func restore(_ backup: BackupFile, into context: ModelContext) throws -> RestoreSummary {
        try context.delete(model: Expense.self)
        try context.delete(model: CategoryBudget.self)
        try context.delete(model: RecurringPayment.self)
        try context.delete(model: Account.self)
        try context.delete(model: Transfer.self)
        try context.delete(model: SavingsGoal.self)

        var summary = RestoreSummary(entries: 0, budgets: 0, recurring: 0)

        // Accounts keep their ids so entries and transfers still point to them.
        var accountIDs = Set<String>()
        for item in backup.accounts ?? [] where !item.id.isEmpty && !accountIDs.contains(item.id) {
            let account = Account(
                name: String(item.name.prefix(60)),
                kind: AccountKind(rawValue: item.kind) ?? .checking,
                openingBalance: item.openingBalance.isFinite ? Money.roundCents(item.openingBalance) : 0,
                sortOrder: item.sortOrder,
                createdAt: item.createdAt
            )
            account.id = item.id
            context.insert(account)
            accountIDs.insert(item.id)
            summary.accounts += 1
        }
        if accountIDs.isEmpty {
            // Version 1 backups: one main account with the old starting balance.
            let opening = backup.startingBalance.isFinite ? Money.roundCents(backup.startingBalance) : 0
            context.insert(Account(name: String(localized: "Main Account"), kind: .checking, openingBalance: opening))
        }
        func account(_ id: String?) -> String {
            guard let id, accountIDs.contains(id) else { return "" }
            return id
        }

        for item in backup.entries where isValid(amount: item.amount) {
            let entry = Expense(
                store: String(item.store.prefix(80)),
                amount: Money.roundCents(item.amount),
                category: ExpenseCategory.parse(item.category),
                date: item.date,
                note: String(item.note.prefix(500)),
                source: ExpenseSource(rawValue: item.source) ?? .manual,
                isIncome: item.isIncome,
                accountID: account(item.accountID)
            )
            context.insert(entry)
            summary.entries += 1
        }
        for item in backup.budgets where isValid(amount: item.monthlyLimit) {
            context.insert(CategoryBudget(category: ExpenseCategory.parse(item.category), monthlyLimit: item.monthlyLimit))
            summary.budgets += 1
        }
        for item in backup.recurring where isValid(amount: item.amount) {
            let payment = RecurringPayment(
                name: String(item.name.prefix(80)),
                amount: Money.roundCents(item.amount),
                category: ExpenseCategory.parse(item.category),
                isIncome: item.isIncome,
                dayOfMonth: item.dayOfMonth,
                startDate: item.startDate,
                note: String(item.note.prefix(500)),
                accountID: account(item.accountID)
            )
            payment.lastGenerated = item.lastGenerated
            payment.isActive = item.isActive
            context.insert(payment)
            summary.recurring += 1
        }
        for item in backup.transfers ?? [] where isValid(amount: item.amount) {
            let from = account(item.from), to = account(item.to)
            guard from != to else { continue }
            context.insert(Transfer(from: from, to: to, amount: Money.roundCents(item.amount), date: item.date,
                                    note: String(item.note.prefix(500))))
        }
        for item in backup.goals ?? [] where isValid(amount: item.target) {
            let saved = item.saved.isFinite ? min(max(item.saved, 0), 1_000_000) : 0
            context.insert(SavingsGoal(
                name: String(item.name.prefix(60)),
                target: Money.roundCents(item.target),
                saved: Money.roundCents(saved),
                deadline: item.deadline,
                symbol: GoalStyle.symbols.contains(item.symbol) ? item.symbol : "star.fill",
                colorName: GoalStyle.colorNames.contains(item.color) ? item.color : "blue",
                createdAt: item.createdAt
            ))
            summary.goals += 1
        }
        try context.save()
        return summary
    }

    private static func isValid(amount: Double) -> Bool {
        amount.isFinite && amount > 0 && amount < 1_000_000
    }
}
