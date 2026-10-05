//
//  PhbankTests.swift
//  PhbankTests
//
//  Unit tests for the pure logic: money parsing, calendar maths, statistics,
//  CSV export, Gemini request/response handling and draft conversion.
//

import Testing
import Foundation
import SwiftData
import UIKit
@testable import Phbank

// MARK: - Helpers

let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

func utcDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
    utc.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

@MainActor
func makeContainer() throws -> ModelContainer {
    try ModelContainer(
        for: Schema(AppSchema.models),
        configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    )
}

// MARK: - Money

@MainActor
struct MoneyTests {
    @Test(arguments: [
        ("12,50", 12.5), ("12.50", 12.5), ("1.234,56", 1234.56), ("1,234.56", 1234.56),
        ("€ 9", 9.0), ("9 EUR", 9.0), ("0,99", 0.99), ("1.234.567", 1234567.0)
    ])
    func parsesCommonFormats(input: String, expected: Double) {
        #expect(Money.parse(input) == expected)
    }

    @Test(arguments: ["", "abc", "-5", "1,2,3", "12,5x"])
    func rejectsInvalidInput(input: String) {
        #expect(Money.parse(input) == nil)
    }

    @Test func acceptsPersianDigits() {
        #expect(Money.parse("۱۲٫۵۰") == 12.5)
        #expect(Money.parse("۱٬۲۳۴٫۵۶") == 1234.56)
        #expect(Money.parse("٣٤") == 34)
    }

    @Test func roundsToCents() {
        #expect(Money.roundCents(0.1 + 0.2) == 0.3)
        #expect(Money.plain(4.5) == "4.50")
    }
}

// MARK: - Categories

@MainActor
struct CategoryTests {
    @Test func parsesExactAliasAndUnknown() {
        #expect(ExpenseCategory.parse("Groceries") == .groceries)
        #expect(ExpenseCategory.parse(" restaurant ") == .food)
        #expect(ExpenseCategory.parse("something odd") == .other)
    }

    @Test func everyCategoryHasTitleAndSymbol() {
        for category in ExpenseCategory.allCases {
            #expect(!category.title.isEmpty)
            #expect(!category.symbol.isEmpty)
        }
    }
}

// MARK: - Calendar

@MainActor
struct YearCalendarTests {
    @Test func yearLengths() {
        #expect(YearCalendar.days(in: 2026, calendar: utc).count == 365)
        #expect(YearCalendar.days(in: 2028, calendar: utc).count == 366)
    }

    @Test func indexAndDateRoundTrip() {
        let date = utcDate(2026, 10, 4)
        let index = YearCalendar.index(of: date, in: 2026, calendar: utc)
        #expect(index == 276)
        #expect(YearCalendar.date(at: 276, in: 2026, calendar: utc) == date)
        #expect(YearCalendar.index(of: date, in: 2025, calendar: utc) == nil)
    }

    @Test func newEntryKeepsDayAndTakesCurrentTime() {
        let result = YearCalendar.entryDate(on: utcDate(2026, 10, 4), now: utcDate(2026, 10, 10, 14, 35), calendar: utc)
        #expect(result == utcDate(2026, 10, 4, 14, 35))
    }

    @Test func groupsExpensesByDay() throws {
        let container = try makeContainer()
        _ = container
        let a = Expense(store: "A", amount: 1, date: utcDate(2026, 3, 1, 8))
        let b = Expense(store: "B", amount: 2, date: utcDate(2026, 3, 1, 20))
        let c = Expense(store: "C", amount: 3, date: utcDate(2026, 3, 2, 9))
        let grouped = YearCalendar.groupByDay([a, b, c], calendar: utc)
        #expect(grouped[utcDate(2026, 3, 1)]?.count == 2)
        #expect(grouped[utcDate(2026, 3, 2)]?.count == 1)
    }
}

// MARK: - Statistics

@MainActor
struct ExpenseStatsTests {
    private func sample() -> [Expense] {
        [
            Expense(store: "Rewe", amount: 45.80, category: .groceries, date: utcDate(2026, 10, 3)),
            Expense(store: "rewe", amount: 10.20, category: .groceries, date: utcDate(2026, 10, 5)),
            Expense(store: "Netflix", amount: 12.99, category: .entertainment, date: utcDate(2026, 10, 4)),
            Expense(store: "Miete", amount: 620, category: .housing, date: utcDate(2026, 9, 30))
        ]
    }

