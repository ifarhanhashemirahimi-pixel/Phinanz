//
//  SampleData.swift
//  Phbank
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
        for entry in entries { context.insert(entry) }

        context.insert(CategoryBudget(category: .groceries, monthlyLimit: 250))
        context.insert(CategoryBudget(category: .food, monthlyLimit: 120))
        context.insert(CategoryBudget(category: .shopping, monthlyLimit: 80))
        context.insert(CategoryBudget(category: .entertainment, monthlyLimit: 60))

        let start = calendar.date(byAdding: .month, value: -2, to: now) ?? now
        let rent = RecurringPayment(name: "Miete", amount: 720, category: .housing, dayOfMonth: 1, startDate: start)
        let salary = RecurringPayment(name: "Arbeitgeber GmbH", amount: 2_450, category: .salary, isIncome: true, dayOfMonth: 28, startDate: start)
        let netflix = RecurringPayment(name: "Netflix", amount: 13.99, category: .entertainment, dayOfMonth: 15, startDate: start)
        let insurance = RecurringPayment(name: "Haftpflichtversicherung", amount: 6.50, category: .other, dayOfMonth: 20, startDate: start)
        for payment in [rent, salary, netflix, insurance] {
            payment.lastGenerated = now
            context.insert(payment)
        }
        try? context.save()
    }
}
