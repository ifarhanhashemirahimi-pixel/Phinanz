//
//  CSVExporter.swift
//  Phbank
//
//  Tax-report export. Semicolon-separated with decimal comma and a UTF-8 BOM so
//  German Excel opens it correctly.
//

import Foundation

enum CSVExporter {
    static let header = ["Date", "Time", "Store", "Category", "Amount (EUR)", "Note", "Source"]

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
                expense.store,
                expense.category.title,
                Money.plain(expense.amount).replacingOccurrences(of: ".", with: ","),
                expense.note,
                expense.source.title
            ]
            lines.append(fields.map(escape).joined(separator: ";"))
        }
        return lines.joined(separator: "\r\n") + "\r\n"
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
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("PHINANZ-\(year).csv")
        let content = "\u{FEFF}" + csv(for: expenses)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
