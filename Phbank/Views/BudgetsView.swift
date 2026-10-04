//
//  BudgetsView.swift
//  Phbank
//
//  Monthly spending limits per category.
//

import SwiftUI
import SwiftData

struct BudgetsView: View {
    @Query private var budgets: [CategoryBudget]

    private var totalLimit: Double {
        Money.roundCents(budgets.reduce(0) { $0 + max(0, $1.monthlyLimit) })
    }

    var body: some View {
        Form {
            Section {
                ForEach(ExpenseCategory.expenseCases) { category in
                    BudgetField(category: category, existing: budgets.first { $0.category == category })
                }
            } footer: {
                Text("Leave a field empty for no limit. PHINANZ warns you at 80 percent and when you go over.")
            }

            Section {
                LabeledContent("Total monthly budget", value: Money.format(totalLimit))
            }
        }
        .navigationTitle("Monthly Budgets")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
    }
}

private struct BudgetField: View {
    @Environment(\.modelContext) private var context
    let category: ExpenseCategory
    let existing: CategoryBudget?

    @State private var text = ""
    @State private var loaded = false
    @FocusState private var focused: Bool

    var body: some View {
        HStack {
            Label {
                Text(category.title)
            } icon: {
                CategoryIcon(category: category, size: 29)
            }
            Spacer()
            TextField("No limit", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 110)
                .focused($focused)
            Text(verbatim: "€").foregroundStyle(.secondary)
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            text = existing.map { Money.input($0.monthlyLimit) } ?? ""
        }
        .onChange(of: focused) { _, isFocused in
            if !isFocused { commit() }
        }
        .onDisappear(perform: commit)
    }

    private func commit() {
        let raw = category.rawValue
        let descriptor = FetchDescriptor<CategoryBudget>(predicate: #Predicate { $0.categoryRaw == raw })
        let current = (try? context.fetch(descriptor)) ?? []
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if let value = Money.parse(trimmed), value > 0 {
            if let first = current.first {
                if first.monthlyLimit != value { first.monthlyLimit = value }
                for extra in current.dropFirst() { context.delete(extra) }
            } else {
                context.insert(CategoryBudget(category: category, monthlyLimit: value))
            }
        } else if trimmed.isEmpty {
            for budget in current { context.delete(budget) }
        } else {
            return // invalid input: keep the old value
        }
        try? context.save()
    }
}
