//
//  YearlyDayPageView.swift
//  Phbank
//
//  One ruled notebook page = one day of the year.
//

import SwiftUI

struct YearlyDayPageView: View {
    let date: Date
    let expenses: [Expense]
    let isToday: Bool
    var onAdd: () -> Void
    var onEdit: (Expense) -> Void

    private static let titleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yy.MMMM.dd" // e.g. 26.October.04, month name in the app language
        return formatter
    }()

    private let lineHeight: CGFloat = 40

    private var spent: Double { ExpenseStats.spending(expenses) }
    private var earned: Double { ExpenseStats.income(expenses) }

    /// Keeps the ruled-paper look on quiet days.
    private var emptyLineCount: Int { max(0, 12 - expenses.count) }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(expenses) { expense in
                        row(expense)
                    }
                    addRow
                    ForEach(0..<emptyLineCount, id: \.self) { _ in
                        Color.clear.frame(height: lineHeight - 0.5)
                        ruledLine
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .background(JournalTheme.ivory)
        .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
        .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 10)
        .padding(20)
    }

    // MARK: Pieces

    private var header: some View {
        HStack(alignment: .lastTextBaseline) {
            HStack(spacing: 8) {
                Text(Self.titleFormatter.string(from: date))
                    .font(JournalTheme.classic(26, relativeTo: .title2))
                    .foregroundStyle(JournalTheme.ink)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
                    .accessibilityAddTraits(.isHeader)

                if isToday {
                    Circle()
                        .fill(JournalTheme.gold)
                        .frame(width: 8, height: 8)
                        .accessibilityLabel(Text("Today"))
                }
            }
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 2) {
                Text("TOTAL SPENT")
                    .font(JournalTheme.classic(10, relativeTo: .caption2))
                    .tracking(1)
                    .foregroundStyle(JournalTheme.brown)
                Text(Money.format(spent))
                    .font(JournalTheme.classicBold(20, relativeTo: .title3))
                    .foregroundStyle(JournalTheme.ink)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                if earned > 0 {
                    Text(verbatim: "+" + Money.format(earned))
                        .font(JournalTheme.classic(13, relativeTo: .footnote))
                        .foregroundStyle(JournalTheme.incomeInk)
                        .accessibilityLabel(Text("Income \(Money.format(earned))"))
                }
            }
            .accessibilityElement(children: .combine)
        }
        .padding(.horizontal, 30)
        .padding(.top, 34)
        .padding(.bottom, 14)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(JournalTheme.gold.opacity(0.7))
                .frame(height: 1)
                .padding(.horizontal, 30)
        }
    }

    private var ruledLine: some View {
        Rectangle()
            .fill(JournalTheme.brown.opacity(0.35))
            .frame(height: 0.5)
    }

    private func row(_ expense: Expense) -> some View {
        let time = expense.date.formatted(date: .omitted, time: .shortened)
        let amountColor = expense.isIncome ? JournalTheme.incomeInk : JournalTheme.ink
        return Button {
            onEdit(expense)
        } label: {
            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(time)
                        .font(JournalTheme.handwriting(15, relativeTo: .footnote))
                        .foregroundStyle(JournalTheme.brown)
                        .frame(minWidth: 50, alignment: .leading)

                    Image(systemName: expense.source == .recurring ? "arrow.triangle.2.circlepath" : expense.category.symbol)
                        .font(.footnote)
                        .foregroundStyle(expense.isIncome ? JournalTheme.incomeInk : JournalTheme.brown)
                        .accessibilityHidden(true)

                    Text(expense.store)
                        .font(JournalTheme.handwriting(18))
                        .foregroundStyle(JournalTheme.ink)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text((expense.isIncome ? "+" : "") + Money.number(expense.amount))
                        .font(JournalTheme.handwriting(18))
                        .foregroundStyle(amountColor)
                }
                .frame(minHeight: lineHeight - 0.5)
                ruledLine
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText(for: expense, time: time))
        .accessibilityHint(Text("Opens the entry for editing"))
    }

    private func accessibilityText(for expense: Expense, time: String) -> Text {
        let amount = Money.format(expense.amount)
        if expense.isIncome {
            return Text("Income: \(expense.store), \(amount), \(expense.category.title), \(time)")
        }
        return Text(verbatim: "\(expense.store), \(amount), \(expense.category.title), \(time)")
    }

    private var addRow: some View {
        Button(action: onAdd) {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle")
                    Text("Add entry")
                        .font(JournalTheme.handwriting(17))
                    Spacer()
                }
                .foregroundStyle(JournalTheme.brown.opacity(0.8))
                .frame(minHeight: lineHeight - 0.5)
                ruledLine
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Add entry for this day"))
        .accessibilityIdentifier("add-entry")
    }
}
