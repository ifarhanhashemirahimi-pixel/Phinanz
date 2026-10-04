//
//  BudgetCalculator.swift
//  Phbank
//

import Foundation

struct BudgetStatus: Identifiable, Equatable {
    enum Level: Int, Comparable {
        case ok, warning, over
        static func < (lhs: Level, rhs: Level) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    let category: ExpenseCategory
    let limit: Double
    let spent: Double

    var id: String { category.rawValue }
    var ratio: Double { limit > 0 ? spent / limit : 0 }
    var remaining: Double { Money.roundCents(limit - spent) }
    var level: Level { BudgetCalculator.level(spent: spent, limit: limit) }
}

enum BudgetCalculator {
    static let warningRatio = 0.8

    static func level(spent: Double, limit: Double) -> BudgetStatus.Level {
        guard limit > 0 else { return .ok }
        if spent > limit + 0.004 { return .over }
        if spent >= limit * warningRatio { return .warning }
        return .ok
    }

    /// One status per budget with a positive limit, most used first.
    static func statuses(budgets: [CategoryBudget], entries: [Expense], in month: DateInterval) -> [BudgetStatus] {
        let monthEntries = ExpenseStats.expenses(entries, in: month).filter { !$0.isIncome }
        return budgets
            .filter { $0.monthlyLimit > 0 }
            .map { budget in
                let spent = ExpenseStats.total(monthEntries.filter { $0.category == budget.category })
                return BudgetStatus(category: budget.category, limit: budget.monthlyLimit, spent: spent)
            }
            .sorted { $0.ratio > $1.ratio }
    }

    /// The new level if spending moved from `before` to `after` crossed a threshold upwards.
    static func crossedLevel(before: Double, after: Double, limit: Double) -> BudgetStatus.Level? {
        let old = level(spent: before, limit: limit)
        let new = level(spent: after, limit: limit)
        return new > old ? new : nil
    }
}
