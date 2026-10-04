//
//  JournalTheme.swift
//  Phbank
//
//  Design tokens for the leather-notebook look of PHINANZ.
//

import SwiftUI

extension Color {
    /// Creates an sRGB colour from a 0xRRGGBB literal.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: 1.0
        )
    }
}

enum JournalTheme {
    // Palette
    static let shell = Color(hex: 0x121010)   // leather cover
    static let ivory = Color(hex: 0xFAF7F2)   // paper
    static let gold = Color(hex: 0xB08C3D)    // accents on dark
    static let brown = Color(hex: 0x6B5138)   // accents on paper
    static let ink = Color(hex: 0x1B1613)     // text on paper
    static let danger = Color(hex: 0xB33A2B)

    // Typography (dual typeface: classic for structure, handwriting for entries)
    static let fontClassic = "Optima-Regular"
    static let fontClassicBold = "Optima-Bold"
    static let fontHandwriting = "Noteworthy-Light"

    static func classic(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(fontClassic, size: size, relativeTo: style)
    }

    static func classicBold(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(fontClassicBold, size: size, relativeTo: style)
    }

    static func handwriting(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(fontHandwriting, size: size, relativeTo: style)
    }
}

extension ExpenseCategory {
    /// Muted palette that sits well next to the leather/ivory theme.
    var color: Color {
        switch self {
        case .groceries: Color(hex: 0x5B7F4F)
        case .food: Color(hex: 0xC0794A)
        case .transport: Color(hex: 0x4F6F8F)
        case .housing: Color(hex: 0x7A5C8F)
        case .entertainment: Color(hex: 0xB5496A)
        case .health: Color(hex: 0x4E9A8F)
        case .shopping: Color(hex: 0xB08C3D)
        case .software: Color(hex: 0x5E6AA8)
        case .travel: Color(hex: 0x3F8FB0)
        case .other: Color(hex: 0x8C8479)
        }
    }
}
