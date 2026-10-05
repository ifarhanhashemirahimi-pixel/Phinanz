//
//  SnapshotRenderer.swift
//  Phinanz
//
//  DEBUG-only design QA helper. When the file `snapshots/REQUEST` exists in the
//  project folder on the Mac, the app (running in the simulator) draws every
//  main screen into PNG files next to it, in light/dark and German/Persian.
//  Delete REQUEST to turn it off. Never compiled into release builds.
//

#if DEBUG
import SwiftUI
import SwiftData
import UIKit

enum SnapshotRenderer {
    private struct Scenario {
        let name: String
        let style: UIUserInterfaceStyle
        let locale: String?
        let view: AnyView
    }

    private static var candidateDirectories: [URL] { DebugFlags.directories }

    @MainActor
    static func runIfRequested() async {
        guard !AppEnvironment.isUITest, !DebugFlags.isTesting,
              let root = candidateDirectories.first(where: {
                  FileManager.default.fileExists(atPath: $0.appendingPathComponent("REQUEST").path)
              }),
              let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
        else { return }

        try? await Task.sleep(for: .seconds(1)) // let the real UI settle first

        let container: ModelContainer
        do {
            container = try ModelContainer(
                for: Schema(AppSchema.models),
                configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            )
        } catch {
            return
        }
        SampleData.seedShowcase(into: container.mainContext)

        // One folder per app language, e.g. snapshots/de.
        let language = Locale.current.language.languageCode?.identifier ?? "xx"
        let directory = root.appendingPathComponent(language)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        var log = "Started \(Date()) language \(language)\n"
        let logURL = root.appendingPathComponent("log.txt")
        for scenario in scenarios(container: container) {
            log += "\(scenario.name): rendering…\n"
            try? log.write(to: logURL, atomically: true, encoding: .utf8)
            let result = await render(scenario, in: scene, container: container, to: directory)
            log += "\(scenario.name): \(result)\n"
            try? log.write(to: logURL, atomically: true, encoding: .utf8)
        }
        // A sample PDF report, to check the layout.
        let entries = (try? container.mainContext.fetch(FetchDescriptor<Expense>())) ?? []
        let budgets = (try? container.mainContext.fetch(FetchDescriptor<CategoryBudget>())) ?? []
        let lastMonth = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        if let pdf = try? ReportPDF.write(ReportBuilder.build(month: lastMonth, entries: entries, budgets: budgets)) {
            let target = directory.appendingPathComponent("report.pdf")
            try? FileManager.default.removeItem(at: target)
            try? FileManager.default.copyItem(at: pdf, to: target)
            log += "report.pdf: ok\n"
        }
        log += "Finished \(Date())\n"
        try? log.write(to: logURL, atomically: true, encoding: .utf8)
    }

