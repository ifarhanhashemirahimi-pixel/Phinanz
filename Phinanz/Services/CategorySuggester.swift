//
//  CategorySuggester.swift
//  Phinanz
//
//  Picks a category from the store name: first from your own history
//  (the category you used last time at that store), then from a list of
//  common German merchants.
//

import Foundation

enum CategorySuggester {
    /// Lower-cased keywords → category. Matched as whole words or prefixes.
    static let keywords: [(String, ExpenseCategory)] = [
        // Groceries
        ("rewe", .groceries), ("lidl", .groceries), ("aldi", .groceries), ("edeka", .groceries),
        ("netto", .groceries), ("penny", .groceries), ("kaufland", .groceries), ("tegut", .groceries),
        ("alnatura", .groceries), ("denns", .groceries), ("supermarkt", .groceries),
        // Food & drink
        ("bäcker", .food), ("baecker", .food), ("café", .food), ("cafe", .food), ("restaurant", .food),
        ("starbucks", .food), ("mcdonald", .food), ("burger", .food), ("pizza", .food), ("döner", .food),
        ("doner", .food), ("vapiano", .food), ("lieferando", .food), ("wolt", .food), ("kantine", .food),
        // Transport
        ("rmv", .transport), ("db ", .transport), ("deutsche bahn", .transport), ("bvg", .transport),
        ("mvv", .transport), ("hvv", .transport), ("uber", .transport), ("bolt", .transport), ("taxi", .transport),
        ("shell", .transport), ("aral", .transport), ("esso", .transport), ("jet ", .transport), ("tankstelle", .transport),
        ("deutschlandticket", .transport), ("flixbus", .transport), ("tier", .transport), ("lime", .transport),
        // Housing
        ("miete", .housing), ("strom", .housing), ("stadtwerke", .housing), ("vodafone", .housing),
        ("telekom", .housing), ("o2", .housing), ("1&1", .housing), ("gez", .housing), ("rundfunk", .housing),
        // Entertainment
        ("netflix", .entertainment), ("spotify", .entertainment), ("disney", .entertainment), ("kino", .entertainment),
        ("cinemaxx", .entertainment), ("dazn", .entertainment), ("youtube", .entertainment), ("playstation", .entertainment),
        ("steam", .entertainment), ("audible", .entertainment),
        // Health
        ("dm", .health), ("rossmann", .health), ("müller", .health), ("apotheke", .health), ("arzt", .health),
        ("zahnarzt", .health), ("fitness", .health), ("mcfit", .health), ("urban sports", .health),
        // Shopping
        ("amazon", .shopping), ("zalando", .shopping), ("h&m", .shopping), ("zara", .shopping), ("ikea", .shopping),
        ("mediamarkt", .shopping), ("saturn", .shopping), ("otto", .shopping), ("primark", .shopping), ("decathlon", .shopping),
        // Software
        ("apple", .software), ("icloud", .software), ("google", .software), ("microsoft", .software),
        ("adobe", .software), ("chatgpt", .software), ("github", .software), ("app store", .software),
        // Travel
        ("lufthansa", .travel), ("ryanair", .travel), ("eurowings", .travel), ("airbnb", .travel),
        ("booking", .travel), ("hotel", .travel), ("condor", .travel),
        // Income
        ("gehalt", .salary), ("lohn", .salary), ("salary", .salary), ("arbeitgeber", .salary),
        ("erstattung", .refund), ("rückerstattung", .refund), ("refund", .refund)
    ]

    static func suggest(for store: String, history: [Expense] = []) -> ExpenseCategory? {
        let name = store.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard name.count >= 2 else { return nil }

        // 1. What you chose last time at the same store.
        if let previous = history
            .filter({ $0.store.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == name })
            .max(by: { $0.date < $1.date }) {
            return previous.category
        }

        // 2. Known merchants: whole word or word prefix.
        let padded = " " + name + " "
        let words = name.split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "&" }).map(String.init)
        for (keyword, category) in keywords {
            if keyword.hasSuffix(" ") || keyword.contains(" ") {
                if padded.contains(" " + keyword.trimmingCharacters(in: .whitespaces) + " ") || padded.contains(" " + keyword) {
                    return category
                }
            } else if words.contains(where: { $0 == keyword || ($0.hasPrefix(keyword) && keyword.count >= 4) }) {
                return category
            }
        }
        return nil
    }
}
