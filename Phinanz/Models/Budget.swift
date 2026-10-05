//
//  Budget.swift
//  Phinanz
//
//  Monthly spending limit for one category.
//

import Foundation
import SwiftData

@Model
final class CategoryBudget {
    var categoryRaw: String = ExpenseCategory.other.rawValue
    var monthlyLimit: Double = 0

    init(category: ExpenseCategory, monthlyLimit: Double) {
        self.categoryRaw = category.rawValue
        self.monthlyLimit = monthlyLimit
    }

    var category: ExpenseCategory {
        get { ExpenseCategory.parse(categoryRaw) }
        set { categoryRaw = newValue.rawValue }
    }
}
