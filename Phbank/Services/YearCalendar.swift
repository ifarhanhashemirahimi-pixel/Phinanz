//
//  YearCalendar.swift
//  Phbank
//
//  Pure date helpers behind the 365-page journal.
//

import Foundation

enum YearCalendar {
    /// Start-of-day dates for every day of `year` (365 or 366 entries).
    static func days(in year: Int, calendar: Calendar = .current) -> [Date] {
        guard let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let end = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)),
              let count = calendar.dateComponents([.day], from: start, to: end).day
        else { return [] }
        return (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    /// Zero-based page index of `date` inside `year`, or nil if it is in another year.
    static func index(of date: Date, in year: Int, calendar: Calendar = .current) -> Int? {
        guard calendar.component(.year, from: date) == year,
              let ordinal = calendar.ordinality(of: .day, in: .year, for: date)
        else { return nil }
        return ordinal - 1
    }

    static func date(at index: Int, in year: Int, calendar: Calendar = .current) -> Date? {
        guard let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) else { return nil }
        return calendar.date(byAdding: .day, value: index, to: start)
    }

    static func groupByDay(_ expenses: [Expense], calendar: Calendar = .current) -> [Date: [Expense]] {
        Dictionary(grouping: expenses) { calendar.startOfDay(for: $0.date) }
    }

    /// Day from the pager combined with the current wall-clock time, for new entries.
    static func entryDate(on day: Date, now: Date = Date(), calendar: Calendar = .current) -> Date {
        let time = calendar.dateComponents([.hour, .minute], from: now)
        return calendar.date(
            bySettingHour: time.hour ?? 12,
            minute: time.minute ?? 0,
            second: 0,
            of: day
        ) ?? day
    }
}
