//
//  BankCSVImporter.swift
//  Phbank
//
//  Reads the CSV exports of German banks (Sparkasse, ING, DKB, N26,
//  Commerzbank, comdirect, Volksbank, Postbank, Deutsche Bank …) on the
//  device. Nothing is sent anywhere. Columns are found by their names, so
//  new layouts usually work without code changes.
//

import Foundation

enum BankCSVImporter {
    /// One booking from the file. `amount` is signed: negative = money out.
    struct Booking: Equatable {
        var date: Date
        var amount: Double
        var counterparty: String
        var purpose: String
    }

    enum ImportError: LocalizedError, Equatable {
        case unreadable
        case unknownLayout
        case noBookings

        var errorDescription: String? {
            switch self {
            case .unreadable:
                String(localized: "The file could not be read as text.")
            case .unknownLayout:
                String(localized: "This doesn't look like a bank export. PHINANZ needs a date and an amount column.")
            case .noBookings:
                String(localized: "No bookings were found in this file.")
            }
        }
    }

    static let maxFileSize = 5_000_000
    static let maxBookings = 5_000

    // MARK: Public API

    /// UTF-8 (with or without BOM) first, then Windows-1252, which many
    /// German banks still use.
    static func decode(_ data: Data) -> String? {
        guard !data.isEmpty, data.count <= maxFileSize else { return nil }
        if var text = String(data: data, encoding: .utf8) {
            if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
            return text
        }
        return String(data: data, encoding: .windowsCP1252) ?? String(data: data, encoding: .isoLatin1)
    }

    static func bookings(in data: Data, calendar: Calendar = .current) throws -> [Booking] {
        guard let text = decode(data) else { throw ImportError.unreadable }
        return try bookings(in: text, calendar: calendar)
    }

    static func bookings(in text: String, calendar: Calendar = .current) throws -> [Booking] {
        for delimiter in [";", "\t", ","] as [Unicode.Scalar] {
            let table = rows(in: text, delimiter: delimiter)
            guard let header = findHeader(in: table) else { continue }
            let columns = header.columns
            let result = table.dropFirst(header.index + 1)
                .lazy
                .compactMap { booking(from: $0, columns: columns, calendar: calendar) }
                .prefix(maxBookings)
            let list = Array(result)
            if list.isEmpty { throw ImportError.noBookings }
            return list
        }
        throw ImportError.unknownLayout
    }