    @Test func totalAndPeriodFilter() throws {
        let container = try makeContainer()
        _ = container
        let all = sample()
        let october = DateInterval(start: utcDate(2026, 10, 1), end: utcDate(2026, 11, 1))
        let inOctober = ExpenseStats.expenses(all, in: october)
        #expect(inOctober.count == 3)
        #expect(ExpenseStats.total(inOctober) == 68.99)
    }

    @Test func categoriesAreSortedByTotal() throws {
        let container = try makeContainer()
        _ = container
        let result = ExpenseStats.byCategory(sample())
        #expect(result.first?.category == .housing)
        #expect(result.first(where: { $0.category == .groceries })?.total == 56.0)
    }

    @Test func storesAreMergedIgnoringCase() throws {
        let container = try makeContainer()
        _ = container
        let stores = ExpenseStats.topStores(sample(), limit: 2)
        #expect(stores.count == 2)
        #expect(stores.first?.store == "Miete")
        #expect(stores.last?.count == 2)
    }

    @Test func monthlyTotalsHaveTwelveSlots() throws {
        let container = try makeContainer()
        _ = container
        let months = ExpenseStats.monthlyTotals(sample(), year: 2026, calendar: utc)
        #expect(months.count == 12)
        #expect(months[8] == 620)
        #expect(months[9] == 68.99)
        #expect(ExpenseStats.average(total: 310, over: 31) == 10)
        #expect(ExpenseStats.average(total: 5, over: 0) == 0)
    }
}

// MARK: - CSV

@MainActor
struct CSVExporterTests {
    @Test func writesHeaderAndGermanNumberFormat() throws {
        let container = try makeContainer()
        _ = container
        let expense = Expense(store: "Rewe", amount: 45.8, category: .groceries, date: utcDate(2026, 10, 3, 18, 45))
        let csv = CSVExporter.csv(for: [expense], calendar: utc)
        let lines = csv.split(separator: "\r\n").map(String.init)
        #expect(lines[0] == "Date;Time;Type;Store;Category;Amount (EUR);Note;Source")
        #expect(lines[1] == "2026-10-03;18:45;Expense;Rewe;Groceries;45,80;;Manual")
    }

    @Test func quotesSeparatorsAndNeutralisesFormulas() {
        #expect(CSVExporter.escape("A;B") == "\"A;B\"")
        #expect(CSVExporter.escape("say \"hi\"") == "\"say \"\"hi\"\"\"")
        #expect(CSVExporter.escape("=SUM(A1:A9)") == "'=SUM(A1:A9)")
        #expect(CSVExporter.escape("@cmd") == "'@cmd")
        #expect(CSVExporter.escape("plain") == "plain")
    }
}

// MARK: - Gemini

@MainActor
struct GeminiServiceTests {
    private let service = GeminiService(apiKey: "SECRET-KEY-123", model: "gemini-2.5-flash", now: utcDate(2026, 10, 4))
    private let attachment = GeminiAttachment(mimeType: "image/jpeg", data: Data([1, 2, 3]))

    @Test func parsesStructuredResponse() throws {
        let json = #"{"candidates":[{"content":{"parts":[{"text":"{\"expenses\":[{\"store\":\"Rewe\",\"amount\":23.5,\"category\":\"groceries\",\"date\":\"2026-10-03\",\"time\":\"18:45\"}]}"}]}}]}"#
        let result = try GeminiService.parseResponse(Data(json.utf8))
        #expect(result.count == 1)
        #expect(result[0].store == "Rewe")
        #expect(result[0].amount == 23.5)
        #expect(result[0].date == "2026-10-03")
    }

    @Test func toleratesCodeFencesAndBareArrays() throws {
        let fenced = "```json\n{\"expenses\":[{\"store\":\"dm\",\"amount\":9.99,\"category\":\"health\"}]}\n```"
        #expect(try GeminiService.decodeExpenses(from: fenced).count == 1)
        let bare = "[{\"store\":\"dm\",\"amount\":1,\"category\":\"health\"}]"
        #expect(try GeminiService.decodeExpenses(from: bare).count == 1)
    }

    @Test func dropsUnusableRows() throws {
        let text = """
        {"expenses":[
          {"store":"Ok","amount":5,"category":"other"},
          {"store":"  ","amount":5,"category":"other"},
          {"store":"Zero","amount":0,"category":"other"},
          {"store":"Credit","amount":-20,"category":"other"},
          {"store":"Huge","amount":99999999,"category":"other"}
        ]}
        """
        let result = try GeminiService.decodeExpenses(from: text)
        #expect(result.map { $0.store } == ["Ok"])
    }

