//
//  SearchView.swift
//  Phinanz
//
//  The search tab: recent entries, and results as you type.
//

import SwiftUI

struct SearchView: View {
    let expenses: [Expense]
    @Binding var activeSheet: ActiveSheet?

    @State private var query = ""

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var results: [Expense] {
        let text = trimmedQuery
        guard !text.isEmpty else { return [] }
        let amountQuery = Money.normalizeDigits(text).replacingOccurrences(of: ",", with: ".")
        return expenses
            .filter { entry in
                entry.store.localizedCaseInsensitiveContains(text)
                    || entry.category.title.localizedCaseInsensitiveContains(text)
                    || entry.note.localizedCaseInsensitiveContains(text)
                    || Money.plain(entry.amount).contains(amountQuery)
                    || entry.date.formatted(.dateTime.month(.wide)).localizedCaseInsensitiveContains(text)
            }
            .sorted { $0.date > $1.date }
            .prefix(100)
            .map { $0 }
    }

    private var recent: [Expense] {
        Array(expenses.sorted { $0.date > $1.date }.prefix(20))
    }

    var body: some View {
        NavigationStack {
            List {
                if trimmedQuery.isEmpty {
                    if !recent.isEmpty {
                        Section("Recent") {
                            ForEach(recent) { row($0) }
                        }
                    }
                } else {
                    ForEach(results) { row($0) }
                }
            }
            .listStyle(.insetGrouped)
            .overlay {
                if !trimmedQuery.isEmpty && results.isEmpty {
                    ContentUnavailableView.search(text: trimmedQuery)
                } else if trimmedQuery.isEmpty && expenses.isEmpty {
                    ContentUnavailableView(
                        "Search Your Journal",
                        systemImage: "magnifyingglass",
                        description: Text("Find entries by store, category, note, amount or month.")
                    )
                }
            }
            .navigationTitle("Search")
            .searchable(text: $query, prompt: Text("Stores, categories, amounts"))
        }
    }

    private func row(_ entry: Expense) -> some View {
        Button {
            activeSheet = .edit(entry)
        } label: {
            EntryRow(entry: entry, showsDate: true)
        }
        .tint(Color.primary)
    }
}
