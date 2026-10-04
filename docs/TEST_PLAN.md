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
7. **Export**: share the CSV to Files and open it in Numbers/Excel (German locale): columns split, decimals correct, umlauts intact.

## Example edge cases worth keeping in mind

- Entry at 23:59 on 31 December and one at 00:00 on 1 January land on the right pages.
- Switching the device time zone or locale does not lose or move entries.
- 30+ entries on one day stay scrollable and editable.
- Deleting all data empties every page and the summary shows its empty state.

## Running

- Xcode: **Cmd+U**.
- CLI: `xcodebuild test -scheme Phbank -destination 'platform=iOS Simulator,name=iPhone 16'` (pick any installed simulator).
