//
//  ExpenseStats.swift
//  Phinanz
//
//  Aggregations for the summary screen, budgets and the widget.
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
    /// Plain sum of amounts (direction ignored).
    static func total(_ entries: [Expense]) -> Double {
        Money.roundCents(entries.reduce(0) { $0 + $1.amount })
    }

    static func spending(_ entries: [Expense]) -> Double {
        total(entries.filter { !$0.isIncome })
    }

    static func income(_ entries: [Expense]) -> Double {
        total(entries.filter(\.isIncome))
    }

    /// Income minus spending.
    static func net(_ entries: [Expense]) -> Double {
        Money.roundCents(income(entries) - spending(entries))
    }

    /// Starting balance plus everything booked up to (and including) `date`.
    static func balance(starting: Double, entries: [Expense], upTo date: Date = Date()) -> Double {
        Money.roundCents(starting + entries.filter { $0.date <= date }.reduce(0) { $0 + $1.signedAmount })
    }

    static func expenses(_ all: [Expense], in interval: DateInterval) -> [Expense] {
        all.filter { $0.date >= interval.start && $0.date < interval.end }
    }

    /// Spending per category (income is left out), largest first.
    static func byCategory(_ entries: [Expense]) -> [CategoryTotal] {
        Dictionary(grouping: entries.filter { !$0.isIncome }, by: { $0.category })
            .map { CategoryTotal(category: $0.key, total: total($0.value)) }
            .sorted { $0.total > $1.total }
    }

    static func topStores(_ entries: [Expense], limit: Int = 5) -> [StoreTotal] {
        Dictionary(grouping: entries.filter { !$0.isIncome }, by: { $0.store.trimmingCharacters(in: .whitespaces).lowercased() })
            .compactMap { _, items -> StoreTotal? in
                guard let name = items.first?.store else { return nil }
                return StoreTotal(store: name, total: total(items), count: items.count)
            }
            .sorted { $0.total > $1.total }
            .prefix(limit)
            .map { $0 }
    }

    /// Twelve monthly spending totals (January first) for `year`.
    static func monthlyTotals(_ all: [Expense], year: Int, calendar: Calendar = .current) -> [Double] {
        monthly(all.filter { !$0.isIncome }, year: year, calendar: calendar)
    }

    /// Twelve monthly income totals (January first) for `year`.
    static func monthlyIncome(_ all: [Expense], year: Int, calendar: Calendar = .current) -> [Double] {
        monthly(all.filter(\.isIncome), year: year, calendar: calendar)
    }

    private static func monthly(_ entries: [Expense], year: Int, calendar: Calendar) -> [Double] {
        var totals = [Double](repeating: 0, count: 12)
        for entry in entries where calendar.component(.year, from: entry.date) == year {
            let month = calendar.component(.month, from: entry.date) - 1
            if totals.indices.contains(month) { totals[month] += entry.amount }
        }
        return totals.map { Money.roundCents($0) }
    }

    static func average(total: Double, over days: Int) -> Double {
        guard days > 0 else { return 0 }
        return Money.roundCents(total / Double(days))
    }
}
