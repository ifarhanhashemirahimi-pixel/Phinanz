//
//  RecurringViews.swift
//  Phbank
//
//  List and editor for monthly recurring payments and incomes.
//

import SwiftUI
import SwiftData

struct RecurringListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \RecurringPayment.dayOfMonth) private var payments: [RecurringPayment]

    @State private var editing: RecurringPayment?
    @State private var showNew = false

    private var fixedCosts: Double {
        Money.roundCents(payments.filter { $0.isActive && !$0.isIncome }.reduce(0) { $0 + $1.amount })
    }

    private var fixedIncome: Double {
        Money.roundCents(payments.filter { $0.isActive && $0.isIncome }.reduce(0) { $0 + $1.amount })
    }

    var body: some View {
        List {
            if payments.isEmpty {
                ContentUnavailableView(
                    "No recurring payments",
                    systemImage: "arrow.triangle.2.circlepath",
                    description: Text("Add rent, subscriptions, insurance or your salary. PHINANZ books them automatically every month.")
                )
            } else {
                Section {
                    ForEach(payments) { payment in
                        Button { editing = payment } label: { row(payment) }
                            .foregroundStyle(.primary)
                    }
                    .onDelete(perform: delete)
                }
                Section {
                    LabeledContent("Fixed costs per month", value: Money.format(fixedCosts))
                    LabeledContent("Fixed income per month", value: Money.format(fixedIncome))
                }
            }
        }
        .navigationTitle("Recurring Payments")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showNew = true } label: { Label("Add", systemImage: "plus") }
                    .accessibilityIdentifier("add-recurring")
            }
        }
        .sheet(item: $editing) { payment in
            RecurringEditorView(payment: payment)
        }
        .sheet(isPresented: $showNew) {
            RecurringEditorView(payment: nil)
        }
    }

    private func row(_ payment: RecurringPayment) -> some View {
        HStack(spacing: 12) {
            CategoryIcon(category: payment.category, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(payment.name).font(.headline)
                Group {
                    if payment.isActive {
                        Text("Every month on day \(payment.dayOfMonth)")
                    } else {
                        Text("Paused")
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Text(verbatim: (payment.isIncome ? "+" : "") + Money.format(payment.amount))
                .monospacedDigit()
                .foregroundStyle(payment.isIncome ? Theme.income : Color.primary)
        }
        .opacity(payment.isActive ? 1 : 0.5)
        .accessibilityElement(children: .combine)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { context.delete(payments[index]) }
        try? context.save()
    }
}

struct RecurringEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let payment: RecurringPayment?

    @State private var isIncome: Bool
    @State private var name: String
    @State private var amountText: String
    @State private var category: ExpenseCategory
    @State private var dayOfMonth: Int
    @State private var startDate: Date
    @State private var isActive: Bool
    @State private var note: String

    init(payment: RecurringPayment?) {
        self.payment = payment
        _isIncome = State(initialValue: payment?.isIncome ?? false)
        _name = State(initialValue: payment?.name ?? "")
        _amountText = State(initialValue: payment.map { Money.input($0.amount) } ?? "")
        _category = State(initialValue: payment?.category ?? .housing)
        _dayOfMonth = State(initialValue: payment?.dayOfMonth ?? Calendar.current.component(.day, from: Date()))
        _startDate = State(initialValue: payment?.startDate ?? Calendar.current.startOfDay(for: Date()))
        _isActive = State(initialValue: payment?.isActive ?? true)
        _note = State(initialValue: payment?.note ?? "")
    }

    private var amount: Double? {
        guard let value = Money.parse(amountText), value > 0, value < 1_000_000 else { return nil }
        return value
    }

    private var trimmedName: String {
        String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
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
                }

                Section("Details") {
                    TextField(isIncome ? LocalizedStringKey("e.g. Salary") : LocalizedStringKey("e.g. Rent, Netflix, insurance"), text: $name)
                        .textInputAutocapitalization(.words)
                    HStack {
                        TextField("Amount", text: $amountText)
                            .keyboardType(.decimalPad)
                        Text(verbatim: "EUR").foregroundStyle(.secondary)
                    }
                    Picker("Category", selection: $category) {
                        ForEach(isIncome ? ExpenseCategory.incomeCases : ExpenseCategory.expenseCases) { item in
                            Label {
                                Text(item.title)
                            } icon: {
                                CategoryIcon(category: item, size: 28)
                            }
                            .tag(item)
                        }
                    }
                }

                Section {
                    Picker("Day of month", selection: $dayOfMonth) {
                        ForEach(1...31, id: \.self) { day in
                            Text(verbatim: "\(day)").tag(day)
                        }
                    }
                    DatePicker("Starts on", selection: $startDate, displayedComponents: .date)
                    Toggle("Active", isOn: $isActive)
                } header: {
                    Text("Schedule")
                } footer: {
                    Text("Entries are created automatically on this day every month, starting from the start date. Day 31 means the last day in shorter months.")
                }

                Section("Note") {
                    TextField("Optional note", text: $note, axis: .vertical)
                        .lineLimit(1...3)
                }

                if payment != nil {
                    Section {
                        Button("Delete Recurring Payment", role: .destructive, action: delete)
                    } footer: {
                        Text("Entries that were already booked stay in your journal.")
                    }
                }
            }
            .navigationTitle(payment == nil ? Text("New Recurring Payment") : Text("Edit Recurring Payment"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(trimmedName.isEmpty || amount == nil)
                }
            }
            .onChange(of: isIncome) { _, income in
                if category.isIncome != income { category = income ? .salary : .housing }
            }
        }
    }

    private func save() {
        guard let amount, !trimmedName.isEmpty else { return }
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if let payment {
            payment.name = trimmedName
            payment.amount = amount
            payment.category = category
            payment.isIncome = isIncome
            payment.dayOfMonth = dayOfMonth
            payment.startDate = startDate
            payment.isActive = isActive
            payment.note = cleanNote
        } else {
            let created = RecurringPayment(
                name: trimmedName,
                amount: amount,
                category: category,
                isIncome: isIncome,
                dayOfMonth: dayOfMonth,
                startDate: startDate,
                note: cleanNote
            )
            created.isActive = isActive
            context.insert(created)
        }
        try? context.save()
        RecurringScheduler.run(in: context)
        Task { await NotificationScheduler.refresh(context: context) }
        dismiss()
    }

    private func delete() {
        if let payment { context.delete(payment) }
        try? context.save()
        dismiss()
    }
}
