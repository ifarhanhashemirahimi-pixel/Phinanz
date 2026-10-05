//
//  SavingsPlanner.swift
//  Phinanz
//
//  Progress of a savings goal and how much to put aside each month.
//

import Foundation

enum SavingsPlanner {
    struct Plan: Equatable {
        /// 0...1
        var progress: Double
        var remaining: Double
        var isReached: Bool
        /// Months until the deadline (at least 1), nil without a deadline.
        var monthsLeft: Int?
        /// Suggested amount per month to reach the goal on time.
        var monthlyAmount: Double?
        var isOverdue: Bool
    }

    static func plan(target: Double, saved: Double, deadline: Date?, now: Date = Date(), calendar: Calendar = .current) -> Plan {
        let target = max(target, 0)
        let saved = max(saved, 0)
        let remaining = Money.roundCents(max(target - saved, 0))
        let progress = target > 0 ? min(max(saved / target, 0), 1) : 0
        let reached = target > 0 && remaining == 0

        guard let deadline, !reached else {
            return Plan(progress: progress, remaining: remaining, isReached: reached,
                        monthsLeft: nil, monthlyAmount: nil, isOverdue: false)
        }
        let start = calendar.startOfDay(for: now)
        let end = calendar.startOfDay(for: deadline)
        if end < start {
            return Plan(progress: progress, remaining: remaining, isReached: false,
                        monthsLeft: 0, monthlyAmount: remaining, isOverdue: true)
        }
        let components = calendar.dateComponents([.month, .day], from: start, to: end)
        // A started month counts: 1 month and 3 days → 2 months to save in.
        let months = max(1, (components.month ?? 0) + ((components.day ?? 0) > 0 ? 1 : 0))
        let monthly = (remaining / Double(months) * 100).rounded(.up) / 100
        return Plan(progress: progress, remaining: remaining, isReached: false,
                    monthsLeft: months, monthlyAmount: monthly, isOverdue: false)
    }

    static func plan(for goal: SavingsGoal, now: Date = Date(), calendar: Calendar = .current) -> Plan {
        plan(target: goal.target, saved: goal.saved, deadline: goal.deadline, now: now, calendar: calendar)
    }
}
