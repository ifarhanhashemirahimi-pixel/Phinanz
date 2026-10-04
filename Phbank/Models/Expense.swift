//
//  Expense.swift
//  Phbank
//
//  A single journal entry: money out (expense) or money in (income).
//

import Foundation
import SwiftData

enum ExpenseCategory: String, CaseIterable, Codable, Identifiable {
    // Spending
    case groceries, food, transport, housing, entertainment, health, shopping, software, travel, other
    // Income
    case salary, freelance, refund, otherIncome

    var id: String { rawValue }

    var isIncome: Bool {
        switch self {
        case .salary, .freelance, .refund, .otherIncome: true
        default: false
        }
    }

    static var expenseCases: [ExpenseCategory] { allCases.filter { !$0.isIncome } }
    static var incomeCases: [ExpenseCategory] { allCases.filter(\.isIncome) }

    var title: String {
        switch self {
        case .groceries: String(localized: "Groceries")
        case .food: String(localized: "Food & Drink")
        case .transport: String(localized: "Transport")
        case .housing: String(localized: "Housing")
        case .entertainment: String(localized: "Entertainment")
        case .health: String(localized: "Health")
        case .shopping: String(localized: "Shopping")
        case .software: String(localized: "Software")
        case .travel: String(localized: "Travel")
        case .other: String(localized: "Other")
        case .salary: String(localized: "Salary")
        case .freelance: String(localized: "Side income")
        case .refund: String(localized: "Refund")
        case .otherIncome: String(localized: "Other income")
        }
    }

    /// SF Symbol shown in white on the category colour.
    var symbol: String {
        switch self {
        case .groceries: "cart.fill"
        case .food: "fork.knife"
        case .transport: "tram.fill"
        case .housing: "house.fill"
        case .entertainment: "film.fill"
        case .health: "cross.case.fill"
        case .shopping: "bag.fill"
        case .software: "laptopcomputer"
        case .travel: "airplane"
        case .other: "ellipsis"
        case .salary: "banknote.fill"
        case .freelance: "briefcase.fill"
        case .refund: "arrow.uturn.backward"
        case .otherIncome: "plus"
        }
    }

    /// Lenient mapping used for AI output and legacy data. Unknown labels become `.other`.
    static func parse(_ label: String) -> ExpenseCategory {
        let key = label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let exact = allCases.first(where: { $0.rawValue.lowercased() == key }) { return exact }
        let aliases: [String: ExpenseCategory] = [
            "grocery": .groceries, "supermarket": .groceries,
            "restaurant": .food, "coffee": .food, "dining": .food, "drink": .food, "food & drink": .food,
            "taxi": .transport, "fuel": .transport, "public transport": .transport,
            "rent": .housing, "utilities": .housing,
            "subscription": .entertainment, "streaming": .entertainment,
            "pharmacy": .health, "medical": .health,
            "clothing": .shopping, "electronics": .shopping,
            "app": .software,
            "income": .otherIncome, "other income": .otherIncome, "wage": .salary, "gehalt": .salary,
            "side income": .freelance, "bonus": .otherIncome
        ]
        return aliases[key] ?? .other
    }
}

enum ExpenseSource: String, Codable {
    case manual, voice, receipt, statement, recurring

    var title: String {
        switch self {
        case .manual: String(localized: "Manual")
        case .voice: String(localized: "Voice note")
        case .receipt: String(localized: "Receipt scan")
        case .statement: String(localized: "Bank statement")
        case .recurring: String(localized: "Recurring payment")
        }
    }
}

@Model
final class Expense {
    var store: String = ""
    /// Always a positive number of euros; `isIncome` decides the direction.
    var amount: Double = 0
    var categoryRaw: String = ExpenseCategory.other.rawValue
    var date: Date = Date()
    var note: String = ""
    var sourceRaw: String = ExpenseSource.manual.rawValue
    var isIncome: Bool = false

    init(
        store: String,
        amount: Double,
        category: ExpenseCategory = .other,
        date: Date = Date(),
        note: String = "",
        source: ExpenseSource = .manual,
        isIncome: Bool = false
    ) {
        self.store = store
        self.amount = amount
        self.categoryRaw = category.rawValue
        self.date = date
        self.note = note
        self.sourceRaw = source.rawValue
        self.isIncome = isIncome
    }

    var category: ExpenseCategory {
        get { ExpenseCategory.parse(categoryRaw) }
        set { categoryRaw = newValue.rawValue }
    }

    var source: ExpenseSource {
        get { ExpenseSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    /// Positive for income, negative for spending.
    var signedAmount: Double { isIncome ? amount : -amount }
}
