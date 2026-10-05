//
//  GoalViews.swift
//  Phbank
//
//  Savings goals: progress in Plan, a detail screen with "Add Money",
//  and an editor with symbol and colour, in the style of Apple's apps.
//

import SwiftUI
import SwiftData

/// "Savings Goals" section for the Plan tab.
struct GoalsSection: View {
    @Query(sort: \SavingsGoal.createdAt) private var goals: [SavingsGoal]
    @State private var showNew = false

    var body: some View {
        Section {
            ForEach(goals) { goal in
                NavigationLink {
                    GoalDetailView(goal: goal)
                } label: {
                    GoalRow(goal: goal)
                }
            }
            Button {
                showNew = true
            } label: {
                Label("New Savings Goal", systemImage: "plus.circle.fill")
            }
            .accessibilityIdentifier("new-goal")
        } header: {
            Text("Savings Goals")
        } footer: {
            if goals.isEmpty {
                Text("Saving for a trip, a laptop or a safety cushion? PHINANZ tells you how much to put aside each month.")
            }
        }
        .sheet(isPresented: $showNew) {
            GoalEditorView(goal: nil)
        }
    }
}

struct GoalRow: View {
    let goal: SavingsGoal

    private var plan: SavingsPlanner.Plan { SavingsPlanner.plan(for: goal) }
    private var color: Color { GoalStyle.color(goal.colorName) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                SettingsIcon(systemName: goal.symbol, color: color, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.name).lineLimit(1)
                    Text(GoalText.subtitle(plan: plan, deadline: goal.deadline))
                        .font(.footnote)
                        .foregroundStyle(plan.isOverdue ? Color.red : Color.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if plan.isReached {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .accessibilityLabel(Text("Goal reached"))
                } else {
                    Text(plan.progress, format: .percent.precision(.fractionLength(0)))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(color)
                }
            }
            ProgressView(value: plan.progress)
                .tint(plan.isReached ? .green : color)
            Text("\(Money.format(goal.saved)) of \(Money.format(goal.target))")
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

enum GoalText {
    static func subtitle(plan: SavingsPlanner.Plan, deadline: Date?) -> String {
        if plan.isReached { return String(localized: "Goal reached") }
        if plan.isOverdue { return String(localized: "Target date passed") }
        if let monthly = plan.monthlyAmount, let deadline {
            return String(localized: "\(Money.format(monthly)) a month until \(deadline.formatted(.dateTime.month(.abbreviated).year()))")
        }
        return String(localized: "\(Money.format(plan.remaining)) to go")
    }
}

// MARK: - Detail

struct GoalDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var goal: SavingsGoal

    @State private var moneySheet: MoneyAction?
    @State private var editing = false
    @State private var confirmDelete = false
    @State private var celebrate = false

    enum MoneyAction: String, Identifiable {
        case add, withdraw
        var id: String { rawValue }
    }

    private var plan: SavingsPlanner.Plan { SavingsPlanner.plan(for: goal) }
    private var color: Color { GoalStyle.color(goal.colorName) }

    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .stroke(color.opacity(0.18), lineWidth: 16)
                        Circle()
                            .trim(from: 0, to: plan.progress)
                            .stroke(plan.isReached ? Color.green : color, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(duration: 0.8), value: plan.progress)
                        VStack(spacing: 4) {
                            Image(systemName: plan.isReached ? "checkmark.seal.fill" : goal.symbol)
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundStyle(plan.isReached ? Color.green : color)
                                .symbolEffect(.bounce, value: celebrate)
                            Text(plan.progress, format: .percent.precision(.fractionLength(0)))
                                .font(Theme.amount(.title, weight: .bold))
                                .monospacedDigit()
                        }
                    }
                    .frame(width: 170, height: 170)
                    .accessibilityElement(children: .combine)

