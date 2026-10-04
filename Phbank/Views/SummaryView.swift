//
//  SummaryView.swift
//  Phbank
//
//  Monthly and yearly overview with a category donut and a monthly bar chart.
//

import SwiftUI
import Charts

struct SummaryView: View {
    enum Scope: String, CaseIterable, Identifiable {
        case month = "Month"
        case year = "Year"
        var id: String { rawValue }
    }

    @Environment(\.dismiss) private var dismiss

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

    private var periodExpenses: [Expense] { ExpenseStats.expenses(expenses, in: interval) }
    private var total: Double { ExpenseStats.total(periodExpenses) }
    private var categories: [CategoryTotal] { ExpenseStats.byCategory(periodExpenses) }
    private var topStores: [StoreTotal] { ExpenseStats.topStores(periodExpenses) }

    private var dayCount: Int {
        calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? 1
    }

    private var title: String {
        scope == .month
            ? anchor.formatted(.dateTime.month(.wide).year())
            : anchor.formatted(.dateTime.year())
    }

    private struct MonthTotal: Identifiable {
        let label: String
        let total: Double
        var id: String { label }
    }

    private var monthly: [MonthTotal] {
        let year = calendar.component(.year, from: anchor)
        let totals = ExpenseStats.monthlyTotals(expenses, year: year, calendar: calendar)
        let names = calendar.shortMonthSymbols
        return totals.enumerated().map { MonthTotal(label: names[$0.offset], total: $0.element) }
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Picker("Period", selection: $scope) {
                        ForEach(Scope.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    periodBar
                    totals

                    if periodExpenses.isEmpty {
                        ContentUnavailableView(
                            "No entries",
                            systemImage: "book.closed",
                            description: Text("Nothing was spent in this period.")
                        )
                    } else {
                        categoryChart
                        if scope == .year { monthlyChart }
                        categoryList
                        storeList
                    }
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

    private var periodBar: some View {
        HStack {
            Button { shift(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                .accessibilityLabel("Previous \(scope == .month ? "month" : "year")")
            Spacer()
            Text(title)
                .font(JournalTheme.classicBold(20, relativeTo: .title3))
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button { shift(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                .accessibilityLabel("Next \(scope == .month ? "month" : "year")")
        }
    }

    private var totals: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Total spent").font(.footnote).foregroundStyle(.secondary)
                Text(Money.format(total))
                    .font(JournalTheme.classicBold(32, relativeTo: .largeTitle))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Per day").font(.footnote).foregroundStyle(.secondary)
                Text(Money.format(ExpenseStats.average(total: total, over: dayCount)))
                    .font(JournalTheme.classic(20, relativeTo: .title3))
            }
        }
        .accessibilityElement(children: .combine)
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
        .accessibilityLabel("Spending by category")
        .accessibilityValue(categories.map { "\($0.category.title) \(Money.format($0.total))" }.joined(separator: ", "))
    }

    private var monthlyChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("By month").font(.headline)
            Chart(monthly) { item in
                BarMark(x: .value("Month", item.label), y: .value("Spent", item.total))
                    .foregroundStyle(JournalTheme.gold)
                    .cornerRadius(3)
            }
            .frame(height: 160)
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
                    Text("×\(item.count)").font(.footnote).foregroundStyle(.secondary)
                    Spacer()
                    Text(Money.format(item.total))
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: Helpers

    private func percent(_ value: Double) -> String {
        guard total > 0 else { return "" }
        return (value / total).formatted(.percent.precision(.fractionLength(0)))
    }

    private func shift(_ delta: Int) {
        anchor = calendar.date(byAdding: component, value: delta, to: anchor) ?? anchor
    }
}
