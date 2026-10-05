//
//  MonthRecap.swift
//  Phinanz
//
//  The plain-language recap of one month, kept so it is written only once
//  (and Gemini is asked at most once per month and set of numbers).
//

import Foundation
import SwiftData

@Model
final class MonthRecap {
    /// "yyyy-MM".
    var monthKey: String = ""
    var text: String = ""
    /// "local" (written on the iPhone) or "gemini".
    var sourceRaw: String = "local"
    /// Changes whenever the month's numbers change, so an old text is replaced.
    var fingerprint: String = ""
    var createdAt: Date = Date()

    init(monthKey: String, text: String, sourceRaw: String, fingerprint: String, createdAt: Date = Date()) {
        self.monthKey = monthKey
        self.text = text
        self.sourceRaw = sourceRaw
        self.fingerprint = fingerprint
        self.createdAt = createdAt
    }
}
