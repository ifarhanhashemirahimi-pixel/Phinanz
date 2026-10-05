//
//  MonthlyRecap.swift
//  Phinanz
//
//  "Your month in a few sentences": a short, friendly recap of the month
//  before, shown once when a new month starts and at the top of the report.
//
//  The facts are only totals (per category, budgets, tax hints) — never store
//  names or single entries — so even the optional Gemini wording sees nothing
//  more than a monthly summary.
//

import Foundation
import SwiftData

/// Everything the recap may talk about. Amounts are already formatted for the
/// app's language, so neither the local writer nor Gemini does any maths.
struct RecapFacts: Codable, Equatable {
    struct CategoryAmount: Codable, Equatable {
        let category: String
        let amount: String
    }

    let month: String
    let previousMonth: String
    let spent: String
    let earned: String?
    let leftOver: String?
    let overspent: String?
    let savedPercent: Int?
    /// Signed: -12 means 12 % less than the month before.
    let changePercent: Int?
    let topCategories: [CategoryAmount]
    let biggestRise: CategoryAmount?
    let biggestDrop: CategoryAmount?
    let fixedCostsPercent: Int?
    let overBudget: [String]
    let allBudgetsKept: Bool
    let taxHintCount: Int
    let taxHintTotal: String?
    let entryCount: Int

    init(report: MonthlyReport) {
        func percent(_ fraction: Double) -> Int { Int((fraction * 100).rounded()) }
        month = report.month.start.formatted(.dateTime.month(.wide).year())
        previousMonth = report.previousMonth.start.formatted(.dateTime.month(.wide))
        spent = Money.format(report.spending)
        earned = report.income > 0 ? Money.format(report.income) : nil
        leftOver = report.income > 0 && report.net > 0 ? Money.format(report.net) : nil
        overspent = report.income > 0 && report.net < 0 ? Money.format(-report.net) : nil
        savedPercent = report.savingsRate.flatMap { $0 > 0 ? percent($0) : nil }
        changePercent = report.spendingChange.flatMap { abs($0) >= 0.01 ? percent($0) : nil }
        topCategories = report.categories.filter { $0.current > 0 }.prefix(3)
            .map { CategoryAmount(category: $0.category.title, amount: Money.format($0.current)) }
        let threshold = 20.0
        biggestRise = report.categories.filter { $0.previous > 0 && $0.delta >= threshold }.max { $0.delta < $1.delta }
            .map { CategoryAmount(category: $0.category.title, amount: Money.format($0.delta)) }
        biggestDrop = report.categories.filter { $0.previous > 0 && $0.delta <= -threshold }.min { $0.delta < $1.delta }
            .map { CategoryAmount(category: $0.category.title, amount: Money.format(-$0.delta)) }
        fixedCostsPercent = report.spending > 0 && report.fixedCosts > 0 ? percent(report.fixedCosts / report.spending) : nil
        overBudget = report.overBudget.map(\.title)
        allBudgetsKept = report.hasBudgets && report.overBudget.isEmpty
        taxHintCount = report.taxItems.count
        taxHintTotal = report.taxItems.isEmpty ? nil : Money.format(report.taxTotal)
        entryCount = report.entryCount
    }

    /// Sorted-key JSON, the only thing Gemini gets to see.
    func json() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try encoder.encode(self), as: UTF8.self)
    }
}

/// Writes the recap on the iPhone: short sentences, no AI, no network.
enum RecapWriter {
    static func sentences(_ facts: RecapFacts) -> [String] {
        func percent(_ value: Int) -> String {
            (Double(abs(value)) / 100).formatted(.percent.precision(.fractionLength(0)))
        }
        var list: [String] = []

        if let earned = facts.earned {
            list.append(String(localized: "In \(facts.month) you spent \(facts.spent) and received \(earned)."))
        } else {
            list.append(String(localized: "In \(facts.month) you spent \(facts.spent)."))
        }

        if let change = facts.changePercent {
            list.append(change < 0
                ? String(localized: "That is \(percent(change)) less than in \(facts.previousMonth) – nice.")
                : String(localized: "That is \(percent(change)) more than in \(facts.previousMonth)."))
        }

        if facts.topCategories.count >= 2 {
            let first = facts.topCategories[0], second = facts.topCategories[1]
            list.append(String(localized: "Most of it went on \(first.category) (\(first.amount)) and \(second.category) (\(second.amount))."))
        } else if let first = facts.topCategories.first {
            list.append(String(localized: "Most of it went on \(first.category) (\(first.amount))."))
        }

        if let leftOver = facts.leftOver, let saved = facts.savedPercent {
            list.append(saved >= 20
                ? String(localized: "\(leftOver) was left over – \(percent(saved)) of your income. Well done!")
                : String(localized: "\(leftOver) was left over – \(percent(saved)) of your income."))
        } else if let overspent = facts.overspent {
            list.append(String(localized: "You spent \(overspent) more than you received – worth a look this month."))
        }

        if !facts.overBudget.isEmpty {
            list.append(String(localized: "Over budget: \(facts.overBudget.formatted(.list(type: .and)))."))
        } else if facts.allBudgetsKept {
            list.append(String(localized: "You stayed within all your budgets."))
        }

        if let total = facts.taxHintTotal {
            list.append(String(localized: "\(total) could be interesting for your tax return – the list is in the report."))
        }
        return list
    }