    @MainActor
    private static func scenarios(container: ModelContainer) -> [Scenario] {
        let context = container.mainContext
        let entries = (try? context.fetch(FetchDescriptor<Expense>(sortBy: [SortDescriptor(\.date)]))) ?? []
        let sampleEntry = entries.last { !$0.isIncome } ?? entries.first
        let year = Calendar.current.component(.year, from: Date())

        let reviewImporter = ImportController()
        reviewImporter.drafts = [
            DraftExpense(parsed: ParsedExpense(store: "REWE", amount: 23.47, category: "groceries", date: nil, time: "18:20", note: nil, type: "expense"), source: .receipt, fallbackDate: Date()),
            DraftExpense(parsed: ParsedExpense(store: "Arbeitgeber GmbH", amount: 2450, category: "salary", date: nil, time: nil, note: nil, type: "income"), source: .statement, fallbackDate: Date())
        ]

        let bankImporter = ImportController()
        bankImporter.origin = .bankFile
        let sampleCSV = """
        Buchungstag;Beguenstigter/Zahlungspflichtiger;Verwendungszweck;Betrag
        01.10.2026;Arbeitgeber GmbH;Gehalt Oktober;2.450,00
        01.10.2026;Hausverwaltung Kraus;Miete Oktober;-720,00
        02.10.2026;REWE Markt GmbH;REWE SAGT DANKE;-23,45
        02.10.2026;Netflix International;Abo;-13,99
        03.10.2026;PayPal Europe;Ihr Einkauf bei Blumen Meier;-18,00
        04.10.2026;Deutsche Bahn;Ticket Frankfurt-Darmstadt;-9,80
        """
        bankImporter.drafts = BankCSVImporter.drafts(from: (try? BankCSVImporter.bookings(in: sampleCSV)) ?? [])

        var list: [Scenario] = [
            Scenario(name: "01-journal-light", style: .light, locale: nil, view: AnyView(ContentView(initialTab: .journal, previewMode: true))),
            Scenario(name: "02-journal-dark", style: .dark, locale: nil, view: AnyView(ContentView(initialTab: .journal, previewMode: true))),
            Scenario(name: "03-summary-light", style: .light, locale: nil, view: AnyView(ContentView(initialTab: .summary, previewMode: true))),
            Scenario(name: "04-summary-dark", style: .dark, locale: nil, view: AnyView(ContentView(initialTab: .summary, previewMode: true))),
            Scenario(name: "05-plan-light", style: .light, locale: nil, view: AnyView(ContentView(initialTab: .plan, previewMode: true))),
            Scenario(name: "06-search-light", style: .light, locale: nil, view: AnyView(ContentView(initialTab: .search, previewMode: true))),
            Scenario(name: "07-editor-new-light", style: .light, locale: nil, view: AnyView(ExpenseEditorView(expense: nil, defaultDate: Date()))),
            Scenario(name: "09-settings-light", style: .light, locale: nil, view: AnyView(SettingsView(expenses: entries, year: year))),
            Scenario(name: "10-onboarding-light", style: .light, locale: nil, view: AnyView(OnboardingView {})),
            Scenario(name: "11-lock-dark", style: .dark, locale: nil, view: AnyView(LockScreenView(lock: AppLock(startLocked: true)))),
            Scenario(name: "12-voice-light", style: .light, locale: nil, view: AnyView(VoiceInputView(importer: ImportController(), fallbackDate: Date()))),
            Scenario(name: "13-scan-light", style: .light, locale: nil, view: AnyView(ScanImportView(importer: ImportController(), fallbackDate: Date()))),
            Scenario(name: "14-review-light", style: .light, locale: nil, view: AnyView(ReviewDraftsView(importer: reviewImporter) { _ in })),
            Scenario(name: "15-budgets-light", style: .light, locale: nil, view: AnyView(NavigationStack { BudgetsView() })),
            Scenario(name: "16-recurring-light", style: .light, locale: nil, view: AnyView(NavigationStack { RecurringListView() })),
            Scenario(name: "20-journal-empty-day", style: .light, locale: nil, view: AnyView(ContentView(initialTab: .journal, initialDate: Calendar.current.date(byAdding: .day, value: 3, to: Date()), previewMode: true))),
            Scenario(name: "22-review-bank-csv", style: .light, locale: nil, view: AnyView(ReviewDraftsView(importer: bankImporter) { _ in })),
            Scenario(name: "21-journal-income-day-dark", style: .dark, locale: nil, view: AnyView(ContentView(initialTab: .journal, initialDate: Calendar.current.date(byAdding: .day, value: -4, to: Date()), previewMode: true)))
        ]
        if let sampleEntry {
            list.append(Scenario(name: "08-editor-edit-dark", style: .dark, locale: nil, view: AnyView(ExpenseEditorView(expense: sampleEntry, defaultDate: sampleEntry.date))))
        }

        // Accounts, goals, report, security.
        let accounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        let goals = (try? context.fetch(FetchDescriptor<SavingsGoal>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        let budgets = (try? context.fetch(FetchDescriptor<CategoryBudget>())) ?? []
        let lastMonth = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        list += [
            Scenario(name: "23-plan-dark", style: .dark, locale: nil, view: AnyView(ContentView(initialTab: .plan, previewMode: true))),
            Scenario(name: "25-report-light", style: .light, locale: nil, view: AnyView(NavigationStack { MonthlyReportView(expenses: entries, budgets: budgets, month: lastMonth) })),
            Scenario(name: "26-report-dark", style: .dark, locale: nil, view: AnyView(NavigationStack { MonthlyReportView(expenses: entries, budgets: budgets, month: lastMonth) })),
            Scenario(name: "27-security", style: .light, locale: nil, view: AnyView(NavigationStack { SecurityOverviewView() })),
            Scenario(name: "28-accounts-list", style: .light, locale: nil, view: AnyView(NavigationStack { AccountsListView() })),
            Scenario(name: "30-backup-sheet", style: .light, locale: nil, view: AnyView(BackupSheet { _ in })),
            Scenario(name: "31-transfer", style: .light, locale: nil, view: AnyView(TransferEditorView())),
            Scenario(name: "32-goal-editor", style: .light, locale: nil, view: AnyView(GoalEditorView(goal: nil))),
            Scenario(name: "34-settings-dark", style: .dark, locale: nil, view: AnyView(SettingsView(expenses: entries, year: year)))
        ]
        if let goal = goals.first {
            list.append(Scenario(name: "24-goal-detail", style: .light, locale: nil, view: AnyView(NavigationStack { GoalDetailView(goal: goal) })))
            list.append(Scenario(name: "24b-goal-detail-dark", style: .dark, locale: nil, view: AnyView(NavigationStack { GoalDetailView(goal: goal) })))
        }
        list.append(Scenario(name: "35-analysing", style: .light, locale: nil, view: AnyView(ZStack { ContentView(initialTab: .journal, previewMode: true); AnalysingHUD() })))
        list.append(Scenario(name: "35b-analysing-dark", style: .dark, locale: nil, view: AnyView(ZStack { ContentView(initialTab: .journal, previewMode: true); AnalysingHUD() })))
        if let found = entries.last(where: { !$0.isIncome && Calendar.current.isDateInToday($0.date) }) ?? sampleEntry {
            list.append(Scenario(name: "36-search-jump-highlight", style: .light, locale: nil, view: AnyView(ContentView(initialTab: .journal, initialDate: found.date, initialHighlight: found.persistentModelID, previewMode: true))))
        }
        if let primary = AccountLedger.primary(accounts) {
            list.append(Scenario(name: "29-account-detail", style: .light, locale: nil, view: AnyView(NavigationStack { AccountDetailView(accountID: primary.id, expenses: entries) })))
        }
        return list
    }

    @MainActor
    private static func render(_ scenario: Scenario, in scene: UIWindowScene, container: ModelContainer, to directory: URL) async -> String {
        var root = AnyView(scenario.view.modelContainer(container))
        if let code = scenario.locale {
            let locale = Locale(identifier: code)
            let direction: LayoutDirection = Locale.Language(identifier: code).characterDirection == .rightToLeft ? .rightToLeft : .leftToRight
            root = AnyView(root.environment(\.locale, locale).environment(\.layoutDirection, direction))
        }

        let window = UIWindow(windowScene: scene)
        let bounds = scene.effectiveGeometry.coordinateSpace.bounds
        // Always render in portrait, even if the simulator is rotated.
        window.frame = CGRect(x: 0, y: 0, width: min(bounds.width, bounds.height), height: max(bounds.width, bounds.height))
        window.overrideUserInterfaceStyle = scenario.style
        window.windowLevel = .alert + 1
        window.rootViewController = UIHostingController(rootView: root)
        window.isHidden = false
        defer { window.isHidden = true }

        try? await Task.sleep(for: .milliseconds(1500))

        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        guard let data = image.pngData() else { return "no data" }
        do {
            try data.write(to: directory.appendingPathComponent("\(scenario.name).png"))
            return "ok"
        } catch {
            return "write failed: \(error.localizedDescription)"
        }
    }
}
#endif
