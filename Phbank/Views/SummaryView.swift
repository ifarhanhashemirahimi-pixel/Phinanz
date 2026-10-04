//
//  SummaryView.swift
//  Phbank
//
//  Month / year overview: spending, income, balance, budgets and charts.
//

import SwiftUI
import SwiftData
import Charts

struct SummaryView: View {
    enum Scope: String, CaseIterable, Identifiable {
        case month, year
        var id: String { rawValue }
        var title: LocalizedStringKey { self == .month ? "Month" : "Year" }
    }

    @Environment(\.dismiss) private var dismiss
    @Query private var budgets: [CategoryBudget]
    @AppStorage(SettingsKeys.startingBalance) private var startingBalance = 0.0

    let expenses: [Expense]
    @State private var scope: Scope = .month
    @State private var anchor: Date

    private let calendar = Calendar.current

    init(expenses: [Expense], anchor: Date) {
        self.expenses = expenses
        _anchor = State(initialValue: anchor)
    }

    // MARK: Derived data

    private var component: Calendar.Component { scope == .month ? .month : .year }

    private var interval: DateInterval {
        calendar.dateInterval(of: component, for: anchor) ?? DateInterval(start: anchor, duration: 86_400)
    }

    private var periodEntries: [Expense] { ExpenseStats.expenses(expenses, in: interval) }
    private var spent: Double { ExpenseStats.spending(periodEntries) }
    private var earned: Double { ExpenseStats.income(periodEntries) }
    private var net: Double { Money.roundCents(earned - spent) }
    private var categories: [CategoryTotal] { ExpenseStats.byCategory(periodEntries) }
    private var topStores: [StoreTotal] { ExpenseStats.topStores(periodEntries) }
    private var balance: Double { ExpenseStats.balance(starting: startingBalance, entries: expenses) }

    private var budgetStatuses: [BudgetStatus] {
        guard scope == .month else { return [] }
        return BudgetCalculator.statuses(budgets: budgets, entries: expenses, in: interval)
    }

    private var dayCount: Int {
        calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? 1
    }

    private var title: String {
        scope == .month
            ? anchor.formatted(.dateTime.month(.wide).year())
            : anchor.formatted(.dateTime.year())
    }

    private struct MonthBar: Identifiable {
        let label: String
        let kind: String
        let total: Double
        var id: String { label + kind }
    }

