//
//  Account.swift
//  Phbank
//
//  Where money lives: checking account, cash, credit card, savings.
//  Entries point to an account by its `id`; an empty or unknown id means the
//  main account. Transfers move money between accounts without counting as
//  spending or income.
//
//  No relationships and no unique constraints, so the models can sync with
//  CloudKit unchanged.
//

import Foundation
import SwiftData

enum AccountKind: String, CaseIterable, Codable, Identifiable {
    case checking, cash, credit, savings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .checking: String(localized: "Checking Account")
        case .cash: String(localized: "Cash")
        case .credit: String(localized: "Credit Card")
        case .savings: String(localized: "Savings Account")
        }
    }

    var symbol: String {
        switch self {
        case .checking: "building.columns.fill"
        case .cash: "banknote.fill"
        case .credit: "creditcard.fill"
        case .savings: "eurosign.circle.fill"
        }
    }
}

@Model
final class Account {
    var id: String = UUID().uuidString
    var name: String = ""
    var kindRaw: String = AccountKind.checking.rawValue
    /// What was in the account before the first entry in PHINANZ.
    var openingBalance: Double = 0
    var sortOrder: Int = 0
    var createdAt: Date = Date()

    init(name: String, kind: AccountKind, openingBalance: Double = 0, sortOrder: Int = 0, createdAt: Date = Date()) {
        self.id = UUID().uuidString
        self.name = name
        self.kindRaw = kind.rawValue
        self.openingBalance = openingBalance
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }

    var kind: AccountKind {
        get { AccountKind(rawValue: kindRaw) ?? .checking }
        set { kindRaw = newValue.rawValue }
    }
}

@Model
final class Transfer {
    var id: String = UUID().uuidString
    var fromAccountID: String = ""
    var toAccountID: String = ""
    /// Always positive.
    var amount: Double = 0
    var date: Date = Date()
    var note: String = ""

    init(from: String, to: String, amount: Double, date: Date = Date(), note: String = "") {
        self.id = UUID().uuidString
        self.fromAccountID = from
        self.toAccountID = to
        self.amount = amount
        self.date = date
        self.note = note
    }
}
