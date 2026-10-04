//
//  WidgetBridge.swift
//  Phbank
//
//  Publishes a tiny summary to the shared App Group so the Home Screen
//  widget can show it without opening the database.
//

import Foundation
import WidgetKit

/// Keep in sync with PhinanzWidget/WidgetSnapshot.swift.
struct WidgetSnapshot: Codable, Equatable {
    var todaySpent: Double
    var monthSpent: Double
    var monthIncome: Double
    var balance: Double
    var budgetLimit: Double
    var updatedAt: Date

    static let appGroup = "group.Farhan.Phbank"
    static let key = "widgetSnapshot"
}

enum WidgetBridge {
    static func makeSnapshot(
        entries: [Expense],
        budgets: [CategoryBudget],
        startingBalance: Double,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> WidgetSnapshot {
        let today = calendar.dateInterval(of: .day, for: now) ?? DateInterval(start: now, duration: 86_400)
        let month = calendar.dateInterval(of: .month, for: now) ?? today
        let monthEntries = ExpenseStats.expenses(entries, in: month)
        return WidgetSnapshot(
            todaySpent: ExpenseStats.spending(ExpenseStats.expenses(entries, in: today)),
            monthSpent: ExpenseStats.spending(monthEntries),
            monthIncome: ExpenseStats.income(monthEntries),
            balance: ExpenseStats.balance(starting: startingBalance, entries: entries, upTo: now),
            budgetLimit: Money.roundCents(budgets.reduce(0) { $0 + max(0, $1.monthlyLimit) }),
            updatedAt: now
        )
    }

    static func publish(_ snapshot: WidgetSnapshot) {
        guard let defaults = UserDefaults(suiteName: WidgetSnapshot.appGroup),
              let data = try? JSONEncoder().encode(snapshot)
        else { return }
        if defaults.data(forKey: WidgetSnapshot.key) == data { return }
        defaults.set(data, forKey: WidgetSnapshot.key)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