    static func text(_ facts: RecapFacts) -> String {
        sentences(facts).joined(separator: " ")
    }
}

/// When the recap card appears: once, on the first launch in a new month,
/// for the month before — and only if that month has a few entries.
enum RecapSchedule {
    static let minimumEntries = 3

    static func monthKey(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
    }

    static func monthToShow(now: Date, lastShownKey: String?, entries: [Expense], calendar: Calendar = .current) -> Date? {
        guard let thisMonth = calendar.dateInterval(of: .month, for: now),
              let previousStart = calendar.date(byAdding: .month, value: -1, to: thisMonth.start),
              let previous = calendar.dateInterval(of: .month, for: previousStart)
        else { return nil }
        guard monthKey(previous.start, calendar: calendar) != lastShownKey else { return nil }
        guard ExpenseStats.expenses(entries, in: previous).count >= minimumEntries else { return nil }
        return previous.start
    }
}

struct RecapResult: Equatable {
    let text: String
    let byGemini: Bool
}

/// Picks the recap text: Gemini's wording when the user turned it on (cached
/// per month and set of numbers), otherwise — or when anything fails — the
/// local text, which is always available instantly.
enum RecapProvider {
    static var geminiAllowed: Bool {
        UserDefaults.standard.bool(forKey: SettingsKeys.recapAI) && AIReadiness.issue() == nil
    }

    static var languageCode: String {
        switch Locale.current.language.languageCode?.identifier {
        case "de": "de"
        case "fa": "fa"
        default: "en"
        }
    }

    static func fingerprint(_ facts: RecapFacts, language: String) -> String {
        "\(language)|\(facts.entryCount)|\(facts.spent)|\(facts.earned ?? "-")|\(facts.taxHintTotal ?? "-")|\(facts.overBudget.joined(separator: ","))"
    }

    static func local(for report: MonthlyReport) -> RecapResult {
        RecapResult(text: RecapWriter.text(RecapFacts(report: report)), byGemini: false)
    }

    static func recap(for report: MonthlyReport, context: ModelContext, allowGemini: Bool = true) async -> RecapResult {
        let facts = RecapFacts(report: report)
        let local = RecapResult(text: RecapWriter.text(facts), byGemini: false)
        guard allowGemini, geminiAllowed, !report.isEmpty else { return local }

        let key = RecapSchedule.monthKey(report.month.start)
        let language = languageCode
        let stamp = fingerprint(facts, language: language)
        let descriptor = FetchDescriptor<MonthRecap>(predicate: #Predicate { $0.monthKey == key })
        let stored = (try? context.fetch(descriptor)) ?? []
        if let cached = stored.first(where: { $0.fingerprint == stamp && !$0.text.isEmpty }) {
            return RecapResult(text: cached.text, byGemini: true)
        }

        let apiKey = KeychainStore.get(SettingsKeys.apiKeyAccount) ?? ""
        let storedModel = UserDefaults.standard.string(forKey: SettingsKeys.geminiModel) ?? ""
        let service = GeminiService(apiKey: apiKey, model: storedModel.isEmpty ? GeminiService.defaultModel : storedModel)
        guard let text = try? await service.writeRecap(facts: facts, language: language) else { return local }

        for old in stored { context.delete(old) }
        context.insert(MonthRecap(monthKey: key, text: text, sourceRaw: "gemini", fingerprint: stamp))
        try? context.save()
        return RecapResult(text: text, byGemini: true)
    }
}
