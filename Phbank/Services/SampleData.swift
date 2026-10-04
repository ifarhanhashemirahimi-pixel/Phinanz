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
}
