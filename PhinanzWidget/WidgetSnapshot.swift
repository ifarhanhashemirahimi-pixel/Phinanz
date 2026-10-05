//
//  WidgetSnapshot.swift
//  PhinanzWidget
//
//  Keep in sync with Phinanz/Services/WidgetBridge.swift.
//

import Foundation

struct WidgetSnapshot: Codable, Equatable {
    var todaySpent: Double
    var monthSpent: Double
    var monthIncome: Double
    var balance: Double
    var budgetLimit: Double
    var updatedAt: Date
    /// True when the user hid amounts in widgets; all numbers are zero then.
    var isHidden: Bool? = nil

    static let appGroup = "group.Farhan.Phinanz"
    static let key = "widgetSnapshot"

    static func load() -> WidgetSnapshot? {
        guard let data = UserDefaults(suiteName: appGroup)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    static let preview = WidgetSnapshot(
        todaySpent: 21.69,
        monthSpent: 742.30,
        monthIncome: 2_450,
        balance: 3_180.55,
        budgetLimit: 1_200,
        updatedAt: Date()
    )

    /// Values that belong to an earlier day or month are shown as zero.
    func current(at now: Date = Date(), calendar: Calendar = .current) -> WidgetSnapshot {
        var copy = self
        if !calendar.isDate(updatedAt, inSameDayAs: now) { copy.todaySpent = 0 }
        if !calendar.isDate(updatedAt, equalTo: now, toGranularity: .month) {
            copy.monthSpent = 0
            copy.monthIncome = 0
        }
        return copy
    }
}
