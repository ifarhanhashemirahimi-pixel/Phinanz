//
//  MonthlyReport.swift
//  Phinanz
//
//  The monthly report: numbers for one month compared with the month
//  before, plus a few plain-language insights. Pure logic, no UI.
//

import Foundation

struct MonthlyReport: Equatable {
    struct CategoryChange: Identifiable, Equatable {
        let category: ExpenseCategory
        let current: Double
        let previous: Double
        var delta: Double { Money.roundCents(current - previous) }
        var id: String { category.rawValue }
    }

    /// An expense that could matter for the tax return (a hint, not advice).
    struct TaxItem: Identifiable, Equatable {
        let store: String
        let amount: Double
        let date: Date
        /// nil when the user marked it without an automatic suggestion.
        let kind: TaxHintKind?
        var id: String { "\(store)|\(date.timeIntervalSince1970)|\(amount)" }
    }

    struct BiggestExpense: Equatable {
        let store: String
        let amount: Double
        let date: Date
    }

    enum Tone: Equatable {
        case positive, negative, neutral
    }

    struct Insight: Identifiable, Equatable {
        let symbol: String
        let text: String
        let tone: Tone
        var id: String { text }
    }

    let month: DateInterval
    let previousMonth: DateInterval
    let spending: Double
    let income: Double
    let previousSpending: Double
    let previousIncome: Double
    let dailyAverage: Double
    let entryCount: Int
    /// Spending booked by recurring payments (rent, subscriptions …).
    let fixedCosts: Double
    let categories: [CategoryChange]
    let topStores: [StoreTotal]
    let biggestExpense: BiggestExpense?
    let overBudget: [ExpenseCategory]
    let hasBudgets: Bool
    /// Possibly tax-relevant expenses in this month.
    var taxItems: [TaxItem] = []
    /// The same, added up from 1 January to the end of this month.
    var yearTaxTotal: Double = 0
    var insights: [Insight]

    var taxTotal: Double { Money.roundCents(taxItems.reduce(0) { $0 + $1.amount }) }

    var net: Double { Money.roundCents(income - spending) }

    /// Change against the previous month as a fraction (0.12 = 12 % more); nil without a previous month.
    var spendingChange: Double? {
        previousSpending > 0 ? (spending - previousSpending) / previousSpending : nil
    }

    /// Share of income that was not spent; nil without income.
    var savingsRate: Double? {
        income > 0 ? net / income : nil
    }

    var isEmpty: Bool { entryCount == 0 }
}

