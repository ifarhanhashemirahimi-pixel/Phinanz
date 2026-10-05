//
//  RecurringPayment.swift
//  Phinanz
//
//  Rent, subscriptions, insurance or salary that repeat every month.
//  Entries are created automatically on the given day (see RecurringScheduler).
//

import Foundation
import SwiftData

@Model
final class RecurringPayment {
    var name: String = ""
    var amount: Double = 0
    var categoryRaw: String = ExpenseCategory.other.rawValue
    var isIncome: Bool = false
    /// 1...31; clamped to the month's length (31 → 30 or 28/29).
    var dayOfMonth: Int = 1
    var startDate: Date = Date()
    /// Date of the last entry this payment created.
    var lastGenerated: Date?
    var isActive: Bool = true
    var note: String = ""
    /// `Account.id`; empty means the main account.
    var accountID: String = ""

    init(
        name: String,
        amount: Double,
        category: ExpenseCategory,
        isIncome: Bool = false,
        dayOfMonth: Int,
        startDate: Date = Date(),
        note: String = "",
        accountID: String = ""
    ) {
        self.name = name
        self.amount = amount
        self.categoryRaw = category.rawValue
        self.isIncome = isIncome
        self.dayOfMonth = min(max(dayOfMonth, 1), 31)
        self.startDate = startDate
        self.note = note
        self.accountID = accountID
    }

    var category: ExpenseCategory {
        get { ExpenseCategory.parse(categoryRaw) }
        set { categoryRaw = newValue.rawValue }
    }
}

enum AppSchema {
    static let models: [any PersistentModel.Type] = [
        Expense.self, CategoryBudget.self, RecurringPayment.self,
        Account.self, Transfer.self, SavingsGoal.self
    ]
}
