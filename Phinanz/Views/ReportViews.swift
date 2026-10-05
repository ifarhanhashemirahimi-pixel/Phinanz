//
//  ReportViews.swift
//  Phinanz
//
//  Monthly report: the month compared with the one before, plain-language
//  insights and a PDF to share or print.
//

import SwiftUI
import Charts
import UIKit

struct MonthlyReportView: View {
    let expenses: [Expense]
    let budgets: [CategoryBudget]

    @State private var month: Date
    @State private var pdfURL: URL?
    @State private var pdfError: String?

    private let calendar = Calendar.current

    init(expenses: [Expense], budgets: [CategoryBudget], month: Date = Date()) {
        self.expenses = expenses
        self.budgets = budgets
        _month = State(initialValue: month)
    }

    private var report: MonthlyReport {
        ReportBuilder.build(month: month, entries: expenses, budgets: budgets)
    }

    private var isCurrentMonth: Bool {
        calendar.isDate(month, equalTo: Date(), toGranularity: .month)
    }

    var body: some View {
        let report = self.report
        ScrollView {
            VStack(spacing: 16) {
                monthBar
                if report.isEmpty {
                    ContentUnavailableView(
                        "No Entries",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("There is nothing to report for this month yet.")
                    )
                    .padding(.top, 40)
                } else {
                    ReportHeaderCard(report: report)
                    if !report.insights.isEmpty { ReportInsightsCard(report: report) }
                    ReportComparisonCard(report: report)
                    if !report.topStores.isEmpty { ReportStoresCard(report: report) }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(Theme.groupedBackground)
        .navigationTitle("Monthly Report")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if let pdfURL {
                    ShareLink(item: pdfURL) {
                        Label("Share PDF", systemImage: "square.and.arrow.up")
                    }
                } else {
                    Button {
                        makePDF(report)
                    } label: {
                        Label("Create PDF", systemImage: "doc.richtext")
                    }
                    .disabled(report.isEmpty)
                    .accessibilityIdentifier("report-pdf")
                }
            }
        }
        .alert("Couldn't Create PDF", isPresented: Binding(get: { pdfError != nil }, set: { if !$0 { pdfError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(pdfError ?? "")
        }
        .onChange(of: month) { pdfURL = nil }
        .sensoryFeedback(.selection, trigger: month)
    }

    private var monthBar: some View {
        HStack {
            Button { shift(-1) } label: {
                Image(systemName: "chevron.backward").frame(width: 44, height: 44)
            }
            .accessibilityLabel(Text("Previous Month"))
            Spacer()
            Text(month.formatted(.dateTime.month(.wide).year()))
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button { shift(1) } label: {
                Image(systemName: "chevron.forward").frame(width: 44, height: 44)
            }
            .disabled(isCurrentMonth)
            .accessibilityLabel(Text("Next Month"))
        }
        .fontWeight(.semibold)
    }

    private func shift(_ delta: Int) {
        month = calendar.date(byAdding: .month, value: delta, to: month) ?? month
    }

    private func makePDF(_ report: MonthlyReport) {
        do {
            pdfURL = try ReportPDF.write(report)
        } catch {
            pdfError = error.localizedDescription
        }
    }
}

// MARK: - Cards (shared by the screen and the PDF)

struct ReportHeaderCard: View {
    let report: MonthlyReport

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Spending", systemImage: "creditcard.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)
            Text(Money.format(report.spending))
                .font(Theme.amount(.largeTitle, weight: .bold))
                .monospacedDigit()
            if let change = report.spendingChange {
                Label {
                    Text("\(abs(change).formatted(.percent.precision(.fractionLength(0)))) vs. \(report.previousMonth.start.formatted(.dateTime.month(.wide)))")
                } icon: {
                    Image(systemName: change <= 0 ? "arrow.down.right" : "arrow.up.right")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(change <= 0 ? Color.green : Color.red)
            }
            Divider()
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                GridRow {
                    metric("Income", Money.format(report.income), color: .green)
                    metric("Net", (report.net > 0 ? "+" : "") + Money.format(report.net), color: report.net >= 0 ? .blue : .red)
                }
                GridRow {
                    metric("Per Day", Money.format(report.dailyAverage), color: .orange)
                    metric("Saved", report.savingsRate.map { max($0, 0).formatted(.percent.precision(.fractionLength(0))) } ?? "–", color: .purple)
                }
            }
        }
        .card()
    }

    private func metric(_ title: LocalizedStringKey, _ value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
            Text(verbatim: value)
                .font(Theme.amount(.headline))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct ReportInsightsCard: View {
    let report: MonthlyReport

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Insights")
                .font(.headline)
            ForEach(report.insights) { insight in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Image(systemName: insight.symbol)
                        .foregroundStyle(color(for: insight.tone))
                        .frame(width: 24)
                    Text(insight.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func color(for tone: MonthlyReport.Tone) -> Color {
        switch tone {
        case .positive: .green
        case .negative: .orange
        case .neutral: .blue
        }
    }
}

struct ReportComparisonCard: View {
    let report: MonthlyReport

    private struct Bar: Identifiable {
        let category: ExpenseCategory
        let period: String
        let amount: Double
        var id: String { category.rawValue + period }
    }

    private var bars: [Bar] {
        let thisMonth = report.month.start.formatted(.dateTime.month(.abbreviated))
        let lastMonth = report.previousMonth.start.formatted(.dateTime.month(.abbreviated))
        return report.categories.prefix(6).flatMap {
            [Bar(category: $0.category, period: lastMonth, amount: $0.previous),
             Bar(category: $0.category, period: thisMonth, amount: $0.current)]
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Compared with \(report.previousMonth.start.formatted(.dateTime.month(.wide)))")
                .font(.headline)
            Chart(bars) { bar in
                BarMark(
                    x: .value("Amount", bar.amount),
                    y: .value("Category", bar.category.title)
                )
                .position(by: .value("Month", bar.period))
                .foregroundStyle(by: .value("Month", bar.period))
            }
            .chartForegroundStyleScale(range: [Color.gray.opacity(0.45), Color.accentColor])
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(amount, format: .currency(code: "EUR").precision(.fractionLength(0)))
                        }
                    }
                }
            }
            .frame(height: CGFloat(max(report.categories.prefix(6).count, 1)) * 44 + 40)
            .accessibilityLabel(Text("Spending by category compared with last month"))

            ForEach(report.categories.prefix(6)) { item in
                HStack(spacing: 10) {
                    CategoryIcon(category: item.category, size: 26)
                    Text(item.category.title)
                    Spacer()
                    if item.previous > 0 || item.current > 0 {
                        Text(verbatim: (item.delta > 0 ? "+" : item.delta < 0 ? "−" : "±") + Money.format(abs(item.delta)))
                            .font(.subheadline)
                            .monospacedDigit()
                            .foregroundStyle(item.delta > 0 ? Color.orange : item.delta < 0 ? Color.green : Color.secondary)
                    }
                    Text(Money.format(item.current))
                        .monospacedDigit()
                        .frame(minWidth: 76, alignment: .trailing)
                }
                .font(.subheadline)
                .accessibilityElement(children: .combine)
            }
        }
        .card()
    }
}

struct ReportStoresCard: View {
    let report: MonthlyReport

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Stores")
                .font(.headline)
            ForEach(report.topStores) { store in
                HStack {
                    Text(store.store).lineLimit(1)
                    Spacer()
                    Text(Money.format(store.total)).monospacedDigit()
                }
                .font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

// MARK: - PDF

/// One A4 page in light mode, made from the same cards as the screen.
struct ReportPDFPage: View {
    let report: MonthlyReport

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: "PHINANZ")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tint)
                    Text("Monthly Report \(report.month.start.formatted(.dateTime.month(.wide).year()))")
                        .font(.title2.bold())
                }
                Spacer()
                Text(Date().formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ReportHeaderCard(report: report)
            if !report.insights.isEmpty { ReportInsightsCard(report: report) }
            ReportComparisonCard(report: report)
            Text("Created with PHINANZ on this iPhone. Your data never left the device.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        // Natural height; the renderer scales it down to fit one A4 page.
        .frame(width: ReportPDF.pageSize.width, alignment: .top)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color(uiColor: .systemGroupedBackground))
        .environment(\.colorScheme, .light)
    }
}

