//
//  PhinanzWidget.swift
//  PhinanzWidget
//
//  Home Screen and Lock Screen widget: today's spending, this month, balance.
//

import WidgetKit
import SwiftUI

private enum WidgetLinks {
    static let add = URL(string: "phinanz://add")
    static let today = URL(string: "phinanz://today")
}

private enum WidgetStyle {
    static func amount(_ style: Font.TextStyle, weight: Font.Weight = .semibold) -> Font {
        .system(style, design: .rounded, weight: weight)
    }
}

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: Date(), snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        let snapshot = context.isPreview ? WidgetSnapshot.preview : (WidgetSnapshot.load() ?? .preview)
        completion(SnapshotEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let now = Date()
        let entry = SnapshotEntry(date: now, snapshot: WidgetSnapshot.load()?.current(at: now))
        // Refresh after midnight so "today" starts at zero; the app reloads us after every change.
        let nextDay = Calendar.current.startOfDay(for: now.addingTimeInterval(86_400)).addingTimeInterval(60)
        completion(Timeline(entries: [entry], policy: .after(nextDay)))
    }
}

struct SpendingWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    private func euro(_ value: Double) -> String {
        value.formatted(.currency(code: "EUR").precision(.fractionLength(value.magnitude >= 1_000 ? 0 : 2)))
    }

    var body: some View {
        if let snapshot = entry.snapshot, snapshot.isHidden == true {
            hidden
        } else if let snapshot = entry.snapshot {
            switch family {
            case .accessoryInline:
                Text("Today \(euro(snapshot.todaySpent))").privacySensitive()
            case .accessoryCircular:
                circular(snapshot)
            case .accessoryRectangular:
                rectangular(snapshot)
            case .systemMedium:
                medium(snapshot)
            default:
                small(snapshot)
            }
        } else {
            empty
        }
    }

    /// Amounts are hidden in Settings → Security; the app shares no numbers then.
    @ViewBuilder
    private var hidden: some View {
        switch family {
        case .accessoryInline:
            Label("PHINANZ", systemImage: "lock.fill")
        case .accessoryCircular:
            Image(systemName: "lock.fill").font(.title3)
        case .accessoryRectangular:
            Label("Amounts hidden", systemImage: "lock.fill").font(.caption)
        default:
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .widgetAccentable()
                Spacer()
                Text(verbatim: "PHINANZ").font(.headline)
                Text("Amounts hidden")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "book.pages.fill")
                .font(.title2)
                .foregroundStyle(.tint)
                .widgetAccentable()
            Spacer()
            Text("Open PHINANZ to start your journal.")
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func small(_ s: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("Today", systemImage: "creditcard.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tint)
                .widgetAccentable()
            Text(euro(s.todaySpent))
                .privacySensitive()
                .font(WidgetStyle.amount(.title, weight: .bold))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .contentTransition(.numericText())
            Spacer(minLength: 6)
            Text("This Month")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(euro(s.monthSpent))
                .privacySensitive()
                .font(WidgetStyle.amount(.headline))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if s.budgetLimit > 0 {
                ProgressView(value: min(max(s.monthSpent / s.budgetLimit, 0), 1))
                    .tint(budgetColor(s))
                    .padding(.top, 4)
                    .accessibilityLabel(Text("Budget used"))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func medium(_ s: WidgetSnapshot) -> some View {
        HStack(spacing: 16) {
            small(s)
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Spacer()
                    if let url = WidgetLinks.add {
                        Link(destination: url) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.tint)
                                .widgetAccentable()
                        }
                        .accessibilityLabel(Text("Add Entry"))
                    }
                }
                metric("Income", euro(s.monthIncome), systemImage: "arrow.down.circle.fill", color: .green)
                metric("Balance", euro(s.balance), systemImage: "building.columns.fill", color: .indigo)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private func metric(_ title: LocalizedStringKey, _ value: String, systemImage: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
            Text(value)
                .privacySensitive()
                .font(WidgetStyle.amount(.headline))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
    }

    private func budgetColor(_ s: WidgetSnapshot) -> Color {
        let ratio = s.monthSpent / s.budgetLimit
        if ratio > 1 { return .red }
        if ratio >= 0.8 { return .orange }
        return .green
    }

    private func circular(_ s: WidgetSnapshot) -> some View {
        Gauge(value: s.budgetLimit > 0 ? min(s.monthSpent / s.budgetLimit, 1) : 0) {
            Image(systemName: "eurosign")
        } currentValueLabel: {
            Text(s.todaySpent, format: .number.precision(.fractionLength(0)))
                .privacySensitive()
        }
        .gaugeStyle(.accessoryCircular)
    }

    private func rectangular(_ s: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(verbatim: "PHINANZ").font(.caption2).bold()
            Text("Today \(euro(s.todaySpent))").font(.caption).privacySensitive()
            Text("Month \(euro(s.monthSpent))").font(.caption).privacySensitive()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SpendingWidget: Widget {
    let kind = "PhinanzSpending"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            SpendingWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
                .widgetURL(WidgetLinks.today)
        }
        .configurationDisplayName("Spending")
        .description("Today's and this month's spending at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct PhinanzWidgetBundle: WidgetBundle {
    var body: some Widget {
        SpendingWidget()
        NewEntryControl()
    }
}

#Preview(as: .systemMedium) {
    SpendingWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .preview)
}