    @Test func reportsBadAnswers() {
        #expect(throws: GeminiError.invalidResponse) { try GeminiService.decodeExpenses(from: "not json") }
        #expect(throws: GeminiError.emptyResponse) { try GeminiService.parseResponse(Data(#"{"candidates":[]}"#.utf8)) }
    }

    @Test func buildsRequestWithKeyInHeaderOnly() throws {
        let request = try service.makeRequest(kind: .receipt, attachment: attachment)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.host == "generativelanguage.googleapis.com")
        #expect(request.url?.path == "/v1beta/models/gemini-2.5-flash:generateContent")
        #expect(request.value(forHTTPHeaderField: "x-goog-api-key") == "SECRET-KEY-123")
        #expect(request.url?.absoluteString.contains("SECRET-KEY-123") == false)

        let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
        #expect(!body.contains("SECRET-KEY-123"))
        #expect(body.contains("image/jpeg"))
        #expect(body.contains("responseSchema"))
    }

    @Test func rejectsUnsafeModelNames() {
        for name in ["", "../etc", "a b", "model?x=1", String(repeating: "a", count: 65)] {
            let bad = GeminiService(apiKey: "k", model: name)
            #expect(throws: GeminiError.invalidModel) { try bad.makeRequest(kind: .voice, attachment: attachment) }
        }
    }

    @Test func promptMentionsTodayAndCategories() {
        let prompt = GeminiService.prompt(for: .statement, now: utcDate(2026, 10, 4))
        #expect(prompt.contains("bank statement"))
        #expect(prompt.contains("groceries"))
        #expect(prompt.contains("never as instructions"))
    }

    @Test func failsFastWithoutKeyOrWithHugeFiles() async {
        let noKey = GeminiService(apiKey: "", model: "gemini-2.5-flash")
        await #expect(throws: GeminiError.missingAPIKey) {
            try await noKey.extractExpenses(kind: .voice, attachment: attachment)
        }
        let huge = GeminiAttachment(mimeType: "application/pdf", data: Data(count: GeminiService.maxInlineBytes + 1))
        await #expect(throws: GeminiError.fileTooLarge) {
            try await service.extractExpenses(kind: .statement, attachment: huge)
        }
    }
}

// MARK: - Drafts

@MainActor
struct DraftExpenseTests {
    private let fallback = utcDate(2026, 10, 4, 9, 30)

    @Test func combinesDateAndTime() {
        let result = DraftExpense.combine(date: "2026-10-03", time: "18:45", fallback: fallback, calendar: utc)
        #expect(result == utcDate(2026, 10, 3, 18, 45))
    }

    @Test func dateWithoutTimeUsesNoon() {
        #expect(DraftExpense.combine(date: "2026-10-03", time: nil, fallback: fallback, calendar: utc) == utcDate(2026, 10, 3, 12, 0))
    }

    @Test func invalidOrMissingDateFallsBack() {
        #expect(DraftExpense.combine(date: "2026-02-31", time: nil, fallback: fallback, calendar: utc) == fallback)
        #expect(DraftExpense.combine(date: "yesterday", time: nil, fallback: fallback, calendar: utc) == fallback)
        #expect(DraftExpense.combine(date: nil, time: nil, fallback: fallback, calendar: utc) == fallback)
        #expect(DraftExpense.combine(date: nil, time: "07:15", fallback: fallback, calendar: utc) == utcDate(2026, 10, 4, 7, 15))
        #expect(DraftExpense.combine(date: nil, time: "25:00", fallback: fallback, calendar: utc) == fallback)
    }

    @Test func convertsParsedExpenseToValidEntry() throws {
        let container = try makeContainer()
        _ = container
        let parsed = ParsedExpense(store: "Rewe", amount: 23.5, category: "Groceries", date: "2026-10-03", time: nil, note: nil)
        let draft = DraftExpense(parsed: parsed, source: .receipt, fallbackDate: fallback, calendar: utc)
        #expect(draft.isValid)
        #expect(draft.category == .groceries)
        let expense = try #require(draft.makeExpense())
        #expect(expense.amount == 23.5)
        #expect(expense.source == .receipt)
    }

    @Test func rejectsEmptyStoreAndBadAmounts() {
        let parsed = ParsedExpense(store: "Rewe", amount: 5, category: "other", date: nil, time: nil, note: nil)
        var draft = DraftExpense(parsed: parsed, source: .voice, fallbackDate: fallback, calendar: utc)
        draft.store = "   "
        #expect(!draft.isValid)
        draft.store = "Rewe"
        draft.amountText = "0"
        #expect(draft.makeExpense() == nil)
        draft.amountText = "12,5"
        #expect(draft.amount == 12.5)
    }

