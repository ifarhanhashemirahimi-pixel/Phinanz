//
//  PhinanzWidget.swift
//  PhinanzWidget
//
//  Home Screen and Lock Screen widget: today's spending, this month, balance.
//

import WidgetKit
import SwiftUI

private enum WidgetTheme {
    static let shell = Color(red: 0x12 / 255, green: 0x10 / 255, blue: 0x10 / 255)
    static let ivory = Color(red: 0xFA / 255, green: 0xF7 / 255, blue: 0xF2 / 255)
    static let gold = Color(red: 0xB0 / 255, green: 0x8C / 255, blue: 0x3D / 255)
    static let income = Color(red: 0x7C / 255, green: 0xC0 / 255, blue: 0x8A / 255)

    static func classic(_ size: CGFloat) -> Font { .custom("Optima-Regular", size: size) }
    static func classicBold(_ size: CGFloat) -> Font { .custom("Optima-Bold", size: size) }
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
        if let snapshot = entry.snapshot {
            switch family {
            case .accessoryInline:
                Text("Today \(euro(snapshot.todaySpent))")
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

    private var empty: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: "PHINANZ")
                .font(WidgetTheme.classicBold(13))
                .kerning(2)
                .foregroundStyle(WidgetTheme.gold)
            Spacer()
            Text("Open PHINANZ to start your journal.")
                .font(WidgetTheme.classic(13))
                .foregroundStyle(WidgetTheme.ivory)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func small(_ s: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("TODAY")
                .font(WidgetTheme.classic(11))
                .kerning(1.5)
                .foregroundStyle(WidgetTheme.gold)
            Text(euro(s.todaySpent))
                .font(WidgetTheme.classicBold(26))
                .foregroundStyle(WidgetTheme.ivory)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text("This month")
                .font(WidgetTheme.classic(11))
                .foregroundStyle(WidgetTheme.ivory.opacity(0.7))
            Text(euro(s.monthSpent))
                .font(WidgetTheme.classicBold(16))
                .foregroundStyle(WidgetTheme.ivory)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if s.budgetLimit > 0 {
                budgetBar(s)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func medium(_ s: WidgetSnapshot) -> some View {
        HStack(spacing: 16) {
            small(s)
            Rectangle().fill(WidgetTheme.gold.opacity(0.5)).frame(width: 0.5)
            VStack(alignment: .leading, spacing: 6) {
                metric("Income", euro(s.monthIncome), WidgetTheme.income)
                metric("Balance", euro(s.balance), s.balance >= 0 ? WidgetTheme.ivory : .red)
                Spacer(minLength: 0)
                Text(verbatim: "PHINANZ")
                    .font(WidgetTheme.classicBold(11))
                    .kerning(2)
                    .foregroundStyle(WidgetTheme.gold)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private func metric(_ title: LocalizedStringKey, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(WidgetTheme.classic(11))
                .foregroundStyle(WidgetTheme.ivory.opacity(0.7))
            Text(value)
                .font(WidgetTheme.classicBold(17))
                .foregroundStyle(color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
    }

    private func budgetBar(_ s: WidgetSnapshot) -> some View {
        let ratio = min(max(s.monthSpent / s.budgetLimit, 0), 1)
        let color: Color = s.monthSpent > s.budgetLimit ? .red : (ratio >= 0.8 ? .orange : WidgetTheme.gold)
        return GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(WidgetTheme.ivory.opacity(0.15))
                Capsule().fill(color).frame(width: proxy.size.width * ratio)
            }
        }
        .frame(height: 4)
        .accessibilityLabel(Text("Budget used"))
        .accessibilityValue(Text(ratio.formatted(.percent.precision(.fractionLength(0)))))
    }

    private func rectangular(_ s: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(verbatim: "PHINANZ").font(.caption2).bold()
            Text("Today \(euro(s.todaySpent))").font(.caption)
            Text("Month \(euro(s.monthSpent))").font(.caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SpendingWidget: Widget {
    let kind = "PhinanzSpending"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            SpendingWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetTheme.shell }
        }
        .configurationDisplayName("Spending")
        .description("Today's and this month's spending at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct PhinanzWidgetBundle: WidgetBundle {
    var body: some Widget {
        SpendingWidget()
    }
}

#Preview(as: .systemMedium) {
    SpendingWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .preview)
}
