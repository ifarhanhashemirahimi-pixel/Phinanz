//
//  JournalView.swift
//  Phbank
//
//  The journal tab: a week strip like Calendar and one page per day.
//  Swipe between days; every page lists that day's entries.
//

import SwiftUI
import SwiftData

struct JournalView: View {
    let expenses: [Expense]
    @Binding var selectedDate: Date
    @Binding var activeSheet: ActiveSheet?

    @State private var year: Int
    @State private var pageIndex: Int?
    @State private var showDatePicker = false

    private let calendar = Calendar.current

    init(expenses: [Expense], selectedDate: Binding<Date>, activeSheet: Binding<ActiveSheet?>) {
        self.expenses = expenses
        _selectedDate = selectedDate
        _activeSheet = activeSheet
        _year = State(initialValue: Calendar.current.component(.year, from: selectedDate.wrappedValue))
    }

    private var isShowingToday: Bool { calendar.isDateInToday(selectedDate) }

    var body: some View {
        let days = YearCalendar.days(in: year, calendar: calendar)
        let grouped = YearCalendar.groupByDay(expenses, calendar: calendar)

        NavigationStack {
            VStack(spacing: 0) {
                WeekStrip(selectedDate: selectedDate, markedDays: Set(grouped.keys)) { day in
                    selectedDate = calendar.startOfDay(for: day)
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 6)

                Divider()

                pager(days: days, grouped: grouped)
            }
            .background(Theme.groupedBackground)
            .navigationTitle(selectedDate.formatted(.dateTime.month(.wide).year()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarTitleMenu {
                Button {
                    selectedDate = calendar.startOfDay(for: Date())
                } label: {
                    Label("Today", systemImage: "calendar.circle")
                }
                Button {
                    showDatePicker = true
                } label: {
                    Label("Go to Date…", systemImage: "calendar")
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        activeSheet = .settings
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .accessibilityIdentifier("toolbar-settings")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            activeSheet = .voice
                        } label: {
                            Label("Voice Note", systemImage: "mic")
                        }
                        Button {
                            activeSheet = .scan
                        } label: {
                            Label("Receipt or Statement", systemImage: "doc.viewfinder")
                        }
                    } label: {
                        Label("Import with AI", systemImage: "sparkles")
                    }
                    .accessibilityIdentifier("toolbar-ai")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        activeSheet = .add(YearCalendar.entryDate(on: selectedDate, calendar: calendar))
                    } label: {
                        Label("Add Entry", systemImage: "plus")
                    }
                    .accessibilityIdentifier("toolbar-add")
                }
            }
            .overlay(alignment: .bottom) {
                if !isShowingToday {
                    Button("Today") {
                        selectedDate = calendar.startOfDay(for: Date())
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.snappy, value: isShowingToday)
            .sheet(isPresented: $showDatePicker) {
                DateJumpSheet(date: selectedDate) { picked in
                    selectedDate = calendar.startOfDay(for: picked)
                }
                .presentationDetents([.medium, .large])
            }
            .sensoryFeedback(.selection, trigger: selectedDate)
            .onChange(of: pageIndex) { _, newIndex in
                guard let newIndex,
                      let date = YearCalendar.date(at: newIndex, in: year, calendar: calendar),
                      !calendar.isDate(date, inSameDayAs: selectedDate)
                else { return }
                selectedDate = date
            }
            .onChange(of: selectedDate) { _, newDate in
                syncPager(to: newDate, animated: true)
            }
            .task {
                syncPager(to: selectedDate, animated: false)
            }
        }
    }

    // MARK: Pager

    private func pager(days: [Date], grouped: [Date: [Expense]]) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    DayPageView(
                        date: day,
                        entries: (grouped[day] ?? []).sorted { $0.date < $1.date },
                        onAdd: { activeSheet = .add(YearCalendar.entryDate(on: day, calendar: calendar)) },
                        onEdit: { activeSheet = .edit($0) }
                    )
                    .containerRelativeFrame([.horizontal, .vertical])
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $pageIndex)
    }

    private func syncPager(to date: Date, animated: Bool) {
        let targetYear = calendar.component(.year, from: date)
        let index = YearCalendar.index(of: date, in: targetYear, calendar: calendar)
        if targetYear != year {
            year = targetYear
            DispatchQueue.main.async { pageIndex = index }
            return
        }
        guard pageIndex != index else { return }
        if animated {
            withAnimation(.snappy) { pageIndex = index }
        } else {
            pageIndex = index
        }
    }
}

// MARK: - Week strip

struct WeekStrip: View {
    let selectedDate: Date
    let markedDays: Set<Date>
    var onSelect: (Date) -> Void

    @Environment(\.layoutDirection) private var layoutDirection
    private let calendar = Calendar.current

