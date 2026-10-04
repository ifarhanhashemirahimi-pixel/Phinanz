//
//  ExpenseEditorView.swift
//  Phbank
//
//  Add or edit a single entry (expense or income).
//

import SwiftUI
import SwiftData

struct ExpenseEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var budgets: [CategoryBudget]
    @Query private var allEntries: [Expense]

    let expense: Expense?

    @State private var isIncome: Bool
    @State private var store: String
    @State private var amountText: String
    @State private var category: ExpenseCategory
    @State private var date: Date
    @State private var note: String
    @State private var confirmDelete = false
    @State private var budgetMessage: String?
    @FocusState private var amountFocused: Bool

    init(expense: Expense?, defaultDate: Date) {
        self.expense = expense
        _isIncome = State(initialValue: expense?.isIncome ?? false)
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

    private var categories: [ExpenseCategory] {
        isIncome ? ExpenseCategory.incomeCases : ExpenseCategory.expenseCases
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $isIncome) {
                        Text("Expense").tag(false)
                        Text("Income").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("field-type")
                }

                Section("Details") {
                    TextField(isIncome ? LocalizedStringKey("Source, e.g. employer") : LocalizedStringKey("Store or description"), text: $store)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("field-store")

                    HStack {
                        TextField("Amount", text: $amountText)
                            .keyboardType(.decimalPad)
                            .focused($amountFocused)
                            .accessibilityIdentifier("field-amount")
                        Text(verbatim: "EUR").foregroundStyle(.secondary)
                    }
                    if !amountText.isEmpty && parsedAmount == nil {
                        Text("Enter an amount greater than 0, e.g. 12,50")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    Picker("Category", selection: $category) {
                        ForEach(categories) { item in
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
            .navigationTitle(expense == nil ? Text("New entry") : Text("Edit entry"))
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
            .onChange(of: isIncome) { _, income in
                if category.isIncome != income {
                    category = income ? .salary : .other
                }
            }
            .confirmationDialog("Delete this entry?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive, action: delete)
                Button("Cancel", role: .cancel) {}
            }
            .alert("Budget", isPresented: budgetAlertBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(budgetMessage ?? "")
            }
        }
        .tint(JournalTheme.gold)
    }

    private var budgetAlertBinding: Binding<Bool> {
        Binding(
            get: { budgetMessage != nil },
            set: { shown in
                if !shown {
                    budgetMessage = nil
                    dismiss()
                }
            }
        )
    }

    // MARK: Actions

    private func save() {
        guard let amount = parsedAmount, !trimmedStore.isEmpty else { return }
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let spentBefore = monthSpending(in: category, excluding: expense)

        if let expense {
            expense.store = trimmedStore
            expense.amount = amount
            expense.category = category
            expense.date = date
            expense.note = cleanNote
            expense.isIncome = isIncome
        } else {
            context.insert(Expense(
                store: trimmedStore,
                amount: amount,
                category: category,
                date: date,
                note: cleanNote,
                isIncome: isIncome
            ))
        }
        try? context.save()

        if !isIncome, let message = budgetWarning(spentBefore: spentBefore, amount: amount) {
            budgetMessage = message // the alert dismisses the editor when closed
        } else {
            dismiss()
        }
    }

    private func delete() {
        if let expense { context.delete(expense) }
        try? context.save()
        dismiss()
    }

    // MARK: Budget check

    private func monthSpending(in category: ExpenseCategory, excluding current: Expense?) -> Double {
        guard let month = Calendar.current.dateInterval(of: .month, for: date) else { return 0 }
        let others = ExpenseStats.expenses(allEntries, in: month).filter { entry in
            !entry.isIncome && entry.category == category && entry !== current
        }
        return ExpenseStats.total(others)
    }

    private func budgetWarning(spentBefore: Double, amount: Double) -> String? {
        guard let budget = budgets.first(where: { $0.category == category && $0.monthlyLimit > 0 }) else { return nil }
        let after = spentBefore + amount
        guard let level = BudgetCalculator.crossedLevel(before: spentBefore, after: after, limit: budget.monthlyLimit) else {
            return nil
        }
        let name = category.title
        switch level {
        case .over:
            let over = Money.format(Money.roundCents(after - budget.monthlyLimit))
            return String(localized: "You are over your \(name) budget this month by \(over).")
        case .warning:
            let used = (after / budget.monthlyLimit).formatted(.percent.precision(.fractionLength(0)))
            return String(localized: "You have used \(used) of your \(name) budget this month.")
        case .ok:
            return nil
        }
    }
}
