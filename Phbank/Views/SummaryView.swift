//
//  SummaryView.swift
//  Phbank
//
//  Week / month / year overview in the style of Wallet and Health:
//  a spending card with a stacked bar chart, metric tiles, categories, stores.
//

import SwiftUI
import SwiftData
import Charts

struct SummaryView: View {
    enum Scope: String, CaseIterable, Identifiable {
        case week, month, year
        var id: String { rawValue }
        var title: LocalizedStringKey {
            switch self {
            case .week: "Week"
            case .month: "Month"
            case .year: "Year"
            }
        }
    }

    let expenses: [Expense]
    @Binding var activeSheet: ActiveSheet?
    @Query private var accounts: [Account]
    @Query private var budgets: [CategoryBudget]

    @State private var scope: Scope = .month
    @State private var anchor = Date()

    private let calendar = Calendar.current

    // MARK: Derived data

    private var component: Calendar.Component {
        switch scope {
        case .week: .weekOfYear
        case .month: .month
        case .year: .year
        }
    }

    private var interval: DateInterval {
        calendar.dateInterval(of: component, for: anchor) ?? DateInterval(start: anchor, duration: 86_400)
    }

    private var periodEntries: [Expense] { ExpenseStats.expenses(expenses, in: interval) }
    private var spent: Double { ExpenseStats.spending(periodEntries) }
    private var earned: Double { ExpenseStats.income(periodEntries) }
    private var net: Double { Money.roundCents(earned - spent) }
    private var categories: [CategoryTotal] { ExpenseStats.byCategory(periodEntries) }
    private var topStores: [StoreTotal] { ExpenseStats.topStores(periodEntries) }
    private var balance: Double { AccountLedger.total(accounts: accounts, entries: expenses) }

    private var dayCount: Int {
        calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? 1
    }

    private var periodTitle: String {
        switch scope {
        case .week:
            let last = interval.end.addingTimeInterval(-1)
            return "\(interval.start.formatted(.dateTime.day().month(.abbreviated))) – \(last.formatted(.dateTime.day().month(.abbreviated).year()))"
        case .month:
            return anchor.formatted(.dateTime.month(.wide).year())
        case .year:
            return anchor.formatted(.dateTime.year())
        }
    }

    private struct ChartPoint: Identifiable {
        let bucket: Date
        let category: ExpenseCategory
        let amount: Double
        var id: String { "\(bucket.timeIntervalSince1970)-\(category.rawValue)" }
    }

    private var chartUnit: Calendar.Component { scope == .year ? .month : .day }

    private var points: [ChartPoint] {
        let spending = periodEntries.filter { !$0.isIncome }
        var sums: [Date: [ExpenseCategory: Double]] = [:]
        for entry in spending {
            let bucket = calendar.dateInterval(of: chartUnit, for: entry.date)?.start ?? entry.date
            sums[bucket, default: [:]][entry.category, default: 0] += entry.amount
        }
        return sums.flatMap { bucket, byCategory in
            byCategory.map { ChartPoint(bucket: bucket, category: $0.key, amount: Money.roundCents($0.value)) }
        }
        .sorted { $0.bucket < $1.bucket }
    }

    private var axisValues: AxisMarkValues {
        switch scope {
        case .week: .stride(by: .day)
        case .month: .stride(by: .day, count: 7)
        case .year: .stride(by: .month)
        }
    }

    private func axisLabel(_ date: Date) -> String {
        switch scope {
        case .week: date.formatted(.dateTime.weekday(.narrow))
        case .month: date.formatted(.dateTime.day())
        case .year: date.formatted(.dateTime.month(.narrow))
        }
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("Period", selection: $scope) {
                        ForEach(Scope.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    periodBar
                    reportLink
                    spendingCard
                    tiles
                    if !categories.isEmpty { categoriesCard }
                    if !topStores.isEmpty { storesCard }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
                .animation(.snappy, value: scope)
            }
            .background(Theme.groupedBackground)
            .navigationTitle("Summary")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    SettingsToolbarButton(activeSheet: $activeSheet)
                }
            }
            .sensoryFeedback(.selection, trigger: anchor)
        }
    }

    // MARK: Sections

    private var periodBar: some View {
        HStack {
            Button { shift(-1) } label: {
                Image(systemName: "chevron.backward")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(Text("Previous Period"))
            Spacer()
            Text(periodTitle)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button { shift(1) } label: {
                Image(systemName: "chevron.forward")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(Text("Next Period"))
        }
        .fontWeight(.semibold)
    }

    /// Opens the monthly report for the month on screen (or this month).
    private var reportLink: some View {
        NavigationLink {
            MonthlyReportView(expenses: expenses, budgets: budgets, month: scope == .year ? Date() : anchor)
        } label: {
            HStack(spacing: 12) {
                SettingsIcon(systemName: "doc.text.magnifyingglass", color: .indigo, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Monthly Report")
                        .font(.headline)
                        .foregroundStyle(Color.primary)
                    Text("Compare months, see insights, share as PDF")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                }
                Spacer()
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .card()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("open-report")
    }

    private var spendingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Spending", systemImage: "creditcard.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(Money.format(spent))
                    .font(Theme.amount(.largeTitle, weight: .bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .accessibilityIdentifier("summary-total")
                Text("\(Money.format(ExpenseStats.average(total: spent, over: dayCount))) per day on average")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if points.isEmpty {
                Text("No spending in this period.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                Chart(points) { point in
                    BarMark(
                        x: .value("Date", point.bucket, unit: chartUnit),
                        y: .value("Amount", point.amount)
                    )
                    .foregroundStyle(point.category.color)
                }
                .chartXScale(domain: interval.start...interval.end)
                .chartXAxis {
                    AxisMarks(values: axisValues) { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(verbatim: axisLabel(date))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text(amount, format: .currency(code: "EUR").precision(.fractionLength(0)))
                            }
                        }
                    }
                }
                .frame(height: 180)
                .accessibilityLabel(Text("Spending chart"))
            }
        }
        .card()
    }

    private var tiles: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            tile("Income", systemImage: "arrow.down.circle.fill", value: Money.format(earned), color: .green)
            tile("Net", systemImage: "plusminus.circle.fill",
                 value: (net > 0 ? "+" : "") + Money.format(net),
                 color: net >= 0 ? .blue : .red)
            tile("Balance", systemImage: "building.columns.fill", value: Money.format(balance), color: .indigo)
            tile("Entries", systemImage: "list.bullet.circle.fill", value: "\(periodEntries.count)", color: .orange)
        }
    }

    private func tile(_ title: LocalizedStringKey, systemImage: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
            Text(verbatim: value)
                .font(Theme.amount(.title3))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .card()
        .accessibilityElement(children: .combine)
    }

    private var categoriesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Categories")
                .font(.headline)
            CategoryShareBar(totals: categories, height: 10)
            ForEach(categories) { item in
                HStack(spacing: 12) {
                    CategoryIcon(category: item.category, size: 30)
                    Text(item.category.title)
                    Spacer()
                    Text(verbatim: percent(item.total))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(Money.format(item.total))
                        .monospacedDigit()
                        .frame(minWidth: 76, alignment: .trailing)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .card()
    }

    private var storesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Top Stores")
                .font(.headline)
            ForEach(Array(topStores.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 12) {
                    Text(verbatim: "\(index + 1)")
                        .font(Theme.amount(.subheadline))
                        .foregroundStyle(.secondary)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.store).lineLimit(1)
                        Text("\(item.count) entries")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(Money.format(item.total))
                        .monospacedDigit()
                }
                .accessibilityElement(children: .combine)
            }
        }
        .card()
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
