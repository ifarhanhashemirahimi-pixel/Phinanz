//
//  ReviewDraftsView.swift
//  Phbank
//
//  Lets the user check and correct AI-suggested entries before they are saved.
//

import SwiftUI
import SwiftData

struct ReviewDraftsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var existing: [Expense]

    @Bindable var importer: ImportController
    var onSaved: (Date) -> Void

    @State private var checkedDuplicates = false

    private var saveCount: Int {
        importer.drafts.filter { $0.include && $0.isValid }.count
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("AI can make mistakes. Check every entry before saving.", systemImage: "sparkles")
                        .font(.footnote)
                }
                ForEach($importer.drafts) { $draft in
                    DraftRow(draft: $draft)
                }
            }
            .navigationTitle("Review entries")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard") {
                        importer.drafts = []
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save \(saveCount)", action: save)
                        .disabled(saveCount == 0)
                        .accessibilityIdentifier("save-drafts")
                }
            }
            .onAppear(perform: markDuplicates)
        }
        .tint(JournalTheme.gold)
        .interactiveDismissDisabled()
    }

    private func markDuplicates() {
        guard !checkedDuplicates else { return }
        checkedDuplicates = true
        for index in importer.drafts.indices
        where DuplicateDetector.isDuplicate(importer.drafts[index], in: existing) {
            importer.drafts[index].isPossibleDuplicate = true
            importer.drafts[index].include = false
        }
    }

    private func save() {
        let toSave = importer.drafts.filter(\.include).compactMap { $0.makeExpense() }
        guard !toSave.isEmpty else { return }
        for expense in toSave { context.insert(expense) }
        try? context.save()

        let firstDate = toSave.map { $0.date }.min()
        importer.drafts = []
        dismiss()
        if let firstDate { onSaved(firstDate) }
    }
}

private struct DraftRow: View {
    @Binding var draft: DraftExpense

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $draft.include) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(draft.store.isEmpty ? "Untitled" : draft.store).font(.headline)
                    Text(draft.amount.map(Money.format) ?? "Check amount")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if draft.isPossibleDuplicate {
                Label("Possible duplicate — already in your journal", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if draft.include {
                TextField("Store or description", text: $draft.store)
                HStack {
                    TextField("Amount", text: $draft.amountText)
                        .keyboardType(.decimalPad)
                    Text("EUR").foregroundStyle(.secondary)
                }
                Picker("Category", selection: $draft.category) {
                    ForEach(ExpenseCategory.allCases) { item in
                        Label(item.title, systemImage: item.symbol).tag(item)
                    }
                }
                DatePicker("Date", selection: $draft.date)
            }
        }
        .padding(.vertical, 4)
    }
}
