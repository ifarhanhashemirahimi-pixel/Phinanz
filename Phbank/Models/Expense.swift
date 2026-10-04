//
//  Expense.swift
//  Phbank
//
//  Persisted money-out entry shown on a page of the yearly journal.
//

import Foundation
import SwiftData

enum ExpenseCategory: String, CaseIterable, Codable, Identifiable {
    case groceries, food, transport, housing, entertainment, health, shopping, software, travel, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .groceries: "Groceries"
        case .food: "Food & Drink"
        case .transport: "Transport"
        case .housing: "Housing"
        case .entertainment: "Entertainment"
        case .health: "Health"
        case .shopping: "Shopping"
        case .software: "Software"
        case .travel: "Travel"
        case .other: "Other"
        }
    }

    var symbol: String {
        switch self {
        case .groceries: "cart"
        case .food: "fork.knife"
        case .transport: "tram.fill"
        case .housing: "house"
        case .entertainment: "film"
        case .health: "cross.case"
        case .shopping: "bag"
        case .software: "laptopcomputer"
        case .travel: "airplane"
        case .other: "ellipsis.circle"
        }
    }

    /// Lenient mapping used for AI output and legacy data. Unknown labels become `.other`.
    static func parse(_ label: String) -> ExpenseCategory {
        let key = label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let exact = ExpenseCategory(rawValue: key) { return exact }
        let aliases: [String: ExpenseCategory] = [
            "grocery": .groceries, "supermarket": .groceries,
            "restaurant": .food, "coffee": .food, "dining": .food, "drink": .food, "food & drink": .food,
            "taxi": .transport, "fuel": .transport, "public transport": .transport,
            "rent": .housing, "utilities": .housing,
            "subscription": .entertainment, "streaming": .entertainment,
            "pharmacy": .health, "medical": .health,
            "clothing": .shopping, "electronics": .shopping,
            "app": .software
        ]
        return aliases[key] ?? .other
    }
}

enum ExpenseSource: String, Codable {
    case manual, voice, receipt, statement

    var title: String {
        switch self {
        case .manual: "Manual"
        case .voice: "Voice note"
        case .receipt: "Receipt scan"
        case .statement: "Bank statement"
        }
    }
}

@Model
final class Expense {
    var store: String = ""
    /// Positive number of euros spent.
    var amount: Double = 0
    var categoryRaw: String = ExpenseCategory.other.rawValue
    var date: Date = Date()
    var note: String = ""
    var sourceRaw: String = ExpenseSource.manual.rawValue

    init(
        store: String,
        amount: Double,
        category: ExpenseCategory = .other,
        date: Date = Date(),
        note: String = "",
        source: ExpenseSource = .manual
    ) {
        self.store = store
        self.amount = amount
        self.categoryRaw = category.rawValue
        self.date = date
        self.note = note
        self.sourceRaw = source.rawValue
    }

    var category: ExpenseCategory {
        get { ExpenseCategory.parse(categoryRaw) }
        set { categoryRaw = newValue.rawValue }
    }

    var source: ExpenseSource {
        get { ExpenseSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }
}