    @Test func detectsDuplicates() throws {
        let container = try makeContainer()
        _ = container
        let existing = [Expense(store: "REWE", amount: 23.5, date: utcDate(2026, 10, 3, 8))]
        let same = DraftExpense(parsed: ParsedExpense(store: "rewe", amount: 23.5, category: "groceries", date: "2026-10-03", time: "20:00", note: nil),
                                source: .receipt, fallbackDate: fallback, calendar: utc)
        let other = DraftExpense(parsed: ParsedExpense(store: "rewe", amount: 24.0, category: "groceries", date: "2026-10-03", time: nil, note: nil),
                                 source: .receipt, fallbackDate: fallback, calendar: utc)
        #expect(DuplicateDetector.isDuplicate(same, in: existing, calendar: utc))
        #expect(!DuplicateDetector.isDuplicate(other, in: existing, calendar: utc))
    }
}

// MARK: - Images

@MainActor
struct ImageEncodingTests {
    @Test func downscalesLargePhotos() throws {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let big = UIGraphicsImageRenderer(size: CGSize(width: 4000, height: 2000), format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4000, height: 2000))
        }
        let data = try #require(ImportController.jpegData(from: big, maxDimension: 1000))
        let decoded = try #require(UIImage(data: data))
        #expect(max(decoded.size.width * decoded.scale, decoded.size.height * decoded.scale) <= 1000)
    }
}


// MARK: - Income & balance

@MainActor
struct IncomeTests {
    @Test func separatesSpendingAndIncome() throws {
        let container = try makeContainer()
        _ = container
        let entries = [
            Expense(store: "Rewe", amount: 40, category: .groceries, date: utcDate(2026, 10, 2)),
            Expense(store: "Employer", amount: 2000, category: .salary, date: utcDate(2026, 10, 1), isIncome: true),
            Expense(store: "Miete", amount: 700, category: .housing, date: utcDate(2026, 10, 3))
        ]
        #expect(ExpenseStats.spending(entries) == 740)
        #expect(ExpenseStats.income(entries) == 2000)
        #expect(ExpenseStats.net(entries) == 1260)
        #expect(ExpenseStats.byCategory(entries).allSatisfy { !$0.category.isIncome })
        #expect(ExpenseStats.balance(starting: 100, entries: entries, upTo: utcDate(2026, 10, 2, 23)) == 2060)
        #expect(ExpenseStats.balance(starting: 100, entries: entries, upTo: utcDate(2026, 12, 1)) == 1360)
    }

    @Test func incomeCategoriesAreSeparate() {
        #expect(ExpenseCategory.incomeCases.allSatisfy { $0.isIncome })
        #expect(ExpenseCategory.expenseCases.allSatisfy { !$0.isIncome })
        #expect(ExpenseCategory.parse("salary") == .salary)
        #expect(ExpenseCategory.parse("otherIncome") == .otherIncome)
    }

    @Test func aiIncomeTypeIsRespected() {
        let parsed = ParsedExpense(store: "Arbeitgeber GmbH", amount: 2100, category: "salary", date: "2026-10-01", time: nil, note: nil, type: "income")
        let draft = DraftExpense(parsed: parsed, source: .statement, fallbackDate: utcDate(2026, 10, 4), calendar: utc)
        #expect(draft.isIncome)
        let expenseByType = ParsedExpense(store: "x", amount: 1, category: "other", date: nil, time: nil, note: nil, type: "income")
        #expect(expenseByType.isIncome)
        let plain = ParsedExpense(store: "x", amount: 1, category: "food", date: nil, time: nil, note: nil, type: nil)
        #expect(!plain.isIncome)
    }
}

// MARK: - Budgets

@MainActor
struct BudgetTests {
    @Test func levels() {
        #expect(BudgetCalculator.level(spent: 50, limit: 100) == .ok)
        #expect(BudgetCalculator.level(spent: 80, limit: 100) == .warning)
        #expect(BudgetCalculator.level(spent: 100, limit: 100) == .warning)
        #expect(BudgetCalculator.level(spent: 100.01, limit: 100) == .over)
        #expect(BudgetCalculator.level(spent: 500, limit: 0) == .ok)
    }

    @Test func crossingIsReportedOnlyOnce() {
        #expect(BudgetCalculator.crossedLevel(before: 70, after: 85, limit: 100) == .warning)
        #expect(BudgetCalculator.crossedLevel(before: 85, after: 90, limit: 100) == nil)
        #expect(BudgetCalculator.crossedLevel(before: 90, after: 120, limit: 100) == .over)
        #expect(BudgetCalculator.crossedLevel(before: 10, after: 20, limit: 100) == nil)
    }

