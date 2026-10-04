//
//  ContentView.swift
//  Phbank
//
//  Root of the app: a standard tab bar (Liquid Glass on iOS 26) with
//  Journal, Summary, Plan and Search.
//

import SwiftUI
import SwiftData

enum AppTab: Hashable {
    case journal, summary, plan, search
}

enum ActiveSheet: Identifiable {
    case settings, voice, scan
    case add(Date)
    case edit(Expense)

    var id: String {
        switch self {
        case .settings: "settings"
        case .voice: "voice"
        case .scan: "scan"
        case .add(let day): "add-\(day.timeIntervalSince1970)"
        case .edit(let expense): "edit-\(ObjectIdentifier(expense).hashValue)"
        }
    }
}

struct ContentView: View {
    @Environment(AppLock.self) private var lock: AppLock?
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Expense.date) private var expenses: [Expense]
    @Query private var budgets: [CategoryBudget]
    @AppStorage(SettingsKeys.startingBalance) private var startingBalance = 0.0
    @AppStorage(SettingsKeys.didOnboard) private var didOnboard = false

    @State private var selectedTab: AppTab
    @State private var journalDate = Calendar.current.startOfDay(for: Date())
    @State private var activeSheet: ActiveSheet?
    @State private var importer = ImportController()
    @State private var showOnboarding = false
    @State private var router = AppRouter.shared

    private let calendar = Calendar.current
    /// Previews and debug screenshots: no onboarding, scheduler or widget updates.
    private let previewMode: Bool

    init(initialTab: AppTab = .journal, initialDate: Date? = nil, previewMode: Bool = false) {
        _selectedTab = State(initialValue: initialTab)
        _journalDate = State(initialValue: Calendar.current.startOfDay(for: initialDate ?? Date()))
        self.previewMode = previewMode
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Journal", systemImage: "book.pages", value: AppTab.journal) {
                JournalView(expenses: expenses, selectedDate: $journalDate, activeSheet: $activeSheet)
            }
            Tab("Summary", systemImage: "chart.pie", value: AppTab.summary) {
                SummaryView(expenses: expenses, activeSheet: $activeSheet)
            }
            Tab("Plan", systemImage: "calendar.badge.clock", value: AppTab.plan) {
                PlanView(expenses: expenses, activeSheet: $activeSheet)
            }
            Tab("Search", systemImage: "magnifyingglass", value: AppTab.search, role: .search) {
                SearchView(expenses: expenses, activeSheet: $activeSheet)
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabBarMinimizeBehavior(.onScrollDown)
        .overlay {
            if importer.phase == .processing {
                AnalysingHUD()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: importer.phase)
        .sheet(item: $activeSheet, content: sheetContent)
        .sheet(isPresented: $importer.showReview) {
            ReviewDraftsView(importer: importer) { date in
                journalDate = calendar.startOfDay(for: date)
                selectedTab = .journal
            }
        }
        .alert("Couldn't Analyse", isPresented: failureBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importer.failureMessage)
        }
        .onChange(of: lock?.isLocked ?? false) { _, locked in
            // Sheets float above the lock screen, so close them when the app locks.
            if locked {
                activeSheet = nil
                importer.showReview = false
            }
        }
        .task {
            guard !previewMode else { return }
            RecurringScheduler.run(in: context)
            if !didOnboard && !AppEnvironment.isUITest { showOnboarding = true }
        }
        .task(id: widgetKey) {
            guard !previewMode else { return }
            WidgetBridge.publish(WidgetBridge.makeSnapshot(
                entries: expenses,
                budgets: budgets,
                startingBalance: startingBalance
            ))
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && !previewMode {
                RecurringScheduler.run(in: context)
                Task { await NotificationScheduler.refresh(context: context) }
            }
        }
        .onOpenURL { url in
            router.handle(url)
        }
        .onChange(of: router.pendingAction, initial: true) { _, action in
            guard let action, !previewMode else { return }
            router.pendingAction = nil
            let today = calendar.startOfDay(for: Date())
            switch action {
            case .newEntry:
                selectedTab = .journal
                journalDate = today
                activeSheet = .add(YearCalendar.entryDate(on: today, calendar: calendar))
            case .showToday:
                selectedTab = .journal
                journalDate = today
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView {
                didOnboard = true
                showOnboarding = false
            }
        }
    }

    /// Changes whenever the numbers shown in the widget could change.
    private var widgetKey: String {
        let day = calendar.startOfDay(for: Date()).timeIntervalSince1970
        return "\(expenses.count)|\(ExpenseStats.net(expenses))|\(ExpenseStats.total(expenses))|\(budgets.count)|\(startingBalance)|\(day)"
    }

    private var failureBinding: Binding<Bool> {
        Binding(
            get: { if case .failed = importer.phase { true } else { false } },
            set: { if !$0 { importer.dismissError() } }
        )
    }

    private var importFallbackDate: Date {
        YearCalendar.entryDate(on: journalDate, calendar: calendar)
    }

    @ViewBuilder
    private func sheetContent(_ sheet: ActiveSheet) -> some View {
        switch sheet {
        case .settings:
            SettingsView(expenses: expenses, year: calendar.component(.year, from: journalDate))
        case .voice:
            VoiceInputView(importer: importer, fallbackDate: importFallbackDate)
        case .scan:
            ScanImportView(importer: importer, fallbackDate: importFallbackDate)
        case .add(let day):
            ExpenseEditorView(expense: nil, defaultDate: day)
        case .edit(let expense):
            ExpenseEditorView(expense: expense, defaultDate: expense.date)
        }
    }
}

/// Toolbar button that opens Settings, shared by the tabs.
struct SettingsToolbarButton: View {
    @Binding var activeSheet: ActiveSheet?

    var body: some View {
        Button {
            activeSheet = .settings
        } label: {
            Label("Settings", systemImage: "gearshape")
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Schema(AppSchema.models),
        configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    )
    SampleData.seedShowcase(into: container.mainContext)
    return ContentView(previewMode: true).modelContainer(container)
}
