//
//  Theme.swift
//  Phinanz
//
//  Design tokens following Apple's Human Interface Guidelines:
//  system colours, SF Pro (rounded for amounts), light and dark mode.
//

import SwiftUI
import UIKit

enum Theme {
    static let background = Color(uiColor: .systemBackground)
    static let groupedBackground = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let income = Color.green

    /// SF Pro Rounded, used for money amounts like Wallet and Health do.
    static func amount(_ style: Font.TextStyle, weight: Font.Weight = .semibold) -> Font {
        .system(style, design: .rounded, weight: weight)
    }
}

extension ExpenseCategory {
    var color: Color {
        switch self {
        case .groceries: .green
        case .food: .orange
        case .transport: .blue
        case .housing: .brown
        case .entertainment: .pink
        case .health: .red
        case .shopping: .purple
        case .software: .indigo
        case .travel: .cyan
        case .other: .gray
        case .salary: .green
        case .freelance: .teal
        case .refund: .mint
        case .otherIncome: .green
        }
    }
}

extension AccountKind {
    var color: Color {
        switch self {
        case .checking: .blue
        case .cash: .green
        case .credit: .orange
        case .savings: .purple
        }
    }
}

/// Symbols and colours a savings goal can use.
enum GoalStyle {
    static let symbols = [
        "star.fill", "airplane", "car.fill", "house.fill", "laptopcomputer", "iphone",
        "gift.fill", "graduationcap.fill", "heart.fill", "bicycle", "camera.fill", "umbrella.fill"
    ]
    static let colorNames = ["blue", "green", "orange", "pink", "purple", "teal", "red", "indigo"]

    static func color(_ name: String) -> Color {
        switch name {
        case "green": .green
        case "orange": .orange
        case "pink": .pink
        case "purple": .purple
        case "teal": .teal
        case "red": .red
        case "indigo": .indigo
        default: .blue
        }
    }
}

/// White symbol on a rounded, colour-filled square, like the icons in the Settings app.
struct CategoryIcon: View {
    let category: ExpenseCategory
    var size: CGFloat = 32

    var body: some View {
        SettingsIcon(systemName: category.symbol, color: category.color, size: size)
    }
}

struct SettingsIcon: View {
    let systemName: String
    let color: Color
    var size: CGFloat = 29

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: size * 0.26, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct SettingsLabel: View {
    let title: LocalizedStringKey
    let systemName: String
    let color: Color

    var body: some View {
        Label {
            Text(title)
        } icon: {
            SettingsIcon(systemName: systemName, color: color)
        }
    }
}

/// Rounded "inset grouped" card used on scroll views (Health / Fitness style).
struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

extension View {
    func card() -> some View { modifier(CardModifier()) }
}

/// Horizontal bar split by category share, like Screen Time and Apple Card.
struct CategoryShareBar: View {
    let totals: [CategoryTotal]
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            let sum = totals.reduce(0) { $0 + max($1.total, 0) }
            let spacing: CGFloat = 2
            let width = proxy.size.width.isFinite ? proxy.size.width : 0
            let available = max(0, width - spacing * CGFloat(max(totals.count - 1, 0)))
            HStack(spacing: spacing) {
                ForEach(totals) { item in
                    Rectangle()
                        .fill(item.category.color)
                        .frame(width: Self.segmentWidth(item.total, of: sum, in: available))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(Capsule())
        .accessibilityHidden(true)
    }

    /// Width of one segment. Always finite and at least 3 pt, so SwiftUI never
    /// gets a negative or infinite frame while a list row is still measuring.
    nonisolated static func segmentWidth(_ value: Double, of sum: Double, in available: CGFloat) -> CGFloat {
        let minimum: CGFloat = 3
        guard value > 0, sum > 0, sum.isFinite, available.isFinite, available > 0 else { return minimum }
        let width = available * CGFloat(min(value / sum, 1))
        return width.isFinite ? max(minimum, width) : minimum
    }
}