    @Test func statusesUseOnlyThatMonthsSpending() throws {
        let container = try makeContainer()
        _ = container
        let budgets = [CategoryBudget(category: .groceries, monthlyLimit: 300), CategoryBudget(category: .food, monthlyLimit: 0)]
        let entries = [
            Expense(store: "Rewe", amount: 120, category: .groceries, date: utcDate(2026, 10, 2)),
            Expense(store: "Lidl", amount: 150, category: .groceries, date: utcDate(2026, 10, 9)),
            Expense(store: "Rewe", amount: 999, category: .groceries, date: utcDate(2026, 9, 30)),
            Expense(store: "Refund", amount: 50, category: .refund, date: utcDate(2026, 10, 3), isIncome: true)
        ]
        let october = DateInterval(start: utcDate(2026, 10, 1), end: utcDate(2026, 11, 1))
        let statuses = BudgetCalculator.statuses(budgets: budgets, entries: entries, in: october)
        #expect(statuses.count == 1)
        #expect(statuses[0].spent == 270)
        #expect(statuses[0].remaining == 30)
        #expect(statuses[0].level == .warning)
    }
}

// MARK: - Recurring payments

@MainActor
struct RecurringTests {
    @Test func catchesUpMonthlyAndClampsShortMonths() {
        let dates = RecurringScheduler.dueDates(
            start: utcDate(2026, 1, 15), dayOfMonth: 31, lastGenerated: nil,
            now: utcDate(2026, 4, 10), calendar: utc
        )
        #expect(dates == [utcDate(2026, 1, 31, 9), utcDate(2026, 2, 28, 9), utcDate(2026, 3, 31, 9)])
    }

    @Test func skipsAlreadyGeneratedAndDaysBeforeStart() {
        let dates = RecurringScheduler.dueDates(
            start: utcDate(2026, 3, 10), dayOfMonth: 1, lastGenerated: utcDate(2026, 4, 1, 9),
            now: utcDate(2026, 6, 2), calendar: utc
        )
        #expect(dates == [utcDate(2026, 5, 1, 9), utcDate(2026, 6, 1, 9)])
    }

    @Test func futureStartCreatesNothing() {
        #expect(RecurringScheduler.dueDates(start: utcDate(2027, 1, 1), dayOfMonth: 5, lastGenerated: nil, now: utcDate(2026, 10, 5), calendar: utc).isEmpty)
    }

    @Test func catchUpIsCapped() {
        let dates = RecurringScheduler.dueDates(start: utcDate(2015, 1, 1), dayOfMonth: 1, lastGenerated: nil, now: utcDate(2026, 10, 5), calendar: utc)
        #expect(dates.count <= RecurringScheduler.maxCatchUpMonths)
    }

    @Test func runCreatesEntriesOnceAndIsIdempotent() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let payment = RecurringPayment(name: "Miete", amount: 700, category: .housing, dayOfMonth: 1, startDate: utcDate(2026, 8, 1))
        context.insert(payment)
        let now = utcDate(2026, 10, 5)
        #expect(RecurringScheduler.run(in: context, now: now, calendar: utc) == 3)
        #expect(RecurringScheduler.run(in: context, now: now, calendar: utc) == 0)
        let entries = try context.fetch(FetchDescriptor<Expense>())
        #expect(entries.count == 3)
        #expect(entries.allSatisfy { $0.source == .recurring && !$0.isIncome })
    }
}

// MARK: - Widget snapshot

@MainActor
struct WidgetSnapshotTests {
    @Test func summarisesTodayMonthAndBalance() throws {
        let container = try makeContainer()
        _ = container
        let now = utcDate(2026, 10, 5, 15)
        let entries = [
            Expense(store: "Bäcker", amount: 4, category: .food, date: utcDate(2026, 10, 5, 8)),
            Expense(store: "Rewe", amount: 30, category: .groceries, date: utcDate(2026, 10, 2, 8)),
            Expense(store: "Gehalt", amount: 1000, category: .salary, date: utcDate(2026, 10, 1, 8), isIncome: true),
            Expense(store: "Alt", amount: 50, category: .other, date: utcDate(2026, 9, 20, 8))
        ]
        let snapshot = WidgetBridge.makeSnapshot(
            entries: entries,
            budgets: [CategoryBudget(category: .food, monthlyLimit: 200)],
            startingBalance: 10,
            now: now,
            calendar: utc
        )
        #expect(snapshot.todaySpent == 4)
        #expect(snapshot.monthSpent == 34)
        #expect(snapshot.monthIncome == 1000)
        #expect(snapshot.balance == 926)
        #expect(snapshot.budgetLimit == 200)
    }
}

