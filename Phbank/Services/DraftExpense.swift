//
//  DraftExpense.swift
//  Phbank
//
//  An AI-suggested expense the user can edit before it is saved.
//

import Foundation

struct DraftExpense: Identifiable, Equatable {
    let id = UUID()
    var store: String
    var amountText: String
    var category: ExpenseCategory
    var date: Date
    var note: String
    var isIncome: Bool
    var include: Bool = true
    var isPossibleDuplicate: Bool = false
    let source: ExpenseSource

    init(parsed: ParsedExpense, source: ExpenseSource, fallbackDate: Date, calendar: Calendar = .current) {
        self.store = parsed.store
        self.amountText = Money.input(parsed.amount)
        self.category = ExpenseCategory.parse(parsed.category)
        self.date = Self.combine(date: parsed.date, time: parsed.time, fallback: fallbackDate, calendar: calendar)
        self.note = parsed.note ?? ""
        self.isIncome = parsed.isIncome
        self.source = source
    }

    var amount: Double? {
        guard let value = Money.parse(amountText), value > 0, value < 1_000_000 else { return nil }
        return value
    }

    var isValid: Bool {
        !store.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && amount != nil
    }

    func makeExpense() -> Expense? {
        guard isValid, let amount else { return nil }
        return Expense(
            store: String(store.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80)),
            amount: amount,
            category: category,
            date: date,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            source: source,
            isIncome: isIncome
        )
    }

    // MARK: Date handling

    /// Builds the entry date from the model's "yyyy-MM-dd" and "HH:mm" strings.
    /// Missing date → fallback; date without time → 12:00.
    static func combine(date: String?, time: String?, fallback: Date, calendar: Calendar = .current) -> Date {
        let day = date.flatMap { parseISODate($0, calendar: calendar) }
        let clock = time.flatMap { parseClock($0) }

        switch (day, clock) {
        case let (day?, clock?):
            return calendar.date(bySettingHour: clock.hour, minute: clock.minute, second: 0, of: day) ?? day
        case let (day?, nil):
            return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
        case let (nil, clock?):
            return calendar.date(bySettingHour: clock.hour, minute: clock.minute, second: 0, of: fallback) ?? fallback
        case (nil, nil):
            return fallback
        }
    }

    static func parseISODate(_ text: String, calendar: Calendar) -> Date? {
        let parts = text.trimmingCharacters(in: .whitespaces).split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (2000...2100).contains(parts[0]) else { return nil }
        guard let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])),
              calendar.component(.month, from: date) == parts[1],
              calendar.component(.day, from: date) == parts[2]
        else { return nil }
        return date
    }

    static func parseClock(_ text: String) -> (hour: Int, minute: Int)? {
        let parts = text.trimmingCharacters(in: .whitespaces).split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2, (0...23).contains(parts[0]), (0...59).contains(parts[1]) else { return nil }
        return (parts[0], parts[1])
    }
}

enum DuplicateDetector {
    /// Same store (case-insensitive), same amount in cents, same calendar day.
    static func isDuplicate(_ draft: DraftExpense, in existing: [Expense], calendar: Calendar = .current) -> Bool {
        guard let amount = draft.amount else { return false }
        let name = draft.store.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return existing.contains { expense in
            expense.isIncome == draft.isIncome
                && calendar.isDate(expense.date, inSameDayAs: draft.date)
                && abs(expense.amount - amount) < 0.005
                && expense.store.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == name
        }
    }
}