    /// Turns bookings into entries for the review screen. Categories come
    /// from your own history first, then from known merchant names.
    static func drafts(from bookings: [Booking], history: [Expense] = [], calendar: Calendar = .current) -> [DraftExpense] {
        bookings.map { booking in
            let isIncome = booking.amount > 0
            let store = storeName(for: booking)
            let fallback: ExpenseCategory = isIncome ? .otherIncome : .other
            let suggested = CategorySuggester.suggest(for: store, history: history)
                ?? CategorySuggester.suggest(for: booking.purpose)
            let category = suggested.flatMap { $0.isIncome == isIncome ? $0 : nil } ?? fallback
            let date = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: booking.date) ?? booking.date
            return DraftExpense(
                store: store,
                amount: abs(booking.amount),
                category: category,
                date: date,
                note: String(booking.purpose.prefix(200)),
                isIncome: isIncome,
                source: .statement
            )
        }
    }

    // MARK: Columns

    struct Columns: Equatable {
        var date: Int
        var amount: Int?
        var debit: Int?
        var credit: Int?
        var debitCreditFlag: Int?
        var combinedParty: Int?
        var payee: Int?
        var payer: Int?
        var purpose: Int?
        var bookingText: Int?
        var status: Int?
    }

    static func normalize(_ header: String) -> String {
        var text = header.lowercased()
        for (from, to) in [("ä", "ae"), ("ö", "oe"), ("ü", "ue"), ("ß", "ss")] {
            text = text.replacingOccurrences(of: from, with: to)
        }
        let kept = text.unicodeScalars.map { scalar -> Character in
            if CharacterSet.letters.contains(scalar) || CharacterSet.decimalDigits.contains(scalar) || scalar == "/" {
                return Character(scalar)
            }
            return " "
        }
        return String(kept)
            .replacingOccurrences(of: " / ", with: "/")
            .replacingOccurrences(of: " /", with: "/")
            .replacingOccurrences(of: "/ ", with: "/")
            .split(separator: " ")
            .joined(separator: " ")
    }

    /// Index of the first header equal to a name, else the first that starts with one.
    private static func index(of names: [String], in headers: [String], prefix: Bool = true) -> Int? {
        for name in names {
            if let index = headers.firstIndex(of: name) { return index }
        }
        guard prefix else { return nil }
        for name in names {
            if let index = headers.firstIndex(where: { $0.hasPrefix(name) }) { return index }
        }
        return nil
    }

    static func columns(for rawHeaders: [String]) -> Columns? {
        let headers = rawHeaders.map { normalize($0) }
        guard headers.count >= 3 else { return nil }

        guard let date = index(of: ["buchungstag", "buchungsdatum", "buchung", "booking date", "datum", "date",
                                    "valutadatum", "wertstellung", "value date"], in: headers)
        else { return nil }

        let amount = index(of: ["betrag", "amount", "umsatz in", "umsatz"], in: headers.map { $0 == "umsatzart" || $0 == "umsatztyp" ? "" : $0 })
        let debit = index(of: ["soll"], in: headers, prefix: false)
        let credit = index(of: ["haben"], in: headers, prefix: false)
        guard amount != nil || (debit != nil && credit != nil), amount != date else { return nil }

        return Columns(
            date: date,
            amount: amount,
            debit: debit,
            credit: credit,
            debitCreditFlag: index(of: ["soll/haben", "s/h"], in: headers, prefix: false),
            combinedParty: index(of: ["beguenstigter/zahlungspflichtiger", "auftraggeber/empfaenger", "empfaenger/auftraggeber",
                                      "beguenstigter/auftraggeber", "name zahlungsbeteiligter", "zahlungsbeteiligter",
                                      "partner name", "payee", "name"], in: headers),
            payee: index(of: ["zahlungsempfaenger", "empfaenger"], in: headers),
            payer: index(of: ["zahlungspflichtige", "auftraggeber"], in: headers, prefix: false)
                ?? index(of: ["zahlungspflichtige"], in: headers),
            purpose: index(of: ["verwendungszweck", "payment reference", "reference", "beschreibung", "description"], in: headers),
            bookingText: index(of: ["buchungstext", "vorgang", "umsatzart", "type"], in: headers, prefix: false),
            status: index(of: ["status", "info"], in: headers, prefix: false)
        )
    }

    private static func findHeader(in table: [[String]]) -> (index: Int, columns: Columns)? {
        for (offset, row) in table.prefix(40).enumerated() {
            if let found = columns(for: row) { return (offset, found) }
        }
        return nil
    }

    // MARK: Rows

    private static func booking(from row: [String], columns: Columns, calendar: Calendar) -> Booking? {
        func cell(_ index: Int?) -> String {
            guard let index, index < row.count else { return "" }
            return row[index].split(whereSeparator: \.isWhitespace).joined(separator: " ")
        }

        let status = cell(columns.status).lowercased()
        if status.contains("vorgemerkt") || status.contains("pending") { return nil }

        guard let date = parseDate(cell(columns.date), calendar: calendar) else { return nil }

        var amount: Double?
        if columns.amount != nil {
            amount = parseAmount(cell(columns.amount))
            if let flag = columns.debitCreditFlag, let value = amount {
                let mark = cell(flag).uppercased()
                if mark == "S" || mark == "SOLL" { amount = -abs(value) }
                if mark == "H" || mark == "HABEN" { amount = abs(value) }
            }
        } else {
            let debit = parseAmount(cell(columns.debit)) ?? 0
            let credit = parseAmount(cell(columns.credit)) ?? 0
            amount = abs(credit) - abs(debit)
        }
        guard let amount, amount != 0, abs(amount) < 1_000_000 else { return nil }

        let party: String
        if columns.combinedParty != nil {
            party = cell(columns.combinedParty)
        } else if amount < 0 {
            party = [cell(columns.payee), cell(columns.payer)].first { !$0.isEmpty } ?? ""
        } else {
            party = [cell(columns.payer), cell(columns.payee)].first { !$0.isEmpty } ?? ""
        }
        let purpose = [cell(columns.purpose), cell(columns.bookingText)].first { !$0.isEmpty } ?? ""

        return Booking(date: date, amount: amount, counterparty: party, purpose: purpose)
    }

    static func storeName(for booking: Booking) -> String {
        let name = booking.counterparty.isEmpty ? booking.purpose : booking.counterparty
        let trimmed = String(name.prefix(60)).trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? ExpenseSource.statement.title : trimmed
    }

    /// "31.12.2026", "31.12.26", "2026-12-31", "31/12/2026".
    static func parseDate(_ text: String, calendar: Calendar) -> Date? {
        let parts = text.split(whereSeparator: { $0 == "." || $0 == "-" || $0 == "/" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 3, let a = Int(parts[0]), let b = Int(parts[1]), let c = Int(parts[2]) else { return nil }
        let (year, month, day) = parts[0].count == 4 ? (a, b, c) : (c < 100 ? 2000 + c : c, b, a)
        guard (1990...2100).contains(year),
              let date = calendar.date(from: DateComponents(year: year, month: month, day: day)),
              calendar.component(.month, from: date) == month,
              calendar.component(.day, from: date) == day
        else { return nil }
        return date
    }

    /// "-1.234,56", "1234.56", "+12,50 €", "12,50-", "−9,99".
    static func parseAmount(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let negative = trimmed.contains("-") || trimmed.contains("−")
        let digits = trimmed
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "−", with: "")
            .replacingOccurrences(of: "+", with: "")
        guard let value = Money.parse(digits) else { return nil }
        return negative ? -value : value
    }

    // MARK: CSV

    /// RFC 4180-style parsing: quoted fields, doubled quotes, CRLF/LF/CR line ends.
    static func rows(in text: String, delimiter: Unicode.Scalar) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = String.UnicodeScalarView()
        var inQuotes = false
        let scalars = Array(text.unicodeScalars)
        var index = 0

        func endField() {
            row.append(String(field).trimmingCharacters(in: .whitespaces))
            field = String.UnicodeScalarView()
        }

        while index < scalars.count {
            let scalar = scalars[index]
            if inQuotes {
                if scalar == "\"" {
                    if index + 1 < scalars.count, scalars[index + 1] == "\"" {
                        field.append("\"")
                        index += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(scalar)
                }
            } else if scalar == "\"" {
                inQuotes = true
            } else if scalar == delimiter {
                endField()
            } else if scalar == "\n" || scalar == "\r" {
                endField()
                rows.append(row)
                row = []
                if scalar == "\r", index + 1 < scalars.count, scalars[index + 1] == "\n" { index += 1 }
            } else {
                field.append(scalar)
            }
            index += 1
        }
        if !field.isEmpty || !row.isEmpty {
            endField()
            rows.append(row)
        }
        return rows
    }
}
