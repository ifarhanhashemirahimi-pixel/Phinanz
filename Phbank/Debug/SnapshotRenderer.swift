//
//  SnapshotRenderer.swift
//  Phbank
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

    private static var candidateDirectories: [URL] {
        guard let home = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"] else { return [] }
        let base = URL(fileURLWithPath: home)
        return [
            base.appendingPathComponent("Desktop/Phbank/snapshots"),
            base.appendingPathComponent("code/phinanz-snapshots")
        ]
    }

    @MainActor
    static func runIfRequested() async {
        guard !AppEnvironment.isUITest,
              let directory = candidateDirectories.first(where: {
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

        var log = "Started \(Date())\n"
        let logURL = directory.appendingPathComponent("log.txt")
        for scenario in scenarios(container: container) {
            log += "\(scenario.name): rendering…\n"
            try? log.write(to: logURL, atomically: true, encoding: .utf8)
            let result = await render(scenario, in: scene, container: container, to: directory)
            log += "\(scenario.name): \(result)\n"
            try? log.write(to: logURL, atomically: true, encoding: .utf8)
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
            Scenario(name: "17-journal-fa", style: .light, locale: "fa", view: AnyView(ContentView(initialTab: .journal, previewMode: true))),
            Scenario(name: "18-summary-de", style: .light, locale: "de", view: AnyView(ContentView(initialTab: .summary, previewMode: true))),
            Scenario(name: "19-plan-fa-dark", style: .dark, locale: "fa", view: AnyView(ContentView(initialTab: .plan, previewMode: true))),
            Scenario(name: "20-journal-empty-day", style: .light, locale: nil, view: AnyView(ContentView(initialTab: .journal, initialDate: Calendar.current.date(byAdding: .day, value: 3, to: Date()), previewMode: true))),
            Scenario(name: "21-journal-income-day-dark", style: .dark, locale: nil, view: AnyView(ContentView(initialTab: .journal, initialDate: Calendar.current.date(byAdding: .day, value: -4, to: Date()), previewMode: true)))
        ]
        if let sampleEntry {
            list.append(Scenario(name: "08-editor-edit-dark", style: .dark, locale: nil, view: AnyView(ExpenseEditorView(expense: sampleEntry, defaultDate: sampleEntry.date))))
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
        let bounds = scene.coordinateSpace.bounds
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
