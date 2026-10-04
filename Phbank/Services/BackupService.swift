//
//  BackupService.swift
//  Phbank
//
//  Full JSON backup of the journal (entries, budgets, recurring payments,
//  starting balance) and restore from such a file.
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
    }

    static let currentVersion = 1

    var app = "PHINANZ"
    var version = BackupFile.currentVersion
    var exportedAt: Date
    var startingBalance: Double
    var entries: [Entry]
    var budgets: [Budget]
    var recurring: [Recurring]
}

enum BackupError: LocalizedError, Equatable {
    case notABackup
    case newerVersion

    var errorDescription: String? {
        switch self {
        case .notABackup: String(localized: "This file is not a PHINANZ backup.")
        case .newerVersion: String(localized: "This backup was made by a newer version of PHINANZ.")
        }
    }
}

struct RestoreSummary: Equatable {
    var entries: Int
    var budgets: Int
    var recurring: Int
}

enum BackupService {
    static func makeBackup(
        entries: [Expense],
        budgets: [CategoryBudget],
        recurring: [RecurringPayment],
        startingBalance: Double,
        now: Date = Date()
    ) -> BackupFile {
        BackupFile(
            exportedAt: now,
            startingBalance: startingBalance,
            entries: entries.sorted { $0.date < $1.date }.map {
                .init(store: $0.store, amount: $0.amount, category: $0.categoryRaw, date: $0.date,
                      note: $0.note, source: $0.sourceRaw, isIncome: $0.isIncome)
            },
            budgets: budgets.map { .init(category: $0.categoryRaw, monthlyLimit: $0.monthlyLimit) },
            recurring: recurring.map {
                .init(name: $0.name, amount: $0.amount, category: $0.categoryRaw, isIncome: $0.isIncome,
                      dayOfMonth: $0.dayOfMonth, startDate: $0.startDate, lastGenerated: $0.lastGenerated,
                      isActive: $0.isActive, note: $0.note)
            }
        )
    }

    static func encode(_ backup: BackupFile) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }

    static func decode(_ data: Data) throws -> BackupFile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let backup = try? decoder.decode(BackupFile.self, from: data), backup.app == "PHINANZ" else {
            throw BackupError.notABackup
        }
        guard backup.version <= BackupFile.currentVersion else { throw BackupError.newerVersion }
        return backup
    }

    /// Writes the backup to a temporary file for the share sheet.
    @MainActor
    static func writeBackup(from context: ModelContext, startingBalance: Double, now: Date = Date()) throws -> URL {
        let backup = makeBackup(
            entries: try context.fetch(FetchDescriptor<Expense>()),
            budgets: try context.fetch(FetchDescriptor<CategoryBudget>()),
            recurring: try context.fetch(FetchDescriptor<RecurringPayment>()),
            startingBalance: startingBalance,
            now: now
        )
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PHINANZ-Backup-\(formatter.string(from: now)).json")
        try encode(backup).write(to: url, options: .atomic)
        return url
    }

    /// Replaces everything in the store with the backup. Invalid rows are skipped.
    @MainActor
    @discardableResult
    static func restore(_ backup: BackupFile, into context: ModelContext) throws -> RestoreSummary {
        try context.delete(model: Expense.self)
        try context.delete(model: CategoryBudget.self)
        try context.delete(model: RecurringPayment.self)

        var summary = RestoreSummary(entries: 0, budgets: 0, recurring: 0)
        for item in backup.entries where isValid(amount: item.amount) {
            let entry = Expense(
                store: String(item.store.prefix(80)),
                amount: Money.roundCents(item.amount),
                category: ExpenseCategory.parse(item.category),
                date: item.date,
                note: String(item.note.prefix(500)),
                source: ExpenseSource(rawValue: item.source) ?? .manual,
                isIncome: item.isIncome
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
                note: String(item.note.prefix(500))
            )
            payment.lastGenerated = item.lastGenerated
            payment.isActive = item.isActive
            context.insert(payment)
            summary.recurring += 1
        }
        try context.save()
        if backup.startingBalance.isFinite {
            UserDefaults.standard.set(backup.startingBalance, forKey: SettingsKeys.startingBalance)
        }
        return summary
    }

    private static func isValid(amount: Double) -> Bool {
        amount.isFinite && amount > 0 && amount < 1_000_000
    }
}