// MARK: - Backup

@MainActor
struct BackupTests {
    @Test func roundTripRestoresEverything() throws {
        let container = try makeContainer()
        let context = container.mainContext
        context.insert(Expense(store: "REWE", amount: 23.5, category: .groceries, date: utcDate(2026, 10, 3, 18), note: "Wocheneinkauf"))
        context.insert(Expense(store: "Gehalt", amount: 2450, category: .salary, date: utcDate(2026, 10, 1, 9), source: .recurring, isIncome: true))
        context.insert(CategoryBudget(category: .groceries, monthlyLimit: 250))
        let rent = RecurringPayment(name: "Miete", amount: 720, category: .housing, dayOfMonth: 1, startDate: utcDate(2026, 1, 1))
        rent.lastGenerated = utcDate(2026, 10, 1, 9)
        context.insert(rent)
        try context.save()

        let backup = BackupService.makeBackup(
            entries: try context.fetch(FetchDescriptor<Expense>()),
            budgets: try context.fetch(FetchDescriptor<CategoryBudget>()),
            recurring: try context.fetch(FetchDescriptor<RecurringPayment>()),
            startingBalance: 150,
            now: utcDate(2026, 10, 5)
        )
        let data = try BackupService.encode(backup)
        let decoded = try BackupService.decode(data)
        #expect(decoded == backup)

        let other = try makeContainer()
        let summary = try BackupService.restore(decoded, into: other.mainContext)
        #expect(summary == RestoreSummary(entries: 2, budgets: 1, recurring: 1))
        let restored = try other.mainContext.fetch(FetchDescriptor<Expense>())
        #expect(restored.count == 2)
        #expect(restored.contains { $0.store == "Gehalt" && $0.isIncome && $0.source == .recurring })
        let payments = try other.mainContext.fetch(FetchDescriptor<RecurringPayment>())
        #expect(payments.first?.lastGenerated == utcDate(2026, 10, 1, 9))
    }

    @Test func rejectsForeignFiles() {
        #expect(throws: BackupError.notABackup) { try BackupService.decode(Data("{\"hello\":1}".utf8)) }
        #expect(throws: BackupError.notABackup) { try BackupService.decode(Data("not json".utf8)) }
    }

    @Test func rejectsNewerVersions() throws {
        var backup = BackupFile(exportedAt: utcDate(2026, 10, 5), startingBalance: 0, entries: [], budgets: [], recurring: [])
        backup.version = BackupFile.currentVersion + 1
        let data = try BackupService.encode(backup)
        #expect(throws: BackupError.newerVersion) { try BackupService.decode(data) }
    }

    @Test func restoreSkipsInvalidAmounts() throws {
        let container = try makeContainer()
        let backup = BackupFile(
            exportedAt: utcDate(2026, 10, 5),
            startingBalance: 0,
            entries: [
                .init(store: "ok", amount: 5, category: "food", date: utcDate(2026, 10, 1), note: "", source: "manual", isIncome: false),
                .init(store: "bad", amount: -5, category: "food", date: utcDate(2026, 10, 1), note: "", source: "manual", isIncome: false)
            ],
            budgets: [],
            recurring: []
        )
        let summary = try BackupService.restore(backup, into: container.mainContext)
        #expect(summary.entries == 1)
    }
}

// MARK: - Reminders & deep links

@MainActor
struct ReminderTests {
    @Test func remindsAtSixTheEveningBefore() {
        let dates = NotificationScheduler.reminderDates(start: utcDate(2026, 1, 1), dayOfMonth: 15, now: utcDate(2026, 10, 5, 12), calendar: utc)
        #expect(dates.first == utcDate(2026, 10, 14, 18))
        #expect(dates.count == 2)
    }

    @Test func noReminderForTheDayThatAlreadyPassed() {
        let dates = NotificationScheduler.reminderDates(start: utcDate(2026, 1, 1), dayOfMonth: 6, now: utcDate(2026, 10, 5, 19), calendar: utc)
        #expect(dates.first == utcDate(2026, 11, 5, 18))
    }