    private var days: [Date] {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: week.start) }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                dayButton(day)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 24).onEnded { value in
                let dx = layoutDirection == .rightToLeft ? -value.translation.width : value.translation.width
                if dx < -40 { shift(by: 7) } else if dx > 40 { shift(by: -7) }
            }
        )
    }

    private func dayButton(_ day: Date) -> some View {
        let selected = calendar.isDate(day, inSameDayAs: selectedDate)
        let today = calendar.isDateInToday(day)
        let marked = markedDays.contains(calendar.startOfDay(for: day))
        let numberColor: Color = selected ? Theme.background : (today ? Color.accentColor : Color.primary)
        let circleColor: Color = today ? Color.accentColor : Color.primary

        return Button {
            onSelect(day)
        } label: {
            VStack(spacing: 4) {
                Text(day.formatted(.dateTime.weekday(.narrow)))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(day.formatted(.dateTime.day()))
                    .font(.body.weight(selected || today ? .semibold : .regular))
                    .monospacedDigit()
                    .foregroundStyle(numberColor)
                    .frame(width: 36, height: 36)
                    .background {
                        if selected { Circle().fill(circleColor) }
                    }
                Circle()
                    .fill(marked ? Color.secondary : Color.clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(day.formatted(date: .complete, time: .omitted)))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func shift(by days: Int) {
        if let date = calendar.date(byAdding: .day, value: days, to: selectedDate) {
            onSelect(date)
        }
    }
}

// MARK: - Day page

struct DayPageView: View {
    @Environment(\.modelContext) private var context
    let date: Date
    let entries: [Expense]
    var onAdd: () -> Void
    var onEdit: (Expense) -> Void

    var body: some View {
        List {
            Section {
                DaySummaryHeader(date: date, entries: entries)
            }

            if entries.isEmpty {
                Section {
                    ContentUnavailableView {
                        Label("No Entries", systemImage: "tray")
                    } description: {
                        Text("Nothing written down for this day yet.")
                    } actions: {
                        Button("Add Entry", action: onAdd)
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("empty-add-entry")
                    }
                }
                .listRowBackground(Color.clear)
            } else {
                Section("Entries") {
                    ForEach(entries) { entry in
                        Button {
                            onEdit(entry)
                        } label: {
                            EntryRow(entry: entry)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                delete(entry)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button {
                                onEdit(entry)
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                delete(entry)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .contentMargins(.bottom, 72, for: .scrollContent)
    }

    private func delete(_ entry: Expense) {
        withAnimation {
            context.delete(entry)
            try? context.save()
        }
    }
}

struct DaySummaryHeader: View {
    let date: Date
    let entries: [Expense]

    private let calendar = Calendar.current
    private var spent: Double { ExpenseStats.spending(entries) }
    private var earned: Double { ExpenseStats.income(entries) }
    private var categories: [CategoryTotal] { ExpenseStats.byCategory(entries) }

    private var dayTitle: String {
        let formatted = date.formatted(.dateTime.weekday(.wide).day().month(.wide))
        if calendar.isDateInToday(date) { return String(localized: "Today · \(formatted)") }
        if calendar.isDateInYesterday(date) { return String(localized: "Yesterday · \(formatted)") }
        return formatted
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(dayTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 0) {
                Text(Money.format(spent))
                    .font(Theme.amount(.largeTitle, weight: .bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("Spent")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !categories.isEmpty {
                CategoryShareBar(totals: categories)
                HStack(spacing: 12) {
                    ForEach(categories.prefix(3)) { item in
                        HStack(spacing: 4) {
                            Circle().fill(item.category.color).frame(width: 8, height: 8)
                            Text(item.category.title)
                                .lineLimit(1)
                        }
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if earned > 0 {
                Label {
                    Text("Income \(Money.format(earned))")
                } icon: {
                    Image(systemName: "arrow.down.circle.fill")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.income)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Entry row

struct EntryRow: View {
    let entry: Expense
    var showsDate = false

    private var subtitle: String {
        let time = showsDate
            ? entry.date.formatted(date: .abbreviated, time: .shortened)
            : entry.date.formatted(date: .omitted, time: .shortened)
        return "\(entry.category.title) · \(time)"
    }

    var body: some View {
        HStack(spacing: 12) {
            CategoryIcon(category: entry.category, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.store)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    if entry.source == .recurring {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .imageScale(.small)
                    }
                    Text(subtitle)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(verbatim: (entry.isIncome ? "+" : "") + Money.format(entry.amount))
                .font(.body.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(entry.isIncome ? Theme.income : Color.primary)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint(Text("Opens the entry for editing"))
    }

    private var accessibilityText: Text {
        let amount = Money.format(entry.amount)
        let time = entry.date.formatted(date: .omitted, time: .shortened)
        if entry.isIncome {
            return Text("Income: \(entry.store), \(amount), \(entry.category.title), \(time)")
        }
        return Text(verbatim: "\(entry.store), \(amount), \(entry.category.title), \(time)")
    }
}

// MARK: - Go to date

struct DateJumpSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var date: Date
    var onPick: (Date) -> Void

    init(date: Date, onPick: @escaping (Date) -> Void) {
        _date = State(initialValue: date)
        self.onPick = onPick
    }

    var body: some View {
        NavigationStack {
            DatePicker("Date", selection: $date, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .padding(.horizontal)
                .frame(maxHeight: .infinity, alignment: .top)
                .navigationTitle("Go to Date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Go") {
                            onPick(date)
                            dismiss()
                        }
                    }
                }
        }
    }
}
