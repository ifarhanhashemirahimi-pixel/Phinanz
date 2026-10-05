//
//  SampleData.swift
//  Phinanz
//
//  Demo entries for previews and UI tests only — never inserted in normal launches.
//

import Foundation
import SwiftData

enum SampleData {
    static func seed(into context: ModelContext, now: Date = Date(), calendar: Calendar = .current) {
        func at(dayOffset: Int, hour: Int, minute: Int) -> Date {
            let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: now)) ?? now
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }

        let items = [
            Expense(store: "Bäckerei Schmidt", amount: 4.50, category: .food, date: at(dayOffset: 0, hour: 8, minute: 30)),
            Expense(store: "iCloud+", amount: 2.99, category: .software, date: at(dayOffset: 0, hour: 10, minute: 15)),
            Expense(store: "RMV Ticket", amount: 14.20, category: .transport, date: at(dayOffset: 0, hour: 11, minute: 0)),
            Expense(store: "Rewe", amount: 45.80, category: .groceries, date: at(dayOffset: -1, hour: 18, minute: 45)),
            Expense(store: "Netflix", amount: 12.99, category: .entertainment, date: at(dayOffset: -1, hour: 20, minute: 0)),
            Expense(store: "Miete", amount: 620.00, category: .housing, date: at(dayOffset: -3, hour: 9, minute: 0)),
            Expense(store: "dm", amount: 18.35, category: .health, date: at(dayOffset: -8, hour: 16, minute: 20))
        ]
        for item in items { context.insert(item) }
    }

    /// A realistic month for previews and debug screenshots: daily spending,
    /// salary, rent, subscriptions, budgets and recurring payments.
    static func seedShowcase(into context: ModelContext, now: Date = Date(), calendar: Calendar = .current) {
        func at(_ dayOffset: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: now)) ?? now
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }

        let entries: [Expense] = [
            Expense(store: "Bäckerei Schmidt", amount: 4.50, category: .food, date: at(0, 8, 10)),
            Expense(store: "REWE", amount: 38.72, category: .groceries, date: at(0, 12, 40)),
            Expense(store: "RMV Monatskarte", amount: 58.00, category: .transport, date: at(0, 17, 5)),
            Expense(store: "Vapiano", amount: 16.90, category: .food, date: at(0, 19, 30)),
            Expense(store: "dm-drogerie markt", amount: 12.35, category: .health, date: at(-1, 11, 20)),
            Expense(store: "Netflix", amount: 13.99, category: .entertainment, date: at(-1, 9, 0), source: .recurring),
            Expense(store: "Lidl", amount: 24.18, category: .groceries, date: at(-2, 18, 45)),
            Expense(store: "Amazon", amount: 39.99, category: .shopping, date: at(-3, 14, 15)),
            Expense(store: "Apple iCloud+", amount: 2.99, category: .software, date: at(-4, 9, 0), source: .recurring),
            Expense(store: "Arbeitgeber GmbH", amount: 2_450.00, category: .salary, date: at(-4, 9, 0), source: .recurring, isIncome: true),
            Expense(store: "Miete", amount: 720.00, category: .housing, date: at(-4, 9, 0), source: .recurring),
            Expense(store: "Deutsche Bahn", amount: 49.90, category: .travel, date: at(-6, 7, 55)),
            Expense(store: "Edeka", amount: 52.40, category: .groceries, date: at(-7, 17, 30)),
            Expense(store: "Kino Darmstadt", amount: 22.00, category: .entertainment, date: at(-8, 20, 0)),
            Expense(store: "Rückerstattung Zalando", amount: 29.95, category: .refund, date: at(-9, 10, 0), isIncome: true),
            Expense(store: "Apotheke", amount: 8.70, category: .health, date: at(-10, 16, 0)),
            Expense(store: "REWE", amount: 41.05, category: .groceries, date: at(-12, 18, 10)),
            Expense(store: "Shell", amount: 35.00, category: .transport, date: at(-14, 8, 30)),
            Expense(store: "H&M", amount: 59.97, category: .shopping, date: at(-16, 15, 0)),
            Expense(store: "Nachhilfe", amount: 120.00, category: .freelance, date: at(-18, 18, 0), isIncome: true)
        ]
        // Accounts: card payments and income on the checking account, a few cash buys.
        let checking = Account(name: "Girokonto", kind: .checking, openingBalance: 1_240, sortOrder: 0)
        let cash = Account(name: "Bargeld", kind: .cash, openingBalance: 60, sortOrder: 1)
        let credit = Account(name: "Kreditkarte", kind: .credit, openingBalance: 0, sortOrder: 2)
        let savings = Account(name: "Sparkonto", kind: .savings, openingBalance: 3_500, sortOrder: 3)
        for account in [checking, cash, credit, savings] { context.insert(account) }
        for entry in entries {
            switch entry.store {
            case "Bäckerei Schmidt", "Kino Darmstadt", "Apotheke": entry.accountID = cash.id
            case "Amazon", "H&M", "Deutsche Bahn": entry.accountID = credit.id
            default: entry.accountID = checking.id
            }
            context.insert(entry)
        }
        context.insert(Transfer(from: checking.id, to: cash.id, amount: 100, date: at(-5, 13), note: "Geldautomat"))
        context.insert(Transfer(from: checking.id, to: savings.id, amount: 300, date: at(-4, 10), note: "Sparrate"))

        // Savings goals.
        let trip = SavingsGoal(name: "Reise nach Lissabon", target: 1_200, saved: 780,
                               deadline: calendar.date(byAdding: .month, value: 5, to: now),
                               symbol: "airplane", colorName: "teal")
        let laptop = SavingsGoal(name: "Neues MacBook", target: 1_500, saved: 450,
                                 deadline: calendar.date(byAdding: .month, value: 8, to: now),
                                 symbol: "laptopcomputer", colorName: "indigo")
        let buffer = SavingsGoal(name: "Notgroschen", target: 3_000, saved: 3_000, symbol: "umbrella.fill", colorName: "green")
        for goal in [trip, laptop, buffer] { context.insert(goal) }

        // The two months before, so the monthly report has something to compare with.
        func inMonth(_ monthOffset: Int, day: Int, hour: Int) -> Date {
            let thisMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            let month = calendar.date(byAdding: .month, value: monthOffset, to: thisMonth) ?? thisMonth
            let date = calendar.date(byAdding: .day, value: day - 1, to: month) ?? month
            return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
        }
        var lastMonth: [Expense] = []
        for (offset, groceries, food, shopping) in [(-1, 96.40, 64.00, 89.95), (-2, 142.80, 92.50, 139.99)] {
            lastMonth += [
                Expense(store: "REWE", amount: groceries, category: .groceries, date: inMonth(offset, day: 3, hour: 18), accountID: checking.id),
                Expense(store: "Lidl", amount: 71.25, category: .groceries, date: inMonth(offset, day: 10, hour: 17), accountID: checking.id),
                Expense(store: "Restaurant Sultan", amount: food, category: .food, date: inMonth(offset, day: 14, hour: 20), accountID: credit.id),
                Expense(store: "Zalando", amount: shopping, category: .shopping, date: inMonth(offset, day: 20, hour: 12), accountID: credit.id),
                Expense(store: "Miete", amount: 720.00, category: .housing, date: inMonth(offset, day: 1, hour: 9), source: .recurring, accountID: checking.id),
                Expense(store: "Arbeitgeber GmbH", amount: 2_450.00, category: .salary, date: inMonth(offset, day: 28, hour: 9), source: .recurring, isIncome: true, accountID: checking.id),
                Expense(store: "Netflix", amount: 13.99, category: .entertainment, date: inMonth(offset, day: 15, hour: 9), source: .recurring, accountID: checking.id)
            ]
        }
        for entry in lastMonth { context.insert(entry) }

        context.insert(CategoryBudget(category: .groceries, monthlyLimit: 250))
        context.insert(CategoryBudget(category: .food, monthlyLimit: 120))
        context.insert(CategoryBudget(category: .shopping, monthlyLimit: 80))
        context.insert(CategoryBudget(category: .entertainment, monthlyLimit: 60))

        let start = calendar.date(byAdding: .month, value: -2, to: now) ?? now
        let rent = RecurringPayment(name: "Miete", amount: 720, category: .housing, dayOfMonth: 1, startDate: start, accountID: checking.id)
        let salary = RecurringPayment(name: "Arbeitgeber GmbH", amount: 2_450, category: .salary, isIncome: true, dayOfMonth: 28, startDate: start, accountID: checking.id)
        let netflix = RecurringPayment(name: "Netflix", amount: 13.99, category: .entertainment, dayOfMonth: 15, startDate: start, accountID: checking.id)
        let insurance = RecurringPayment(name: "Haftpflichtversicherung", amount: 6.50, category: .other, dayOfMonth: 20, startDate: start, accountID: checking.id)
        for payment in [rent, salary, netflix, insurance] {
            payment.lastGenerated = now
            context.insert(payment)
        }
        try? context.save()
    }
}
