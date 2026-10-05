//
//  AISelfTest.swift
//  Phinanz
//
//  DEBUG-only: when `snapshots/AITEST` exists, runs the on-device AI path
//  once on sample data (OCR of a rendered receipt, receipt / voice / statement
//  extraction, monthly recap) and writes the results to
//  `snapshots/ai-selftest.txt`. The flag file is removed afterwards.
//  Never compiled into release builds.
//

#if DEBUG
import Foundation
import UIKit

enum AISelfTest {
    static func runIfRequested() async {
        guard !DebugFlags.isTesting, let flag = DebugFlags.url("AITEST") else { return }
        let output = flag.deletingLastPathComponent().appendingPathComponent("ai-selftest.txt")
        try? FileManager.default.removeItem(at: flag)

        var log = "AI self-test \(Date())\nApple Intelligence: \(AppleIntelligence.status)\n"
        log += "Supports de/en/fa: \(AppleIntelligence.supportsLanguage("de"))/\(AppleIntelligence.supportsLanguage("en"))/\(AppleIntelligence.supportsLanguage("fa"))\n"
        log += "Engines (receipt): \(AIReadiness.engines(for: .receipt)), (recap): \(AIReadiness.engines(for: .recap))\n\n"
        func write() { try? log.write(to: output, atomically: true, encoding: .utf8) }
        write()

        let now = Date()
        let receipt = """
        REWE Markt GmbH
        Frankfurter Str. 12, 64293 Darmstadt
        Bananen          1,29
        Vollmilch 1,5%   1,19
        Brot             2,49
        Kaffee          6,99
        SUMME EUR       11,96
        Geg. EC-Karte   11,96
        04.10.2026 18:42
        """

        // 1. OCR of a rendered receipt image.
        let image = render(receipt)
        do {
            let text = try await OnDeviceOCR.text(in: image)
            log += "1 OCR (\(text.count) chars):\n\(text)\n\n"
        } catch { log += "1 OCR failed: \(error)\n\n" }
        write()

        // 2. Receipt text → entries.
        await run("2 Receipt", &log) { try await AppleIntelligence.structure(receipt, kind: .receipt, now: now) }
        write()

        // 3. Spoken note → entries.
        let voice = "Heute habe ich 45 Euro bei Edeka ausgegeben und gestern 12,50 im Kino. Außerdem kamen 300 Euro vom Nebenjob."
        await run("3 Voice", &log) { try await AppleIntelligence.structure(voice, kind: .voice, now: now) }
        write()

        // 4. Statement lines → entries.
        let statement = """
        Buchungstag Empfänger Verwendungszweck Betrag
        01.10.2026 Arbeitgeber GmbH Gehalt Oktober +2.450,00
        01.10.2026 Hausverwaltung Kraus Miete Oktober -720,00
        02.10.2026 Netflix International Abo -13,99
        03.10.2026 Deutsche Bahn Ticket Frankfurt-Darmstadt -9,80
        """
        await run("4 Statement", &log) { try await AppleIntelligence.structure(statement, kind: .statement, now: now) }
        write()

        // 5. Monthly recap in German and English.
        let facts = RecapFacts(report: ReportBuilder.build(month: now, entries: [], budgets: []))
        log += "5 Recap facts empty month: \(facts.spent)\n"
        for language in ["de", "en"] {
            do {
                let text = try await AppleIntelligence.writeRecap(facts: sampleFacts(), language: language)
                log += "5 Recap \(language): \(text)\n"
            } catch { log += "5 Recap \(language) failed: \(error)\n" }
            write()
        }
        log += "\nDone \(Date())\n"
        write()
    }

    private static func run(_ title: String, _ log: inout String, _ work: () async throws -> [ParsedExpense]) async {
        let start = Date()
        do {
            let items = try await work()
            log += "\(title) (\(String(format: "%.1f", Date().timeIntervalSince(start))) s):\n"
            for item in items {
                log += "  - \(item.type ?? "?") | \(item.store) | \(item.amount) | \(item.category) | \(item.date ?? "-") \(item.time ?? "")\n"
            }
            if items.isEmpty { log += "  (nothing)\n" }
        } catch {
            log += "\(title) failed: \(error.localizedDescription)\n"
        }
        log += "\n"
    }

    /// Facts like a real month, so the recap has something to say.
    private static func sampleFacts() -> RecapFacts {
        let calendar = Calendar.current
        let month = calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        func day(_ d: Int, _ offset: Int = 0) -> Date {
            let start = calendar.dateInterval(of: .month, for: calendar.date(byAdding: .month, value: offset, to: month) ?? month)?.start ?? month
            return calendar.date(byAdding: .day, value: d - 1, to: start) ?? start
        }
        let entries = [
            Expense(store: "Miete", amount: 720, category: .housing, date: day(1), source: .recurring),
            Expense(store: "REWE", amount: 210.40, category: .groceries, date: day(5)),
            Expense(store: "Restaurant", amount: 64, category: .food, date: day(12)),
            Expense(store: "UNICEF Spende", amount: 25, category: .other, date: day(15)),
            Expense(store: "Gehalt", amount: 2_450, category: .salary, date: day(28), isIncome: true),
            Expense(store: "Miete", amount: 720, category: .housing, date: day(1, -1), source: .recurring),
            Expense(store: "REWE", amount: 260, category: .groceries, date: day(6, -1))
        ]
        return RecapFacts(report: ReportBuilder.build(month: month, entries: entries, budgets: []))
    }

    private static func render(_ text: String) -> UIImage {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 28, weight: .regular),
            .foregroundColor: UIColor.black
        ]
        let size = CGSize(width: 700, height: 520)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            (text as NSString).draw(in: CGRect(x: 30, y: 20, width: 640, height: 480), withAttributes: attributes)
        }
    }
}
#endif
