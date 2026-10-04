# Test plan

## Strategy

Most risk sits in pure logic (money parsing, date handling, AI output) and in a few user flows. The pyramid is therefore unit-heavy, with a thin UI layer and a manual device checklist for what simulators cannot cover.

| Area | Type | Where | Target |
| --- | --- | --- | --- |
| Money parsing/formatting | Unit | `MoneyTests` | All input formats, rejection of bad input |
| Year calendar, grouping, entry dates | Unit | `YearCalendarTests` | Leap years, index round trip |
| Statistics | Unit | `ExpenseStatsTests` | Totals, categories, store merging, monthly slots |
| CSV export | Unit | `CSVExporterTests` | Format, quoting, formula neutralisation |
| Gemini request/response | Unit | `GeminiServiceTests` | Key only in header, model validation, fences, bad rows dropped |
| Draft conversion + duplicates | Unit | `DraftExpenseTests` | Date/time fallback rules, validation |
| Image downscaling | Unit | `ImageEncodingTests` | Max dimension respected |
| Income, net, balance | Unit | `IncomeTests` | Spending/income separation, balance cut-off date, AI income type |
| Budgets | Unit | `BudgetTests` | Levels, threshold crossing, month filter |
| Recurring payments | Unit | `RecurringTests` | Clamping, catch-up, start date, cap, idempotent run |
| Widget snapshot | Unit | `WidgetSnapshotTests` | Today / month / balance numbers |
| Backup and restore | Unit | `BackupTests` | Round trip, version check, invalid rows dropped |
| Reminders and deep links | Unit | `ReminderTests` | Evening-before dates, horizon, `phinanz://` URLs |
| Category suggestions | Unit | `CategorySuggesterTests` | History wins, German merchant keywords, unknown stores |
| Launch, tab bar, settings, add entry | UI | `PhbankUITests` | Critical happy paths |
| Camera, microphone, Face ID, real Gemini call | Manual | below | Hardware or secrets required |

Coverage goal: 90 %+ of `Services/` and `Models/`, UI covered by flows rather than percentages. Skip tests for trivial getters and framework behaviour.

## Not covered by automation (do manually on a real device)

1. **Face ID**: enable in Settings → background the app → reopen → unlock; cancel the prompt → app stays locked; remove the passcode → lock is skipped, toggle disabled.
2. **Microphone**: first-use permission prompt; deny → clear message; record 5 s, analyse → review screen; recording file is gone afterwards.
3. **Camera scan**: scan a real receipt → review screen; cancel the scanner → nothing happens.
4. **Gemini end-to-end** (with your own key): voice note in German and English, a receipt photo, a bank-statement PDF with several debits. Check amounts, dates, categories. Re-import the same statement → rows flagged as duplicates and unchecked.
5. **Failure modes**: airplane mode, wrong API key (HTTP 400/403), model name typo, 20 MB PDF.
6. **Accessibility**: VoiceOver reads each entry as "store, amount, category, time"; Dynamic Type at the largest sizes; Reduce Motion stops the loader.
7. **Languages**: switch the iPhone to Deutsch and فارسی; check every screen for untranslated text, clipped labels and right-to-left layout.
8. **Widget**: add small, medium and Lock Screen widgets; add an entry in the app and check the widget updates; check it shows zero for "today" after midnight.
9. **Recurring**: create a payment with a start date three months ago and check exactly three entries appear; reopen the app → no duplicates.
10. **Export**: share the CSV to Files and open it in Numbers/Excel (German locale): columns split, decimals correct, umlauts intact.
11. **Backup**: back up, delete all data, restore the file → every entry, budget and recurring payment is back; restoring the same file twice gives the same result (restore replaces, it does not add).
12. **Reminders**: switch on the daily reminder (allow notifications) and check it fires; a recurring payment due tomorrow gives a notice at 18:00 today.
13. **Siri & Shortcuts**: "Add an expense in PHINANZ" in all three languages; the Shortcuts app lists the actions; Spotlight shows them.
14. **Control Center**: add the "New Entry" control; tapping it opens the editor for today.
15. **iPad**: the tab bar turns into a sidebar; sheets and the editor fit.

## Visual QA with the snapshot renderer

Debug builds contain `Debug/SnapshotRenderer.swift`. When the folder `snapshots/` next to the Xcode project contains a file named `REQUEST`, running the app in the simulator renders about 20 screens (light, dark, German, Persian, empty and busy days) as PNG files into that folder and writes `log.txt`. Delete `REQUEST` to switch it off; release builds never include the renderer. The folder is ignored by git.

## Example edge cases worth keeping in mind

- Entry at 23:59 on 31 December and one at 00:00 on 1 January land on the right pages.
- Switching the device time zone or locale does not lose or move entries.
- 30+ entries on one day stay scrollable and editable.
- Deleting all data empties every page and the summary shows its empty state.

## Running

- Xcode: **Cmd+U**.
- CLI: `xcodebuild test -scheme Phbank -destination 'platform=iOS Simulator,name=iPhone 16'` (pick any installed simulator).
