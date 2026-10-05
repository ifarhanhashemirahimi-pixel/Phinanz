//
//  SavingsGoal.swift
//  Phbank
//
//  Something you are saving for: a trip, a laptop, an emergency fund.
//

import Foundation
import SwiftData

@Model
final class SavingsGoal {
    var id: String = UUID().uuidString
    var name: String = ""
    var target: Double = 0
    var saved: Double = 0
    /// Optional target date; PHINANZ then suggests a monthly amount.
    var deadline: Date?
    var symbol: String = "star.fill"
    var colorName: String = "blue"
    var createdAt: Date = Date()

    init(name: String, target: Double, saved: Double = 0, deadline: Date? = nil,
         symbol: String = "star.fill", colorName: String = "blue", createdAt: Date = Date()) {
        self.id = UUID().uuidString
        self.name = name
        self.target = target
        self.saved = saved
        self.deadline = deadline
        self.symbol = symbol
        self.colorName = colorName
        self.createdAt = createdAt
    }
}