enum ReportBuilder {
    static func build(
        month date: Date,
        entries: [Expense],
        budgets: [CategoryBudget],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> MonthlyReport {
        let month = calendar.dateInterval(of: .month, for: date) ?? DateInterval(start: date, duration: 30 * 86_400)
        let previousStart = calendar.date(byAdding: .month, value: -1, to: month.start) ?? month.start
        let previous = calendar.dateInterval(of: .month, for: previousStart) ?? month

        let current = ExpenseStats.expenses(entries, in: month)
        let before = ExpenseStats.expenses(entries, in: previous)
        let spending = ExpenseStats.spending(current)
        let income = ExpenseStats.income(current)
        let previousSpending = ExpenseStats.spending(before)

        // Days so far for the running month, all days for past months.
        let daysInMonth = calendar.range(of: .day, in: .month, for: month.start)?.count ?? 30
        let daysCounted: Int
        if month.contains(now) {
            daysCounted = (calendar.dateComponents([.day], from: month.start, to: now).day ?? 0) + 1
        } else {
            daysCounted = daysInMonth
        }

        let currentByCategory = Dictionary(uniqueKeysWithValues: ExpenseStats.byCategory(current).map { ($0.category, $0.total) })
        let previousByCategory = Dictionary(uniqueKeysWithValues: ExpenseStats.byCategory(before).map { ($0.category, $0.total) })
        let categories = Set(currentByCategory.keys).union(previousByCategory.keys)
            .map { MonthlyReport.CategoryChange(category: $0, current: currentByCategory[$0] ?? 0, previous: previousByCategory[$0] ?? 0) }
            .sorted { ($0.current, $0.previous) > ($1.current, $1.previous) }

        let biggest = current.filter { !$0.isIncome }.max { $0.amount < $1.amount }
            .map { MonthlyReport.BiggestExpense(store: $0.store, amount: $0.amount, date: $0.date) }

        let statuses = BudgetCalculator.statuses(budgets: budgets, entries: entries, in: month)
        let overBudget = statuses.filter { $0.level == .over }.map(\.category)

        let fixed = ExpenseStats.spending(current.filter { $0.source == .recurring })

        let yearStart = calendar.dateInterval(of: .year, for: month.start)?.start ?? month.start
        let yearSoFar = ExpenseStats.expenses(entries, in: DateInterval(start: yearStart, end: month.end))
        let taxItems = TaxHints.relevant(current).map {
            MonthlyReport.TaxItem(store: $0.store, amount: $0.amount, date: $0.date, kind: TaxHints.suggestion(for: $0))
        }
        let yearTaxTotal = Money.roundCents(TaxHints.relevant(yearSoFar).reduce(0) { $0 + $1.amount })

        var report = MonthlyReport(
            month: month,
            previousMonth: previous,
            spending: spending,
            income: income,
            previousSpending: previousSpending,
            previousIncome: ExpenseStats.income(before),
            dailyAverage: ExpenseStats.average(total: spending, over: daysCounted),
            entryCount: current.count,
            fixedCosts: fixed,
            categories: categories,
            topStores: ExpenseStats.topStores(current, limit: 3),
            biggestExpense: biggest,
            overBudget: overBudget,
            hasBudgets: !budgets.isEmpty,
            taxItems: taxItems,
            yearTaxTotal: yearTaxTotal,
            insights: []
        )
        report.insights = insights(for: report)
        return report
    }

    static func insights(for report: MonthlyReport) -> [MonthlyReport.Insight] {
        guard !report.isEmpty else { return [] }
        var list: [MonthlyReport.Insight] = []
        let previousName = report.previousMonth.start.formatted(.dateTime.month(.wide))
        func percent(_ value: Double) -> String { abs(value).formatted(.percent.precision(.fractionLength(0))) }

        if let change = report.spendingChange, abs(change) >= 0.01 {
            if change < 0 {
                list.append(.init(symbol: "arrow.down.right.circle.fill",
                                  text: String(localized: "You spent \(percent(change)) less than in \(previousName)."),
                                  tone: .positive))
            } else {
                list.append(.init(symbol: "arrow.up.right.circle.fill",
                                  text: String(localized: "You spent \(percent(change)) more than in \(previousName)."),
                                  tone: .negative))
            }
        }

        if let rate = report.savingsRate {
            if rate > 0 {
                list.append(.init(symbol: "leaf.fill",
                                  text: String(localized: "You kept \(percent(rate)) of your income."),
                                  tone: .positive))
            } else if report.net < 0 {
                list.append(.init(symbol: "exclamationmark.triangle.fill",
                                  text: String(localized: "You spent \(Money.format(-report.net)) more than you earned."),
                                  tone: .negative))
            }
        }

        let threshold = 20.0
        if let rise = report.categories.filter({ $0.previous > 0 && $0.delta >= threshold }).max(by: { $0.delta < $1.delta }) {
            list.append(.init(symbol: rise.category.symbol,
                              text: String(localized: "\(rise.category.title): \(Money.format(rise.delta)) more than in \(previousName)."),
                              tone: .negative))
        }
        if let drop = report.categories.filter({ $0.previous > 0 && $0.delta <= -threshold }).min(by: { $0.delta < $1.delta }) {
            list.append(.init(symbol: drop.category.symbol,
                              text: String(localized: "\(drop.category.title): \(Money.format(-drop.delta)) less than in \(previousName)."),
                              tone: .positive))
        }

        if report.spending > 0, report.fixedCosts > 0 {
            list.append(.init(symbol: "repeat.circle.fill",
                              text: String(localized: "Fixed costs were \(percent(report.fixedCosts / report.spending)) of your spending."),
                              tone: .neutral))
        }

        if !report.overBudget.isEmpty {
            let names = report.overBudget.map(\.title).formatted(.list(type: .and))
            list.append(.init(symbol: "chart.bar.xaxis",
                              text: String(localized: "Over budget: \(names)."),
                              tone: .negative))
        } else if report.hasBudgets {
            list.append(.init(symbol: "checkmark.seal.fill",
                              text: String(localized: "You stayed within all your budgets."),
                              tone: .positive))
        }

        if !report.taxItems.isEmpty {
            list.append(.init(symbol: "doc.text.magnifyingglass",
                              text: String(localized: "\(Money.format(report.taxTotal)) of this month's spending could matter for your tax return."),
                              tone: .neutral))
        }

        if let biggest = report.biggestExpense {
            list.append(.init(symbol: "magnifyingglass.circle.fill",
                              text: String(localized: "Biggest expense: \(biggest.store), \(Money.format(biggest.amount))."),
                              tone: .neutral))
        }
        return list
    }
}
