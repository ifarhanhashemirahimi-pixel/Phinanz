//
//  ReviewDraftsView.swift
//  Phbank
//
//  Lets the user check and correct suggested entries (AI or bank CSV) before they are saved.
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
    @State private var accountID = UserDefaults.standard.string(forKey: SettingsKeys.lastAccountID) ?? ""

    private var saveCount: Int {
        importer.drafts.filter { $0.include && $0.isValid }.count
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if importer.origin == .bankFile {
                        Label {
                            Text("Read from your bank export on this iPhone. Check the categories, and switch off transfers you don't want in your journal.")
                        } icon: {
                            Image(systemName: "building.columns.fill").foregroundStyle(.green)
                        }
                        .font(.footnote)
                    } else {
                        Label {
                            Text("AI can make mistakes. Check every entry before saving.")
                        } icon: {
                            Image(systemName: "sparkles").foregroundStyle(.purple)
                        }
                        .font(.footnote)
                    }
                    AccountPicker(accountID: $accountID)
                    if importer.drafts.count > 3 {
                        Button(allIncluded ? "Deselect All" : "Select All") {
                            let include = !allIncluded
                            for index in importer.drafts.indices { importer.drafts[index].include = include }
                        }
                    }
                }
                if importer.origin == .bankFile {
                    Section("\(importer.drafts.count) Bookings") {
                        ForEach($importer.drafts) { $draft in
                            CompactDraftRow(draft: $draft)
                        }
                    }
                } else {
                    ForEach($importer.drafts) { $draft in
                        Section {
                            DraftRow(draft: $draft)
                        }
                    }
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
            #if DEBUG
            .onReceive(DemoDirector.shared.commands) { command in
                if case .saveReview = command { save() }
            }
            #endif
        }
        .interactiveDismissDisabled()
    }

    private var allIncluded: Bool {
        importer.drafts.allSatisfy(\.include)
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
        let toSave = importer.drafts.filter(\.include).compactMap { $0.makeExpense(accountID: accountID) }
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
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $draft.include) {
                HStack(spacing: 12) {
                    CategoryIcon(category: draft.category, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(draft.amount.map { (draft.isIncome ? "+" : "") + Money.format($0) } ?? String(localized: "Check amount"))
                            .font(Theme.amount(.title3))
                            .monospacedDigit()
                            .foregroundStyle(draft.isIncome ? AnyShapeStyle(Theme.income) : AnyShapeStyle(.primary))
                        Text(draft.source.title)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if draft.isPossibleDuplicate {
                Label("Possible duplicate — already in your journal", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            if draft.include {
                Picker("Type", selection: $draft.isIncome) {
                    Text("Expense").tag(false)
                    Text("Income").tag(true)
                }
                .pickerStyle(.segmented)

                LabeledContent("Store") {
                    TextField("Store or description", text: $draft.store)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Amount") {
                    HStack(spacing: 4) {
                        TextField("Amount", text: $draft.amountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text(verbatim: "€").foregroundStyle(.secondary)
                    }
                }
                Picker("Category", selection: $draft.category) {
                    ForEach(draft.isIncome ? ExpenseCategory.incomeCases : ExpenseCategory.expenseCases) { item in
                        Label(item.title, systemImage: item.symbol).tag(item)
                    }
                }
                DatePicker("Date", selection: $draft.date)
            }
        }
        .padding(.vertical, 6)
        .onChange(of: draft.isIncome) { _, income in
            if draft.category.isIncome != income { draft.category = income ? .salary : .other }
        }
    }
}

/// One booking from a bank export: compact, because a month can hold a hundred of them.
private struct CompactDraftRow: View {
    @Binding var draft: DraftExpense

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $draft.include) {
                HStack(spacing: 12) {
                    CategoryIcon(category: draft.category, size: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(draft.store)
                            .lineLimit(1)
                        Text(draft.date, format: .dateTime.day().month(.abbreviated).year())
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Text(draft.amount.map { (draft.isIncome ? "+" : "") + Money.format($0) } ?? "–")
                        .font(Theme.amount(.body))
                        .monospacedDigit()
                        .foregroundStyle(draft.isIncome ? AnyShapeStyle(Theme.income) : AnyShapeStyle(.primary))
                }
            }

            if draft.isPossibleDuplicate {
                Label("Possible duplicate — already in your journal", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            if draft.include {
                Picker("Category", selection: $draft.category) {
                    ForEach(draft.isIncome ? ExpenseCategory.incomeCases : ExpenseCategory.expenseCases) { item in
                        Label(item.title, systemImage: item.symbol).tag(item)
                    }
                }
                .font(.subheadline)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .contain)
    }
}
