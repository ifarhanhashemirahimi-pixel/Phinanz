//
//  ExpenseStats.swift
//  Phbank
//
//  Aggregations for the summary screen.
//

import Foundation

struct CategoryTotal: Identifiable, Equatable {
    let category: ExpenseCategory
    let total: Double
    var id: String { category.rawValue }
}

struct StoreTotal: Identifiable, Equatable {
    let store: String
    let total: Double
    let count: Int
    var id: String { store }
}

enum ExpenseStats {
    static func total(_ expenses: [Expense]) -> Double {
        Money.roundCents(expenses.reduce(0) { $0 + $1.amount })
    }

    static func expenses(_ all: [Expense], in interval: DateInterval) -> [Expense] {
        all.filter { $0.date >= interval.start && $0.date < interval.end }
    }

    static func byCategory(_ expenses: [Expense]) -> [CategoryTotal] {
        Dictionary(grouping: expenses, by: { $0.category })
            .map { CategoryTotal(category: $0.key, total: total($0.value)) }
            .sorted { $0.total > $1.total }
    }

    static func topStores(_ expenses: [Expense], limit: Int = 5) -> [StoreTotal] {
        Dictionary(grouping: expenses, by: { $0.store.trimmingCharacters(in: .whitespaces).lowercased() })
            .compactMap { _, items -> StoreTotal? in
                guard let name = items.first?.store else { return nil }
                return StoreTotal(store: name, total: total(items), count: items.count)
            }
            .sorted { $0.total > $1.total }
            .prefix(limit)
            .map { $0 }
    }

    /// Twelve monthly totals (January first) for `year`.
    static func monthlyTotals(_ all: [Expense], year: Int, calendar: Calendar = .current) -> [Double] {
        var totals = [Double](repeating: 0, count: 12)
        for expense in all where calendar.component(.year, from: expense.date) == year {
            let month = calendar.component(.month, from: expense.date) - 1
            if totals.indices.contains(month) { totals[month] += expense.amount }
        }
        return totals.map(Money.roundCents)
    }

    static func average(total: Double, over days: Int) -> Double {
        guard days > 0 else { return 0 }
        return Money.roundCents(total / Double(days))
    }
}
