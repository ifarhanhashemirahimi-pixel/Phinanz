//
//  AccountLedger.swift
//  Phbank
//
//  Balances per account. Transfers move money between accounts and cancel
//  out in the total, so the total balance is simply all opening balances
//  plus all income minus all spending.
//

import Foundation
import SwiftData

struct AccountBalance: Identifiable, Equatable {
    let accountID: String
    let name: String
    let kind: AccountKind
    let balance: Double
    var id: String { accountID }
}

enum AccountLedger {
    /// The main account: lowest sort order, then oldest. Entries without a
    /// known account belong to it.
    static func primary(_ accounts: [Account]) -> Account? {
        accounts.min { ($0.sortOrder, $0.createdAt) < ($1.sortOrder, $1.createdAt) }
    }

    static func sorted(_ accounts: [Account]) -> [Account] {
        accounts.sorted { ($0.sortOrder, $0.createdAt) < ($1.sortOrder, $1.createdAt) }
    }

    /// The account an entry really belongs to.
    static func accountID(for rawID: String, accounts: [Account]) -> String {
        if !rawID.isEmpty, accounts.contains(where: { $0.id == rawID }) { return rawID }
        return primary(accounts)?.id ?? ""
    }

    static func balance(
        of account: Account,
        accounts: [Account],
        entries: [Expense],
        transfers: [Transfer],
        upTo date: Date = Date()
    ) -> Double {
        let id = account.id
        let booked = entries
            .filter { $0.date <= date && accountID(for: $0.accountID, accounts: accounts) == id }
            .reduce(0) { $0 + $1.signedAmount }
        let moved = transfers
            .filter { $0.date <= date }
            .reduce(0.0) { sum, transfer in
                var change = 0.0
                if accountID(for: transfer.toAccountID, accounts: accounts) == id { change += transfer.amount }
                if accountID(for: transfer.fromAccountID, accounts: accounts) == id { change -= transfer.amount }
                return sum + change
            }
        return Money.roundCents(account.openingBalance + booked + moved)
    }

    static func balances(accounts: [Account], entries: [Expense], transfers: [Transfer], upTo date: Date = Date()) -> [AccountBalance] {
        sorted(accounts).map {
            AccountBalance(
                accountID: $0.id,
                name: $0.name,
                kind: $0.kind,
                balance: balance(of: $0, accounts: accounts, entries: entries, transfers: transfers, upTo: date)
            )
        }
    }

    /// All accounts together. Transfers cancel out.
    static func total(accounts: [Account], entries: [Expense], upTo date: Date = Date()) -> Double {
        let openings = accounts.reduce(0) { $0 + $1.openingBalance }
        return ExpenseStats.balance(starting: openings, entries: entries, upTo: date)
    }
}

enum AccountStore {
    /// Makes sure there is a main account. On the first launch after the
    /// update it takes over the old "starting balance" setting.
    @MainActor
    @discardableResult
    static func ensurePrimaryAccount(in context: ModelContext, defaults: UserDefaults = .standard) -> Account? {
        let existing = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        if let primary = AccountLedger.primary(existing) { return primary }
        let account = Account(
            name: String(localized: "Main Account"),
            kind: .checking,
            openingBalance: defaults.double(forKey: SettingsKeys.startingBalance)
        )
        context.insert(account)
        try? context.save()
        return account
    }

    /// Deletes an account; its entries, payments and transfers move to the main account.
    @MainActor
    static func delete(_ account: Account, in context: ModelContext) {
        let accounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        guard let primary = AccountLedger.primary(accounts), primary.id != account.id else { return }
        let id = account.id
        for entry in (try? context.fetch(FetchDescriptor<Expense>(predicate: #Predicate { $0.accountID == id }))) ?? [] {
            entry.accountID = primary.id
        }
        for payment in (try? context.fetch(FetchDescriptor<RecurringPayment>(predicate: #Predicate { $0.accountID == id }))) ?? [] {
            payment.accountID = primary.id
        }
        for transfer in (try? context.fetch(FetchDescriptor<Transfer>())) ?? []
        where transfer.fromAccountID == id || transfer.toAccountID == id {
            if transfer.fromAccountID == id { transfer.fromAccountID = primary.id }
            if transfer.toAccountID == id { transfer.toAccountID = primary.id }
            // A transfer from the main account to itself means nothing.
            if AccountLedger.accountID(for: transfer.fromAccountID, accounts: accounts)
                == AccountLedger.accountID(for: transfer.toAccountID, accounts: accounts) {
                context.delete(transfer)
            }
        }
        primary.openingBalance = Money.roundCents(primary.openingBalance + account.openingBalance)
        context.delete(account)
        try? context.save()
    }
}
