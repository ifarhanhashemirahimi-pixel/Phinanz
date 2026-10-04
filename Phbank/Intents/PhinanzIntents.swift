//
//  PhinanzIntents.swift
//  Phbank
//
//  Siri, Shortcuts and Spotlight actions:
//  "Add an expense in PHINANZ", "How much did I spend today in PHINANZ".
//

import AppIntents
import Foundation
import SwiftData

enum CategoryAppEnum: String, AppEnum {
    case groceries, food, transport, housing, entertainment, health, shopping, software, travel, other

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Category"

    static let caseDisplayRepresentations: [CategoryAppEnum: DisplayRepresentation] = [
        .groceries: DisplayRepresentation(title: "Groceries", image: .init(systemName: "cart.fill")),
        .food: DisplayRepresentation(title: "Food & Drink", image: .init(systemName: "fork.knife")),
        .transport: DisplayRepresentation(title: "Transport", image: .init(systemName: "tram.fill")),
        .housing: DisplayRepresentation(title: "Housing", image: .init(systemName: "house.fill")),
        .entertainment: DisplayRepresentation(title: "Entertainment", image: .init(systemName: "film.fill")),
        .health: DisplayRepresentation(title: "Health", image: .init(systemName: "cross.case.fill")),
        .shopping: DisplayRepresentation(title: "Shopping", image: .init(systemName: "bag.fill")),
        .software: DisplayRepresentation(title: "Software", image: .init(systemName: "laptopcomputer")),
        .travel: DisplayRepresentation(title: "Travel", image: .init(systemName: "airplane")),
        .other: DisplayRepresentation(title: "Other", image: .init(systemName: "ellipsis"))
    ]

    var category: ExpenseCategory { ExpenseCategory(rawValue: rawValue) ?? .other }
}

struct AddExpenseIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Expense"
    static let description = IntentDescription("Adds an expense to today's page in PHINANZ.")

    @Parameter(title: "Amount", description: "Amount in euros")
    var amount: Double

    @Parameter(title: "Store", description: "Where you spent the money")
    var store: String

    @Parameter(title: "Category", default: .other)
    var category: CategoryAppEnum

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$amount) € at \(\.$store)") {
            \.$category
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard amount.isFinite, amount > 0, amount < 1_000_000 else {
            throw $amount.needsValueError("How much did you spend?")
        }
        let name = String(store.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        guard !name.isEmpty else {
            throw $store.needsValueError("Where did you spend it?")
        }
        let value = Money.roundCents(amount)
        let context = Persistence.shared.mainContext
        context.insert(Expense(store: name, amount: value, category: category.category, date: Date()))
        try context.save()
        WidgetBridge.refresh(from: context)
        return .result(dialog: "Added \(Money.format(value)) at \(name).")
    }
}

struct TodaySpendingIntent: AppIntent {
    static let title: LocalizedStringResource = "Today's Spending"
    static let description = IntentDescription("Tells you how much you have spent today.")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Double> & ProvidesDialog {
        let entries = (try? Persistence.shared.mainContext.fetch(FetchDescriptor<Expense>())) ?? []
        let now = Date()
        let today = Calendar.current.dateInterval(of: .day, for: now) ?? DateInterval(start: now, duration: 86_400)
        let spent = ExpenseStats.spending(ExpenseStats.expenses(entries, in: today))
        return .result(value: spent, dialog: "You have spent \(Money.format(spent)) today.")
    }
}

struct MonthSpendingIntent: AppIntent {
    static let title: LocalizedStringResource = "This Month's Spending"
    static let description = IntentDescription("Tells you how much you have spent this month.")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Double> & ProvidesDialog {
        let entries = (try? Persistence.shared.mainContext.fetch(FetchDescriptor<Expense>())) ?? []
        let now = Date()
        let month = Calendar.current.dateInterval(of: .month, for: now) ?? DateInterval(start: now, duration: 86_400)
        let spent = ExpenseStats.spending(ExpenseStats.expenses(entries, in: month))
        return .result(value: spent, dialog: "You have spent \(Money.format(spent)) this month.")
    }
}

struct NewEntryIntent: AppIntent {
    static let title: LocalizedStringResource = "New Entry"
    static let description = IntentDescription("Opens PHINANZ with a new entry for today.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppRouter.shared.pendingAction = .newEntry
        return .result()
    }
}

struct PhinanzShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddExpenseIntent(),
            phrases: [
                "Add an expense in \(.applicationName)",
                "Log spending in \(.applicationName)"
            ],
            shortTitle: "Add Expense",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: TodaySpendingIntent(),
            phrases: [
                "How much did I spend today in \(.applicationName)",
                "Today's spending in \(.applicationName)"
            ],
            shortTitle: "Today's Spending",
            systemImageName: "eurosign.circle"
        )
        AppShortcut(
            intent: MonthSpendingIntent(),
            phrases: [
                "How much did I spend this month in \(.applicationName)"
            ],
            shortTitle: "This Month",
            systemImageName: "calendar"
        )
        AppShortcut(
            intent: NewEntryIntent(),
            phrases: [
                "New entry in \(.applicationName)"
            ],
            shortTitle: "New Entry",
            systemImageName: "square.and.pencil"
        )
    }
}