enum ReportPDF {
    /// A4 in points.
    static let pageSize = CGSize(width: 595, height: 842)

    enum PDFError: LocalizedError {
        case renderFailed
        var errorDescription: String? { String(localized: "The PDF could not be created.") }
    }

    @MainActor
    static func write(_ report: MonthlyReport) throws -> URL {
        let renderer = ImageRenderer(content: ReportPDFPage(report: report))
        renderer.proposedSize = ProposedViewSize(width: pageSize.width, height: nil)
        let data = NSMutableData()
        var failed = true
        renderer.render { size, draw in
            var box = CGRect(origin: .zero, size: pageSize)
            guard let consumer = CGDataConsumer(data: data as CFMutableData),
                  let pdf = CGContext(consumer: consumer, mediaBox: &box, nil)
            else { return }
            pdf.beginPDFPage(nil)
            // Page background, then the content scaled down to fit and centred.
            pdf.setFillColor(UIColor.systemGroupedBackground.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)).cgColor)
            pdf.fill(box)
            let scale = min(1, pageSize.height / max(size.height, 1), pageSize.width / max(size.width, 1))
            pdf.translateBy(x: (pageSize.width - size.width * scale) / 2, y: pageSize.height - size.height * scale)
            pdf.scaleBy(x: scale, y: scale)
            draw(pdf)
            pdf.endPDFPage()
            pdf.closePDF()
            failed = false
        }
        guard !failed else { throw PDFError.renderFailed }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM"
        return try DataProtection.writeExport(data as Data, named: "Report-\(formatter.string(from: report.month.start)).pdf")
    }
}
