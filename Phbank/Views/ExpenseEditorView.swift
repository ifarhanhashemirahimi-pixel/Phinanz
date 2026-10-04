//
//  ExpenseEditorView.swift
//  Phbank
//
//  Add or edit a single entry.
//

import SwiftUI
import SwiftData

struct ExpenseEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let expense: Expense?

    @State private var store: String
    @State private var amountText: String
    @State private var category: ExpenseCategory
    @State private var date: Date
    @State private var note: String
    @State private var confirmDelete = false
    @FocusState private var amountFocused: Bool

    init(expense: Expense?, defaultDate: Date) {
        self.expense = expense
        _store = State(initialValue: expense?.store ?? "")
        _amountText = State(initialValue: expense.map { Money.input($0.amount) } ?? "")
        _category = State(initialValue: expense?.category ?? .other)
        _date = State(initialValue: expense?.date ?? defaultDate)
        _note = State(initialValue: expense?.note ?? "")
    }

    private var parsedAmount: Double? {
        guard let value = Money.parse(amountText), value > 0, value < 1_000_000 else { return nil }
        return value
    }

    private var trimmedStore: String {
        String(store.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
    }

    private var canSave: Bool { !trimmedStore.isEmpty && parsedAmount != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Store or description", text: $store)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("field-store")

                    HStack {
                        TextField("Amount", text: $amountText)
                            .keyboardType(.decimalPad)
                            .focused($amountFocused)
                            .accessibilityIdentifier("field-amount")
                        Text("EUR").foregroundStyle(.secondary)
                    }
                    if !amountText.isEmpty && parsedAmount == nil {
                        Text("Enter an amount greater than 0, e.g. 12,50")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    Picker("Category", selection: $category) {
                        ForEach(ExpenseCategory.allCases) { item in
                            Label(item.title, systemImage: item.symbol).tag(item)
                        }
                    }
                    DatePicker("Date", selection: $date)
                }

                Section("Note") {
                    TextField("Optional note", text: $note, axis: .vertical)
                        .lineLimit(1...4)
                }

                if let expense {
                    Section {
                        LabeledContent("Added via", value: expense.source.title)
                    }
                    Section {
                        Button("Delete entry", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .navigationTitle(expense == nil ? "New entry" : "Edit entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                        .accessibilityIdentifier("save-entry")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { amountFocused = false }
                }
            }
            .confirmationDialog("Delete this entry?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive, action: delete)
                Button("Cancel", role: .cancel) {}
            }
        }
        .tint(JournalTheme.gold)
    }

    private func save() {
        guard let amount = parsedAmount, !trimmedStore.isEmpty else { return }
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        if let expense {
            expense.store = trimmedStore
            expense.amount = amount
            expense.category = category
            expense.date = date
            expense.note = cleanNote
        } else {
            context.insert(Expense(store: trimmedStore, amount: amount, category: category, date: date, note: cleanNote))
        }
        try? context.save()
        dismiss()
    }

    private func delete() {
        if let expense { context.delete(expense) }
        try? context.save()
        dismiss()
    }
}