    private var monthly: [MonthBar] {
        let year = calendar.component(.year, from: anchor)
        let spending = ExpenseStats.monthlyTotals(expenses, year: year, calendar: calendar)
        let income = ExpenseStats.monthlyIncome(expenses, year: year, calendar: calendar)
        let names = calendar.veryShortMonthSymbols
        let spentLabel = String(localized: "Spent")
        let incomeLabel = String(localized: "Income")
        return (0..<12).flatMap { index in
            [
                MonthBar(label: names[index] + "\u{200B}\(index)", kind: spentLabel, total: spending[index]),
                MonthBar(label: names[index] + "\u{200B}\(index)", kind: incomeLabel, total: income[index])
            ]
        }
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Picker("Period", selection: $scope) {
                        ForEach(Scope.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    periodBar
                    totals
                    balanceCard

                    if !budgetStatuses.isEmpty { budgetSection }

                    if periodEntries.isEmpty {
                        ContentUnavailableView(
                            "No entries",
                            systemImage: "book.closed",
                            description: Text("Nothing was booked in this period.")
                        )
                    } else {
                        if !categories.isEmpty { categoryChart }
                        if scope == .year { monthlyChart }
                        if !categories.isEmpty { categoryList }
                        if !topStores.isEmpty { storeList }
                    }

                    planningLinks
                }
                .padding(20)
            }
            .navigationTitle("Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(JournalTheme.gold)
    }

    // MARK: Sections

    private var periodBar: some View {
        HStack {
            Button { shift(-1) } label: { Image(systemName: "chevron.backward").frame(width: 44, height: 44) }
                .accessibilityLabel(scope == .month ? Text("Previous month") : Text("Previous year"))
            Spacer()
            Text(title)
                .font(JournalTheme.classicBold(20, relativeTo: .title3))
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button { shift(1) } label: { Image(systemName: "chevron.forward").frame(width: 44, height: 44) }
                .accessibilityLabel(scope == .month ? Text("Next month") : Text("Next year"))
        }
    }

    private var totals: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total spent").font(.footnote).foregroundStyle(.secondary)
                    Text(Money.format(spent))
                        .font(JournalTheme.classicBold(32, relativeTo: .largeTitle))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Per day").font(.footnote).foregroundStyle(.secondary)
                    Text(Money.format(ExpenseStats.average(total: spent, over: dayCount)))
                        .font(JournalTheme.classic(20, relativeTo: .title3))
                }
            }
            .accessibilityElement(children: .combine)

            HStack {
                metric(title: "Income", value: Money.format(earned), color: JournalTheme.incomeLight)
                Spacer()
                metric(title: "Net", value: (net >= 0 ? "+" : "") + Money.format(net),
                       color: net >= 0 ? JournalTheme.incomeLight : .red)
            }
        }
    }

    private func metric(title: LocalizedStringKey, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.footnote).foregroundStyle(.secondary)
            Text(value).font(JournalTheme.classicBold(18, relativeTo: .headline)).foregroundStyle(color)
        }
        .accessibilityElement(children: .combine)
    }

    private var balanceCard: some View {
        HStack {
            Image(systemName: "building.columns")
                .font(.title2)
                .foregroundStyle(JournalTheme.gold)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Current balance").font(.footnote).foregroundStyle(.secondary)
                Text(Money.format(balance))
                    .font(JournalTheme.classicBold(22, relativeTo: .title2))
                    .foregroundStyle(balance >= 0 ? Color.primary : Color.red)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.gray.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    private var budgetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Budgets").font(.headline)
            ForEach(budgetStatuses) { status in
                BudgetRow(status: status)
            }
        }
    }

    private var categoryChart: some View {
        Chart(categories) { item in
            SectorMark(
                angle: .value("Spent", item.total),
                innerRadius: .ratio(0.62),
                angularInset: 1.5
            )
            .foregroundStyle(item.category.color)
            .cornerRadius(3)
        }
        .frame(height: 200)
        .accessibilityLabel(Text("Spending by category"))
        .accessibilityValue(Text(verbatim: categories.map { "\($0.category.title) \(Money.format($0.total))" }.joined(separator: ", ")))
    }

    private var monthlyChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("By month").font(.headline)
            Chart(monthly) { item in
                BarMark(x: .value("Month", item.label), y: .value("Amount", item.total))
                    .foregroundStyle(by: .value("Type", item.kind))
                    .position(by: .value("Type", item.kind))
                    .cornerRadius(2)
            }
            .chartForegroundStyleScale([
                String(localized: "Spent"): JournalTheme.gold,
                String(localized: "Income"): JournalTheme.incomeLight
            ])
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            Text(verbatim: String(label.prefix { $0 != "\u{200B}" }))
                        }
                    }
                }
            }
            .frame(height: 180)
        }
    }

    private var categoryList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Categories").font(.headline)
            ForEach(categories) { item in
                HStack(spacing: 12) {
                    Image(systemName: item.category.symbol)
                        .foregroundStyle(item.category.color)
                        .frame(width: 28)
                        .accessibilityHidden(true)
                    Text(item.category.title)
                    Spacer()
                    Text(percent(item.total))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(Money.format(item.total))
                        .frame(minWidth: 80, alignment: .trailing)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var storeList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Top stores").font(.headline)
            ForEach(topStores) { item in
                HStack {
                    Text(item.store).lineLimit(1)
                    Text(verbatim: "×\(item.count)").font(.footnote).foregroundStyle(.secondary)
                    Spacer()
                    Text(Money.format(item.total))
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var planningLinks: some View {
        VStack(spacing: 0) {
            NavigationLink {
                BudgetsView()
            } label: {
                linkRow(title: "Monthly budgets", icon: "gauge.with.dots.needle.33percent")
            }
            Divider().padding(.leading, 44)
            NavigationLink {
                RecurringListView()
            } label: {
                linkRow(title: "Recurring payments", icon: "arrow.triangle.2.circlepath")
            }
        }
        .background(Color.gray.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
    }

    private func linkRow(title: LocalizedStringKey, icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).foregroundStyle(JournalTheme.gold).frame(width: 28)
            Text(title).foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.forward").font(.footnote).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 50)
        .contentShape(Rectangle())
    }

    // MARK: Helpers

    private func percent(_ value: Double) -> String {
        guard spent > 0 else { return "" }
        return (value / spent).formatted(.percent.precision(.fractionLength(0)))
    }

    private func shift(_ delta: Int) {
        anchor = calendar.date(byAdding: component, value: delta, to: anchor) ?? anchor
    }
}

struct BudgetRow: View {
    let status: BudgetStatus

    private var tint: Color {
        switch status.level {
        case .ok: JournalTheme.incomeLight
        case .warning: .orange
        case .over: .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: status.category.symbol)
                    .foregroundStyle(status.category.color)
                    .accessibilityHidden(true)
                Text(status.category.title)
                Spacer()
                Text(verbatim: "\(Money.format(status.spent)) / \(Money.format(status.limit))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: min(status.ratio, 1))
                .tint(tint)
            if status.level == .over {
                Text("Over budget by \(Money.format(-status.remaining))")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else {
                Text("\(Money.format(status.remaining)) left")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
