//
//  PlanView.swift
//  Phinanz
//
//  Accounts, savings goals, budgets for this month and upcoming recurring payments.
//

import SwiftUI
import SwiftData

struct PlanView: View {
    let expenses: [Expense]
    @Binding var activeSheet: ActiveSheet?

    @Query private var budgets: [CategoryBudget]
    @Query(sort: \RecurringPayment.dayOfMonth) private var payments: [RecurringPayment]

    @State private var showTransfer = false
    @State private var showNewGoal = false

    private let calendar = Calendar.current

    private var month: DateInterval {
        calendar.dateInterval(of: .month, for: Date()) ?? DateInterval(start: Date(), duration: 86_400)
    }

    private var statuses: [BudgetStatus] {
        BudgetCalculator.statuses(budgets: budgets, entries: expenses, in: month)
    }

    private struct Upcoming: Identifiable {
        let payment: RecurringPayment
        let date: Date
        var id: ObjectIdentifier { ObjectIdentifier(payment) }
    }

    private var upcoming: [Upcoming] {
        payments
            .filter(\.isActive)
            .compactMap { payment in
                RecurringScheduler.nextDue(for: payment).map { Upcoming(payment: payment, date: $0) }
            }
            .sorted { $0.date < $1.date }
            .prefix(5)
            .map { $0 }
    }

    private var monthName: String { Date().formatted(.dateTime.month(.wide)) }

    var body: some View {
        NavigationStack {
            List {
                AccountsSection(expenses: expenses, showTransfer: $showTransfer)
                GoalsSection(showNew: $showNewGoal)

                Section {
                    if statuses.isEmpty {
                        NavigationLink {
                            BudgetsView()
                        } label: {
                            SettingsLabel(title: "Set Up Budgets", systemName: "gauge.with.dots.needle.33percent", color: .orange)
                        }
                    } else {
                        ForEach(statuses) { status in
                            BudgetRow(status: status)
                        }
                    }
                } header: {
                    Text("Budgets in \(monthName)")
                } footer: {
                    if statuses.isEmpty {
                        Text("Set a monthly limit for categories like groceries or eating out. PHINANZ warns you at 80 percent.")
                    }
                }

                Section("Upcoming") {
                    if upcoming.isEmpty {
                        NavigationLink {
                            RecurringListView()
                        } label: {
                            SettingsLabel(title: "Add Recurring Payments", systemName: "arrow.triangle.2.circlepath", color: .indigo)
                        }
                    } else {
                        ForEach(upcoming) { item in
                            HStack(spacing: 12) {
                                CategoryIcon(category: item.payment.category, size: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.payment.name)
                                    Text(item.date.formatted(.relative(presentation: .named)))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(verbatim: (item.payment.isIncome ? "+" : "") + Money.format(item.payment.amount))
                                    .monospacedDigit()
                                    .foregroundStyle(item.payment.isIncome ? Theme.income : Color.primary)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }

                Section {
                    NavigationLink {
                        BudgetsView()
                    } label: {
                        SettingsLabel(title: "Monthly Budgets", systemName: "gauge.with.dots.needle.33percent", color: .orange)
                    }
                    NavigationLink {
                        RecurringListView()
                    } label: {
                        SettingsLabel(title: "Recurring Payments", systemName: "arrow.triangle.2.circlepath", color: .indigo)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .sheet(isPresented: $showTransfer) { TransferEditorView() }
            .sheet(isPresented: $showNewGoal) { GoalEditorView(goal: nil) }
            .navigationTitle("Plan")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    SettingsToolbarButton(activeSheet: $activeSheet)
                }
            }
        }
    }
}

struct BudgetRow: View {
    let status: BudgetStatus

    private var tint: Color {
        switch status.level {
        case .ok: .green
        case .warning: .orange
        case .over: .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                CategoryIcon(category: status.category, size: 30)
                Text(status.category.title)
                Spacer()
                Text(verbatim: "\(Money.format(status.spent)) / \(Money.format(status.limit))")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: min(status.ratio, 1))
                .tint(tint)
            if status.level == .over {
                Text("Over budget by \(Money.format(-status.remaining))")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.red)
            } else {
                Text("\(Money.format(status.remaining)) left")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