                    VStack(spacing: 4) {
                        Text(Money.format(goal.saved))
                            .font(Theme.amount(.title2, weight: .bold))
                            .monospacedDigit()
                        Text("of \(Money.format(goal.target))")
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 12) {
                        Button {
                            moneySheet = .add
                        } label: {
                            Label("Add Money", systemImage: "plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("goal-add-money")
                        Button {
                            moneySheet = .withdraw
                        } label: {
                            Label("Withdraw", systemImage: "minus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(goal.saved <= 0)
                    }
                    .controlSize(.large)
                    .tint(color)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section {
                LabeledContent("Still to Save", value: Money.format(plan.remaining))
                if let deadline = goal.deadline {
                    LabeledContent("Target Date", value: deadline.formatted(date: .long, time: .omitted))
                }
                if let monthly = plan.monthlyAmount, !plan.isReached {
                    LabeledContent("Per Month", value: Money.format(monthly))
                }
            } footer: {
                if plan.isReached {
                    Text("Well done — you reached this goal.")
                } else if let months = plan.monthsLeft, let monthly = plan.monthlyAmount, !plan.isOverdue {
                    Text("Put aside \(Money.format(monthly)) a month for \(months) months and you reach your goal on time.")
                }
            }

            Section {
                Button("Edit Goal") { editing = true }
                Button("Delete Goal", role: .destructive) { confirmDelete = true }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(goal.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $moneySheet) { action in
            GoalMoneySheet(action: action, goal: goal) { reached in
                if reached { celebrate.toggle() }
            }
        }
        .sheet(isPresented: $editing) {
            GoalEditorView(goal: goal)
        }
        .confirmationDialog("Delete this goal?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete Goal", role: .destructive) {
                // Close the screen first; it must not read a deleted goal.
                let doomed = goal
                let store = context
                dismiss()
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(400))
                    store.delete(doomed)
                    try? store.save()
                }
            }
        }
        .sensoryFeedback(.success, trigger: celebrate)
        #if DEBUG
        .onReceive(DemoDirector.shared.commands) { command in
            if case .addToGoal(let amount) = command {
                withAnimation(.spring(duration: 0.8)) {
                    goal.saved = Money.roundCents(goal.saved + amount)
                }
                celebrate.toggle()
            }
        }
        #endif
    }
}

struct GoalMoneySheet: View {
    @Environment(\.dismiss) private var dismiss
    let action: GoalDetailView.MoneyAction
    @Bindable var goal: SavingsGoal
    var onDone: (Bool) -> Void

    @State private var amountText = ""
    @FocusState private var focused: Bool

    private var amount: Double? {
        guard let value = Money.parse(amountText), value > 0, value < 1_000_000 else { return nil }
        if action == .withdraw && value > goal.saved + 0.004 { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 4) {
                        TextField("0,00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(Theme.amount(.largeTitle, weight: .bold))
                            .focused($focused)
                            .accessibilityIdentifier("goal-amount")
                        Text(verbatim: "€")
                            .font(Theme.amount(.title))
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    if action == .withdraw {
                        Text("Saved so far: \(Money.format(goal.saved))")
                    } else {
                        Text("Moves the amount into this goal. Use a transfer to your savings account if the money also moves in your bank.")
                    }
                }
            }
            .navigationTitle(action == .add ? "Add Money" : "Withdraw")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: save).disabled(amount == nil)
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.height(300)])
    }

    private func save() {
        guard let amount else { return }
        let wasReached = SavingsPlanner.plan(for: goal).isReached
        let change = action == .add ? amount : -amount
        goal.saved = Money.roundCents(min(max(goal.saved + change, 0), 1_000_000))
        try? goal.modelContext?.save()
        let reached = SavingsPlanner.plan(for: goal).isReached
        dismiss()
        onDone(reached && !wasReached)
    }
}

// MARK: - Editor

