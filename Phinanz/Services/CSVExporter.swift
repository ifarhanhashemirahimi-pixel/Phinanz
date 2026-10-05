//
//  CSVExporter.swift
//  Phinanz
//
//  Tax-report export. Semicolon-separated with decimal comma and a UTF-8 BOM so
//  German Excel opens it correctly.
//

import Foundation

enum CSVExporter {
    static var header: [String] {
        [
            String(localized: "Date"), String(localized: "Time"), String(localized: "Type"),
            String(localized: "Store"), String(localized: "Category"), String(localized: "Amount (EUR)"),
            String(localized: "Note"), String(localized: "Source"), String(localized: "Tax Hint")
        ]
    }

    static func csv(for expenses: [Expense], calendar: Calendar = .current) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = calendar
        dateFormatter.timeZone = calendar.timeZone
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let timeFormatter = DateFormatter()
        timeFormatter.calendar = calendar
        timeFormatter.timeZone = calendar.timeZone
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.dateFormat = "HH:mm"

        var lines = [header.joined(separator: ";")]
        for expense in expenses.sorted(by: { $0.date < $1.date }) {
            let fields = [
                dateFormatter.string(from: expense.date),
                timeFormatter.string(from: expense.date),
                expense.isIncome ? String(localized: "Income") : String(localized: "Expense"),
                expense.store,
                expense.category.title,
                Money.plain(expense.amount).replacingOccurrences(of: ".", with: ","),
                expense.note,
                expense.source.title,
                taxHint(for: expense)
            ]
            lines.append(fields.map { escape($0) }.joined(separator: ";"))
        }
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    /// The tax-hint column: the kind of hint, "Marked" for the user's own picks, or empty.
    static func taxHint(for expense: Expense) -> String {
        guard TaxHints.isRelevant(expense) else { return "" }
        return TaxHints.suggestion(for: expense)?.title ?? String(localized: "Marked")
    }

    /// Quotes fields that need it and neutralises spreadsheet formulas in untrusted text.
    static func escape(_ field: String) -> String {
        var value = field
        if let first = value.first, "=+-@\t\r".contains(first) {
            value = "'" + value
        }
        let needsQuotes = value.contains(";") || value.contains("\"") || value.contains("\n") || value.contains("\r")
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return needsQuotes ? "\"\(escaped)\"" : escaped
    }

    static func writeFile(for expenses: [Expense], year: Int) throws -> URL {
        let content = "\u{FEFF}" + csv(for: expenses)
        return try DataProtection.writeExport(Data(content.utf8), named: "\(year).csv")
    }
}