    @Test func deepLinks() {
        let router = AppRouter()
        #expect(router.handle(URL(string: "phinanz://add")!))
        #expect(router.pendingAction == .newEntry)
        #expect(router.handle(URL(string: "phinanz://today")!))
        #expect(router.pendingAction == .showToday)
        #expect(!router.handle(URL(string: "https://example.com")!))
        #expect(!router.handle(URL(string: "phinanz://unknown")!))
    }
}

// MARK: - Category suggestions

@MainActor
struct CategorySuggesterTests {
    @Test(arguments: [
        ("REWE City", ExpenseCategory.groceries), ("Lidl", .groceries), ("Bäckerei Schmidt", .food),
        ("RMV Monatskarte", .transport), ("DB Fernverkehr", .transport), ("Netflix", .entertainment),
        ("dm-drogerie markt", .health), ("Amazon.de", .shopping), ("Apple iCloud+", .software),
        ("Lufthansa", .travel), ("Gehalt Oktober", .salary)
    ])
    func knowsCommonGermanMerchants(store: String, expected: ExpenseCategory) {
        #expect(CategorySuggester.suggest(for: store) == expected)
    }

    @Test func unknownStoresGetNoSuggestion() {
        #expect(CategorySuggester.suggest(for: "Blumen Meier") == nil)
        #expect(CategorySuggester.suggest(for: "x") == nil)
    }

    @Test func yourHistoryWins() throws {
        let container = try makeContainer()
        _ = container
        let history = [
            Expense(store: "REWE", amount: 5, category: .food, date: utcDate(2026, 10, 1)),
            Expense(store: "Blumen Meier", amount: 12, category: .shopping, date: utcDate(2026, 9, 1)),
            Expense(store: "Blumen Meier", amount: 12, category: .other, date: utcDate(2026, 10, 2))
        ]
        #expect(CategorySuggester.suggest(for: "rewe", history: history) == .food)
        #expect(CategorySuggester.suggest(for: "Blumen Meier", history: history) == .other)
    }
}

// MARK: - Bank CSV import

@MainActor
struct BankCSVImporterTests {
    @Test func readsSparkasseCAMTExport() throws {
        let csv = """
        "Auftragskonto";"Buchungstag";"Valutadatum";"Buchungstext";"Verwendungszweck";"Beguenstigter/Zahlungspflichtiger";"Kontonummer/IBAN";"BIC (SWIFT-Code)";"Betrag";"Waehrung";"Info"
        "DE001";"02.10.26";"02.10.26";"KARTENZAHLUNG";"REWE SAGT DANKE 1234";"REWE Markt GmbH";"DE02";"BIC";"-23,45";"EUR";"Umsatz gebucht"
        "DE001";"01.10.26";"01.10.26";"GUTSCHR. UEBERWEISUNG";"Gehalt Oktober";"Arbeitgeber GmbH";"DE03";"BIC";"2.450,00";"EUR";"Umsatz gebucht"
        "DE001";"03.10.26";"03.10.26";"LASTSCHRIFT";"Vorgemerkt";"Netflix";"DE04";"BIC";"-12,99";"EUR";"Umsatz vorgemerkt"
        """
        let bookings = try BankCSVImporter.bookings(in: csv, calendar: utc)
        #expect(bookings.count == 2) // pending booking skipped
        #expect(bookings[0] == .init(date: utcDate(2026, 10, 2), amount: -23.45, counterparty: "REWE Markt GmbH", purpose: "REWE SAGT DANKE 1234"))
        #expect(bookings[1].amount == 2450)

        let drafts = BankCSVImporter.drafts(from: bookings, calendar: utc)
        #expect(drafts[0].category == .groceries)
        #expect(drafts[0].isIncome == false)
        #expect(drafts[0].amount == 23.45)
        #expect(drafts[0].source == .statement)
        #expect(drafts[1].category == .salary)
        #expect(drafts[1].isIncome)
    }

    @Test func readsINGExportWithPreamble() throws {
        let csv = "Umsatzanzeige;Datei erstellt am: 05.10.2026 10:00\r\n\r\nIBAN;DE12 3456\r\nKontoname;Girokonto\r\n\r\n"
            + "Buchung;Wertstellungsdatum;Auftraggeber/Empfänger;Buchungstext;Verwendungszweck;Saldo;Währung;Betrag;Währung\r\n"
            + "30.09.2026;30.09.2026;Vodafone GmbH;Lastschrift;Rechnung 0926;1.234,56;EUR;-39,99;EUR\r\n"
        let bookings = try BankCSVImporter.bookings(in: csv, calendar: utc)
        #expect(bookings.count == 1)
        #expect(bookings[0].amount == -39.99)
        #expect(bookings[0].counterparty == "Vodafone GmbH")
        #expect(bookings[0].date == utcDate(2026, 9, 30))
    }