struct GoalEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let goal: SavingsGoal?

    @State private var name: String
    @State private var targetText: String
    @State private var savedText: String
    @State private var hasDeadline: Bool
    @State private var deadline: Date
    @State private var symbol: String
    @State private var colorName: String

    init(goal: SavingsGoal?) {
        self.goal = goal
        _name = State(initialValue: goal?.name ?? "")
        _targetText = State(initialValue: goal.map { Money.input($0.target) } ?? "")
        _savedText = State(initialValue: goal.map { $0.saved == 0 ? "" : Money.input($0.saved) } ?? "")
        _hasDeadline = State(initialValue: goal?.deadline != nil)
        _deadline = State(initialValue: goal?.deadline ?? Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date())
        _symbol = State(initialValue: goal?.symbol ?? "star.fill")
        _colorName = State(initialValue: goal?.colorName ?? "blue")
    }

    private var target: Double? {
        guard let value = Money.parse(targetText), value > 0, value < 1_000_000 else { return nil }
        return value
    }

    private var saved: Double? {
        if savedText.trimmingCharacters(in: .whitespaces).isEmpty { return 0 }
        guard let value = Money.parse(savedText), value < 1_000_000 else { return nil }
        return value
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSave: Bool { !trimmedName.isEmpty && target != nil && saved != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        SettingsIcon(systemName: symbol, color: GoalStyle.color(colorName), size: 44)
                        TextField("Name, e.g. Trip to Lisbon", text: $name)
                            .font(.headline)
                            .accessibilityIdentifier("goal-name")
                    }
                }
                Section {
                    LabeledContent("Target") {
                        amountField($targetText, identifier: "goal-target")
                    }
                    LabeledContent("Already Saved") {
                        amountField($savedText, identifier: "goal-saved")
                    }
                    Toggle("Target Date", isOn: $hasDeadline.animation())
                    if hasDeadline {
                        DatePicker("Date", selection: $deadline, in: Date()..., displayedComponents: .date)
                    }
                } footer: {
                    if let target, let saved, hasDeadline {
                        let plan = SavingsPlanner.plan(target: target, saved: saved, deadline: deadline)
                        if let monthly = plan.monthlyAmount, !plan.isReached {
                            Text("That is \(Money.format(monthly)) a month.")
                        }
                    }
                }
                Section("Symbol") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(GoalStyle.symbols, id: \.self) { item in
                            Button {
                                symbol = item
                            } label: {
                                Image(systemName: item)
                                    .font(.title3)
                                    .frame(width: 40, height: 40)
                                    .background(symbol == item ? GoalStyle.color(colorName).opacity(0.2) : Color.clear, in: Circle())
                                    .foregroundStyle(symbol == item ? GoalStyle.color(colorName) : Color.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section("Color") {
                    HStack {
                        ForEach(GoalStyle.colorNames, id: \.self) { item in
                            Button {
                                colorName = item
                            } label: {
                                Circle()
                                    .fill(GoalStyle.color(item))
                                    .frame(width: 30, height: 30)
                                    .overlay {
                                        if colorName == item {
                                            Image(systemName: "checkmark")
                                                .font(.caption.bold())
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(goal == nil ? "New Goal" : "Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                        .accessibilityIdentifier("save-goal")
                }
            }
        }
    }

    private func amountField(_ text: Binding<String>, identifier: String) -> some View {
        HStack(spacing: 4) {
            TextField("0,00", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .accessibilityIdentifier(identifier)
            Text(verbatim: "€").foregroundStyle(.secondary)
        }
    }

    private func save() {
        guard let target, let saved else { return }
        let finalName = String(trimmedName.prefix(60))
        if let goal {
            goal.name = finalName
            goal.target = Money.roundCents(target)
            goal.saved = Money.roundCents(saved)
            goal.deadline = hasDeadline ? deadline : nil
            goal.symbol = symbol
            goal.colorName = colorName
        } else {
            context.insert(SavingsGoal(name: finalName, target: Money.roundCents(target), saved: Money.roundCents(saved),
                                       deadline: hasDeadline ? deadline : nil, symbol: symbol, colorName: colorName))
        }
        try? context.save()
        dismiss()
    }
}
