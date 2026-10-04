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
    @State private var savedCount = 0
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
                    VStack(spacing: 14) {
                        Picker("Type", selection: $isIncome) {
                            Text("Expense").tag(false)
                            Text("Income").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("field-type")

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            TextField("0", text: $amountText)
                                .font(Theme.amount(.largeTitle, weight: .bold))
                                .monospacedDigit()
                                .multilineTextAlignment(.center)
                                .keyboardType(.decimalPad)
                                .focused($amountFocused)
                                .minimumScaleFactor(0.5)
                                .fixedSize()
                                .accessibilityLabel(Text("Amount"))
                                .accessibilityIdentifier("field-amount")
                            Text(verbatim: "€")
                                .font(Theme.amount(.title, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(isIncome ? Theme.income : Color.primary)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture { amountFocused = true }

                        if !amountText.isEmpty && parsedAmount == nil {
                            Text("Enter an amount greater than 0, e.g. 12,50")
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)

                Section {
                    TextField(isIncome ? LocalizedStringKey("Source, e.g. employer") : LocalizedStringKey("Store or description"), text: $store)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("field-store")

                    Picker(selection: $category) {
                        ForEach(categories) { item in
                            Label {
                                Text(item.title)
                            } icon: {
                                CategoryIcon(category: item, size: 28)
                            }
                            .tag(item)
                        }
                    } label: {
                        Text("Category")
                    }
                    .pickerStyle(.navigationLink)

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
                        Button("Delete Entry", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .navigationTitle(expense == nil ? Text("New Entry") : Text("Edit Entry"))
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
            .onAppear {
                if expense == nil && amountText.isEmpty { amountFocused = true }
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
            .sensoryFeedback(.success, trigger: savedCount)
        }
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
        savedCount += 1

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
