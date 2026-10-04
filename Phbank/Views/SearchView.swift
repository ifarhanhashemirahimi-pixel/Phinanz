//
//  SearchView.swift
//  Phbank
//

import SwiftUI

struct SearchView: View {
    @Environment(\.dismiss) private var dismiss

    let expenses: [Expense]
    var onSelect: (Date) -> Void

    @State private var searchText = ""
    @State private var jumpDate = Date()

    private var results: [Expense] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        let amountQuery = query.replacingOccurrences(of: ",", with: ".")

        return expenses
            .filter { expense in
                expense.store.localizedCaseInsensitiveContains(query)
                    || expense.category.title.localizedCaseInsensitiveContains(query)
                    || expense.note.localizedCaseInsensitiveContains(query)
                    || Money.plain(expense.amount).contains(amountQuery)
                    || expense.date.formatted(.dateTime.month(.wide).day()).localizedCaseInsensitiveContains(query)
            }
            .sorted { $0.date > $1.date }
            .prefix(100)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Go to date") {
                    DatePicker("Date", selection: $jumpDate, displayedComponents: .date)
                    Button("Open this page") {
                        onSelect(jumpDate)
                        dismiss()
                    }
                }

                if !searchText.isEmpty {
                    Section("Entries") {
                        if results.isEmpty {
                            ContentUnavailableView.search(text: searchText)
                        }
                        ForEach(results) { expense in
                            Button {
                                onSelect(expense.date)
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: expense.category.symbol)
                                        .foregroundStyle(expense.category.color)
                                        .frame(width: 28)
                                        .accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(expense.store).font(.headline)
                                        Text(expense.date.formatted(date: .abbreviated, time: .omitted))
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(verbatim: (expense.isIncome ? "+" : "") + Money.format(expense.amount))
                                        .foregroundStyle(expense.isIncome ? JournalTheme.incomeLight : Color.primary)
                                }
                                .foregroundStyle(.primary)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Store, category, amount or month")
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(JournalTheme.gold)
    }
}
