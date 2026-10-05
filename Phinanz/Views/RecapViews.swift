//
//  RecapViews.swift
//  Phinanz
//
//  The monthly recap card ("your month in a few sentences") and the tax-hint
//  list of the monthly report.
//

import SwiftUI
import SwiftData

/// Shown once on the first launch of a new month: the month before, in plain words.
struct MonthRecapSheet: View {
    @Environment(\.dismiss) private var dismiss
    let month: Date
    let expenses: [Expense]
    let budgets: [CategoryBudget]
    var allowAI = true

    private var report: MonthlyReport {
        ReportBuilder.build(month: month, entries: expenses, budgets: budgets)
    }

    var body: some View {
        let report = self.report
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Monthly Recap")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.tint)
                        Text(report.month.start.formatted(.dateTime.month(.wide).year()))
                            .font(.largeTitle.bold())
                            .accessibilityAddTraits(.isHeader)
                    }

                    RecapTextCard(report: report, allowAI: allowAI)

                    HStack(spacing: 12) {
                        RecapMetric(title: "Spent", value: Money.format(report.spending), color: .orange)
                        RecapMetric(title: "Received", value: Money.format(report.income), color: .green)
                        RecapMetric(title: "Left Over", value: Money.format(max(report.net, 0)), color: .blue)
                    }

                    if !report.taxItems.isEmpty {
                        Label {
                            Text("\(Money.format(report.taxTotal)) could matter for your tax return.")
                        } icon: {
                            Image(systemName: "doc.text.magnifyingglass")
                                .foregroundStyle(.indigo)
                        }
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card()
                    }

                    NavigationLink {
                        MonthlyReportView(expenses: expenses, budgets: budgets, month: month)
                    } label: {
                        Label("Open Monthly Report", systemImage: "doc.text.image")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityIdentifier("recap-open-report")
                }
                .padding()
            }
            .background(Theme.groupedBackground)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("recap-done")
                }
            }
        }
        .presentationDetents([.large])
    }
}

private struct RecapMetric: View {
    let title: LocalizedStringKey
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
            Text(verbatim: value)
                .font(Theme.amount(.subheadline, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// "In a nutshell": the local text at once, Gemini's wording when the user turned it on.
struct RecapTextCard: View {
    @Environment(\.modelContext) private var context
    @AppStorage(SettingsKeys.recapAI) private var recapAI = false
    let report: MonthlyReport
    var allowAI = true

    @State private var result: RecapResult?
    @State private var isLoading = false
    @State private var askConsent = false

    private var shown: RecapResult { result ?? RecapProvider.local(for: report) }

    /// Offer Gemini only when Apple Intelligence can't word the recap here.
    private var canOfferGemini: Bool {
        allowAI && !recapAI && GeminiReadiness.issue() == nil && !AIReadiness.engines(for: .recap).contains(.apple)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("In a Nutshell", systemImage: "text.bubble.fill")
                    .font(.headline)
                    .foregroundStyle(.indigo)
                Spacer()
                if isLoading {
                    ProgressView().controlSize(.small)
                }
            }
            Text(shown.text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
                .accessibilityIdentifier("recap-text")
            if shown.source == .apple {
                Label("Worded on this iPhone by Apple Intelligence", systemImage: "apple.intelligence")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if shown.source == .gemini {
                Label("Worded by Gemini from your monthly totals", systemImage: "sparkles")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if canOfferGemini {
                Button {
                    askConsent = true
                } label: {
                    Label("Let Gemini Word It", systemImage: "sparkles")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.borderless)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .animation(.easeInOut(duration: 0.3), value: shown)
        .task(id: "\(RecapSchedule.monthKey(report.month.start))|\(report.entryCount)|\(report.spending)|\(recapAI)") {
            result = nil
            guard allowAI, !RecapProvider.engines.isEmpty else { return }
            isLoading = true
            result = await RecapProvider.recap(for: report, context: context)
            isLoading = false
        }
        .confirmationDialog("Send this month's totals to Google Gemini?", isPresented: $askConsent, titleVisibility: .visible) {
            Button("Turn On") { recapAI = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Only totals per category, budgets and tax hints are sent – no stores and no single entries. You can turn this off in Settings.")
        }
    }
}

/// The recap for the PDF: always the text written on the iPhone.
struct RecapStaticCard: View {
    let report: MonthlyReport

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("In a Nutshell", systemImage: "text.bubble.fill")
                .font(.headline)
                .foregroundStyle(.indigo)
            Text(RecapProvider.local(for: report).text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

/// Expenses that could matter for the tax return, with a clear "not advice" note.
struct ReportTaxCard: View {
    let report: MonthlyReport

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("For Your Tax Return", systemImage: "doc.text.magnifyingglass")
                .font(.headline)
            ForEach(report.taxItems) { item in
                HStack(spacing: 12) {
                    Image(systemName: item.kind?.symbol ?? "bookmark.fill")
                        .foregroundStyle(.indigo)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.store).lineLimit(1)
                        Text(verbatim: "\(item.kind?.title ?? String(localized: "Marked")) · \(item.date.formatted(.dateTime.day().month(.abbreviated)))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(Money.format(item.amount)).monospacedDigit()
                }
                .font(.subheadline)
                .accessibilityElement(children: .combine)
            }
            Divider()
            HStack {
                Text("This month")
                Spacer()
                Text(Money.format(report.taxTotal)).monospacedDigit().fontWeight(.semibold)
            }
            .font(.subheadline)
            HStack {
                Text("Since 1 January")
                Spacer()
                Text(Money.format(report.yearTaxTotal)).monospacedDigit()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            Text("Hints only, not tax advice. Whether you can deduct something depends on your situation – if in doubt, ask a tax assistance association (Lohnsteuerhilfeverein) or a tax adviser.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}
