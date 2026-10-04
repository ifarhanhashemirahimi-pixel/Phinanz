//
//  ContentView.swift
//  Phbank
//
//  The journal: a lazily-built horizontal pager with one page per day of the year.
//

import SwiftUI
import SwiftData

enum ActiveSheet: Identifiable {
    case settings, search, voice, scan, summary
    case add(Date)
    case edit(Expense)

    var id: String {
        switch self {
        case .settings: "settings"
        case .search: "search"
        case .voice: "voice"
        case .scan: "scan"
        case .summary: "summary"
        case .add(let day): "add-\(day.timeIntervalSince1970)"
        case .edit(let expense): "edit-\(ObjectIdentifier(expense).hashValue)"
        }
    }
}

struct ContentView: View {
    @Environment(AppLock.self) private var lock: AppLock?
    @Query(sort: \Expense.date) private var expenses: [Expense]

    @State private var year = Calendar.current.component(.year, from: Date())
    @State private var selectedDayIndex: Int?
    @State private var activeSheet: ActiveSheet?
    @State private var importer = ImportController()

    private let calendar = Calendar.current

    var body: some View {
        let days = YearCalendar.days(in: year, calendar: calendar)
        let grouped = YearCalendar.groupByDay(expenses, calendar: calendar)

        ZStack(alignment: .bottom) {
            JournalTheme.shell.ignoresSafeArea()

            VStack(spacing: 0) {
                yearHeader
                pager(days: days, grouped: grouped)
            }

            LiquidGlassTabBar(
                onSettings: { activeSheet = .settings },
                onSearch: { activeSheet = .search },
                onVoice: { activeSheet = .voice },
                onScan: { activeSheet = .scan },
                onSummary: { activeSheet = .summary },
                onToday: { jump(to: Date()) }
            )

            if importer.phase == .processing {
                PHLoadingView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: importer.phase)
        .sheet(item: $activeSheet, content: sheetContent)
        .sheet(isPresented: $importer.showReview) {
            ReviewDraftsView(importer: importer) { jump(to: $0) }
        }
        .alert("Couldn't analyse", isPresented: failureBinding) {
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
            if selectedDayIndex == nil {
                selectedDayIndex = YearCalendar.index(of: Date(), in: year, calendar: calendar)
            }
        }
    }

    // MARK: Pager

    private func pager(days: [Date], grouped: [Date: [Expense]]) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    YearlyDayPageView(
                        date: day,
                        expenses: (grouped[day] ?? []).sorted { $0.date < $1.date },
                        isToday: calendar.isDateInToday(day),
                        onAdd: { activeSheet = .add(YearCalendar.entryDate(on: day, calendar: calendar)) },
                        onEdit: { activeSheet = .edit($0) }
                    )
                    .containerRelativeFrame(.horizontal)
                    .padding(.bottom, 84)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $selectedDayIndex)
    }

    private var yearHeader: some View {
        HStack(spacing: 18) {
            Button { changeYear(by: -1) } label: {
                Image(systemName: "chevron.left").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Previous year")

            Text(String(year))
                .font(JournalTheme.classicBold(18, relativeTo: .headline))
                .kerning(2)
                .accessibilityAddTraits(.isHeader)

            Button { changeYear(by: 1) } label: {
                Image(systemName: "chevron.right").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Next year")
        }
        .foregroundStyle(JournalTheme.gold)
        .frame(maxWidth: .infinity)
    }

    // MARK: Navigation helpers

    private func changeYear(by delta: Int) {
        year += delta
        let currentYear = calendar.component(.year, from: Date())
        selectedDayIndex = year == currentYear
            ? YearCalendar.index(of: Date(), in: year, calendar: calendar)
            : 0
    }

    private func jump(to date: Date) {
        let targetYear = calendar.component(.year, from: date)
        if targetYear != year { year = targetYear }
        let index = YearCalendar.index(of: date, in: targetYear, calendar: calendar)
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.4)) { selectedDayIndex = index }
        }
    }

    /// The day currently shown in the pager (today as a fallback).
    private var visibleDay: Date {
        if let index = selectedDayIndex,
           let day = YearCalendar.date(at: index, in: year, calendar: calendar) {
            return day
        }
        return calendar.startOfDay(for: Date())
    }

    private var failureBinding: Binding<Bool> {
        Binding(
            get: { if case .failed = importer.phase { true } else { false } },
            set: { if !$0 { importer.dismissError() } }
        )
    }

    @ViewBuilder
    private func sheetContent(_ sheet: ActiveSheet) -> some View {
        switch sheet {
        case .settings:
            SettingsView(expenses: expenses, year: year)
        case .search:
            SearchView(expenses: expenses) { jump(to: $0) }
        case .voice:
            VoiceInputView(importer: importer, fallbackDate: YearCalendar.entryDate(on: visibleDay, calendar: calendar))
        case .scan:
            ScanImportView(importer: importer, fallbackDate: YearCalendar.entryDate(on: visibleDay, calendar: calendar))
        case .summary:
            SummaryView(expenses: expenses, anchor: visibleDay)
        case .add(let day):
            ExpenseEditorView(expense: nil, defaultDate: day)
        case .edit(let expense):
            ExpenseEditorView(expense: expense, defaultDate: expense.date)
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Expense.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    )
    SampleData.seed(into: container.mainContext)
    return ContentView().modelContainer(container)
}
