//
//  RecurringScheduler.swift
//  Phinanz
//
//  Turns recurring payments into journal entries on their due day,
//  catching up on months the app was not opened.
//

import Foundation
import SwiftData

enum RecurringScheduler {
    /// Safety cap so a wrong start date can never create thousands of entries.
    static let maxCatchUpMonths = 24

    /// Due dates (09:00 on the clamped day) after `lastGenerated`, from `start` up to `now`.
    static func dueDates(
        start: Date,
        dayOfMonth: Int,
        lastGenerated: Date?,
        now: Date,
        calendar: Calendar = .current
    ) -> [Date] {
        let startDay = calendar.startOfDay(for: start)
        guard startDay <= now,
              var month = calendar.date(from: calendar.dateComponents([.year, .month], from: startDay))
        else { return [] }

        var result: [Date] = []
        var iterations = 0
        while month <= now, iterations < maxCatchUpMonths + 12 {
            iterations += 1
            if let range = calendar.range(of: .day, in: .month, for: month) {
                let day = min(max(dayOfMonth, 1), range.count)
                if let date = calendar.date(byAdding: .day, value: day - 1, to: month),
                   let due = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date),
                   due >= startDay, due <= now,
                   lastGenerated.map({ due > $0 }) ?? true {
                    result.append(due)
                }
            }
            guard let next = calendar.date(byAdding: .month, value: 1, to: month) else { break }
            month = next
        }
        return Array(result.suffix(maxCatchUpMonths))
    }

    /// Creates the missing entries for all active payments. Returns how many were added.
    @discardableResult
    static func run(in context: ModelContext, now: Date = Date(), calendar: Calendar = .current) -> Int {
        let descriptor = FetchDescriptor<RecurringPayment>(predicate: #Predicate { $0.isActive })
        guard let payments = try? context.fetch(descriptor) else { return 0 }

        var created = 0
        for payment in payments where payment.amount > 0 {
            let dates = dueDates(
                start: payment.startDate,
                dayOfMonth: payment.dayOfMonth,
                lastGenerated: payment.lastGenerated,
                now: now,
                calendar: calendar
            )
            for date in dates {
                context.insert(Expense(
                    store: payment.name,
                    amount: payment.amount,
                    category: payment.category,
                    date: date,
                    note: payment.note,
                    source: .recurring,
                    isIncome: payment.isIncome,
                    accountID: payment.accountID
                ))
                created += 1
            }
            if let last = dates.last { payment.lastGenerated = last }
        }
        if created > 0 { try? context.save() }
        return created
    }

    /// Next due date after `now`, for display.
    static func nextDue(for payment: RecurringPayment, now: Date = Date(), calendar: Calendar = .current) -> Date? {
        let horizon = calendar.date(byAdding: .month, value: 2, to: now) ?? now
        let from = max(payment.startDate, now)
        return dueDates(start: from, dayOfMonth: payment.dayOfMonth, lastGenerated: now, now: horizon, calendar: calendar).first
    }
}
