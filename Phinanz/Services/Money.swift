//
//  Money.swift
//  Phinanz
//

import Foundation

enum Money {
    /// Localised currency string, e.g. "12,50 €".
    static func format(_ value: Double) -> String {
        value.formatted(.currency(code: "EUR"))
    }

    /// Locale-independent two-decimals string, e.g. "12.50".
    static func plain(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    /// Two-decimals string using the user's decimal separator (for text fields).
    static func input(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(2)).grouping(.never))
    }

    /// Localised two-decimals number without currency, e.g. "12,50" or "۱۲٫۵۰".
    static func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(2)))
    }

    /// Converts Persian/Arabic-Indic digits and separators to ASCII so the
    /// Persian keyboard works in amount fields.
    static func normalizeDigits(_ text: String) -> String {
        var result = ""
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x06F0...0x06F9: result.append(Character(UnicodeScalar(scalar.value - 0x06F0 + 48)!))
            case 0x0660...0x0669: result.append(Character(UnicodeScalar(scalar.value - 0x0660 + 48)!))
            case 0x066B: result.append(",")   // Arabic decimal separator
            case 0x066C: result.append(".")   // Arabic thousands separator
            default: result.unicodeScalars.append(scalar)
            }
        }
        return result
    }

    static func roundCents(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }

    /// Parses user input such as "12,50", "12.50", "1.234,56", "1,234.56" or "€ 9".
    /// A single "." or "," is always treated as the decimal separator.
    static func parse(_ text: String) -> Double? {
        var s = normalizeDigits(text)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: "EUR", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
        guard !s.isEmpty else { return nil }

        let lastComma = s.lastIndex(of: ",")
        let lastDot = s.lastIndex(of: ".")

        switch (lastComma, lastDot) {
        case let (comma?, dot?):
            if comma > dot {
                s = s.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
            } else {
                s = s.replacingOccurrences(of: ",", with: "")
            }
        case (_?, nil):
            if s.filter({ $0 == "," }).count > 1 { return nil }
            s = s.replacingOccurrences(of: ",", with: ".")
        case (nil, _?):
            if s.filter({ $0 == "." }).count > 1 {
                s = s.replacingOccurrences(of: ".", with: "")
            }
        case (nil, nil):
            break
        }

        guard let value = Double(s), value.isFinite, value >= 0 else { return nil }
        return roundCents(value)
    }

    /// Like `parse`, but accepts a leading minus ("-250", "−1.200,00") for balances.
    static func parseSigned(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let negative = trimmed.hasPrefix("-") || trimmed.hasPrefix("−")
        let rest = negative ? String(trimmed.dropFirst()) : trimmed
        guard let value = parse(rest) else { return nil }
        return negative ? -value : value
    }
}