    @Test func readsDKBExportAndPicksPayeeBySign() throws {
        let csv = """
        "Girokonto";"DE00 1234"
        "Kontostand vom 05.10.2026:";"1.000,00 €"

        "Buchungsdatum";"Wertstellung";"Status";"Zahlungspflichtige*r";"Zahlungsempfänger*in";"Verwendungszweck";"Umsatztyp";"IBAN";"Betrag (€)"
        "04.10.26";"04.10.26";"Gebucht";"Farhan";"Deutsche Bahn";"Ticket";"Ausgang";"DE1";"-29,9"
        "03.10.26";"03.10.26";"Gebucht";"Mama";"Farhan";"Geschenk";"Eingang";"DE2";"50"
        """
        let bookings = try BankCSVImporter.bookings(in: csv, calendar: utc)
        #expect(bookings.map { $0.counterparty } == ["Deutsche Bahn", "Mama"])
        #expect(bookings.map { $0.amount } == [-29.9, 50])
        #expect(BankCSVImporter.drafts(from: bookings, calendar: utc)[0].category == .transport)
    }

    @Test func readsN26CommaSeparatedExport() throws {
        let csv = """
        "Booking Date","Value Date","Partner Name","Partner Iban",Type,"Payment Reference","Account Name","Amount (EUR)","Original Amount","Original Currency","Exchange Rate"
        2026-10-01,2026-10-01,"Spotify AB",,Presentment,"Premium, October",Main,-10.99,,,
        """
        let bookings = try BankCSVImporter.bookings(in: csv, calendar: utc)
        #expect(bookings.count == 1)
        #expect(bookings[0].amount == -10.99)
        #expect(bookings[0].purpose == "Premium, October")
        #expect(BankCSVImporter.drafts(from: bookings, calendar: utc)[0].category == .entertainment)
    }

    @Test func usesPurposeWhenThereIsNoCounterpartyColumn() throws {
        let csv = """
        Buchungstag;Wertstellung;Umsatzart;Buchungstext;Betrag;Währung
        02.10.2026;02.10.2026;Lastschrift;Miete Oktober Wohnung;-720,00;EUR
        """
        let bookings = try BankCSVImporter.bookings(in: csv, calendar: utc)
        let draft = try #require(BankCSVImporter.drafts(from: bookings, calendar: utc).first)
        #expect(draft.store == "Miete Oktober Wohnung")
        #expect(draft.category == .housing)
    }

    @Test func handlesSollHabenColumns() throws {
        let csv = """
        Buchungstag;Empfänger;Verwendungszweck;Soll;Haben
        01.10.2026;Stadtwerke;Strom;45,00;
        02.10.2026;Finanzamt;Erstattung;;120,50
        """
        let bookings = try BankCSVImporter.bookings(in: csv, calendar: utc)
        #expect(bookings.map { $0.amount } == [-45, 120.5])
    }

    @Test func rejectsFilesThatAreNotBankExports() {
        #expect(throws: BankCSVImporter.ImportError.unknownLayout) {
            try BankCSVImporter.bookings(in: "name;age;city\nAnna;30;Berlin", calendar: utc)
        }
        #expect(throws: BankCSVImporter.ImportError.noBookings) {
            try BankCSVImporter.bookings(in: "Buchungstag;Empfänger;Betrag\n", calendar: utc)
        }
    }

    @Test func decodesWindows1252() throws {
        let data = try #require("Buchungstag;Empfänger;Betrag\n01.10.2026;Bäckerei Müller;-3,20\n".data(using: .windowsCP1252))
        let bookings = try BankCSVImporter.bookings(in: data, calendar: utc)
        #expect(bookings.first?.counterparty == "Bäckerei Müller")
    }

    @Test(arguments: [
        ("-1.234,56", -1234.56), ("1234.56", 1234.56), ("+12,50 €", 12.5), ("12,50-", -12.5), ("−9,99", -9.99)
    ])
    func parsesSignedAmounts(text: String, expected: Double) {
        #expect(BankCSVImporter.parseAmount(text) == expected)
    }

    @Test func parsesQuotedFieldsAndLineEndings() {
        let rows = BankCSVImporter.rows(in: "a;\"b;c\";\"say \"\"hi\"\"\"\r\nd;e;f\rg;h;i", delimiter: ";")
        #expect(rows == [["a", "b;c", "say \"hi\""], ["d", "e", "f"], ["g", "h", "i"]])
    }
}
