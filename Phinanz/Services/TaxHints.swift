//
//  TaxHints.swift
//  Phinanz
//
//  Spots expenses that could matter for the German income tax return
//  (donations, work equipment, training, tradespeople, childcare …) so they
//  are easy to find at the end of the year.
//
//  These are hints, not tax advice: PHINANZ never says what is deductible or
//  how much. Only licensed advisers may give tax advice in Germany (§ 5 StBerG).
//

import Foundation

/// What the user decided for one entry.
enum TaxMark: Int, Codable {
    /// Follow the automatic suggestion.
    case automatic = 0
    /// "Remember this for my tax return", even without a suggestion.
    case marked = 1
    /// Not relevant, even if the app suggested it.
    case dismissed = 2
}

enum TaxHintKind: String, CaseIterable, Identifiable {
    case donation, education, work, household, childcare, insurance, health

    var id: String { rawValue }

    var title: String {
        switch self {
        case .donation: String(localized: "Donation")
        case .education: String(localized: "Training & Books")
        case .work: String(localized: "Work Expenses")
        case .household: String(localized: "Tradespeople & Household Help")
        case .childcare: String(localized: "Childcare")
        case .insurance: String(localized: "Insurance & Pension")
        case .health: String(localized: "Medical Costs")
        }
    }

    var symbol: String {
        switch self {
        case .donation: "heart.fill"
        case .education: "book.fill"
        case .work: "briefcase.fill"
        case .household: "wrench.and.screwdriver.fill"
        case .childcare: "figure.and.child.holdinghands"
        case .insurance: "umbrella.fill"
        case .health: "cross.case.fill"
        }
    }

    /// Lower-cased, diacritic-free keywords. Short ones (≤ 5 letters) must match a whole word.
    fileprivate var keywords: [String] {
        switch self {
        case .donation:
            ["spende", "spenden", "unicef", "caritas", "diakonie", "rotes kreuz", "drk", "arzte ohne grenzen",
             "brot fur die welt", "misereor", "greenpeace", "wwf", "amnesty", "betterplace", "donation", "charity"]
        case .education:
            ["fachbuch", "fachliteratur", "fortbildung", "weiterbildung", "seminar", "schulung", "lehrgang",
             "volkshochschule", "vhs", "ihk", "prufungsgebuhr", "sprachkurs", "deutschkurs", "udemy", "coursera"]
        case .work:
            ["arbeitsmittel", "arbeitskleidung", "berufskleidung", "bewerbung", "gewerkschaft", "verdi",
             "ig metall", "dienstreise", "buromaterial", "steuerberater", "lohnsteuerhilfe", "steuersoftware"]
        case .household:
            ["handwerker", "elektriker", "klempner", "installateur", "malerbetrieb", "schornsteinfeger",
             "hausmeister", "gartenpflege", "putzhilfe", "haushaltshilfe", "reinigungskraft", "umzugsunternehmen",
             "nebenkostenabrechnung"]
        case .childcare:
            ["kita", "kindergarten", "kindertagesstatte", "tagesmutter", "kinderbetreuung", "hort"]
        case .insurance:
            ["haftpflicht", "berufsunfahigkeit", "unfallversicherung", "rentenversicherung", "riester", "rurup",
             "risikolebensversicherung", "pflegeversicherung"]
        case .health:
            ["zuzahlung", "zahnarzt", "brille", "optiker", "physiotherap", "krankengymnastik", "horgerat",
             "arztrechnung", "heilpraktiker"]
        }
    }
}

enum TaxHints {
    /// The automatic suggestion for an entry, from its store, note and category.
    static func suggestion(store: String, note: String, isIncome: Bool) -> TaxHintKind? {
        guard !isIncome else { return nil }
        let text = " " + normalize(store + " " + note) + " "
        for kind in TaxHintKind.allCases where kind.keywords.contains(where: { matches($0, in: text) }) {
            return kind
        }
        return nil
    }

    static func suggestion(for entry: Expense) -> TaxHintKind? {
        suggestion(store: entry.store, note: entry.note, isIncome: entry.isIncome)
    }

    /// Whether the entry belongs on the "for your tax return" list.
    static func isRelevant(_ entry: Expense) -> Bool {
        isRelevant(mark: entry.taxMark, suggestion: suggestion(for: entry), isIncome: entry.isIncome)
    }

    static func isRelevant(mark: TaxMark, suggestion: TaxHintKind?, isIncome: Bool) -> Bool {
        guard !isIncome else { return false }
        switch mark {
        case .marked: return true
        case .dismissed: return false
        case .automatic: return suggestion != nil
        }
    }

    /// The mark to store when the user flips the switch: `.automatic` whenever
    /// the choice agrees with the suggestion, so later keyword updates still apply.
    static func mark(forRelevant relevant: Bool, suggestion: TaxHintKind?) -> TaxMark {
        if relevant == (suggestion != nil) { return .automatic }
        return relevant ? .marked : .dismissed
    }

    static func relevant(_ entries: [Expense]) -> [Expense] {
        entries.filter { isRelevant($0) }.sorted { $0.date < $1.date }
    }

    // MARK: Matching

    static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "de_DE"))
            .lowercased()
            .replacingOccurrences(of: "ß", with: "ss")
            .map { $0.isLetter || $0.isNumber ? $0 : " " }
            .reduce(into: "") { $0.append($1) }
    }

    /// Keywords up to five letters need a whole word ("drk", "kita", "verdi");
    /// longer ones may be part of a word ("Zahnarztpraxis", "Fortbildungskosten").
    private static func matches(_ keyword: String, in paddedText: String) -> Bool {
        keyword.count <= 5 ? paddedText.contains(" \(keyword) ") : paddedText.contains(keyword)
    }
}
