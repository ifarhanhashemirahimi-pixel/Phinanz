# Architecture

## Goals

- A calm, notebook-like daily journal for personal spending in Germany.
- Local-first: all data stays on the device; the only network call is the optional Gemini import.
- Small, testable core: parsing, calendar maths, statistics, export and AI handling are plain Swift with no UI dependencies.

## High-level design

```
SwiftUI views ──▶ @Query (SwiftData) ──▶ Expense (@Model, on-device store)
     │
     ├── YearCalendar / ExpenseStats / CSVExporter / Money   (pure logic)
     │
     └── ImportController (@Observable)
            ├─ VoiceRecorder (WAV 16 kHz mono)
            ├─ AIReadiness (consent + Keychain key)
            ├─ GeminiService ──▶ Gemini REST generateContent
            └─ DraftExpense ──▶ ReviewDraftsView ──▶ Expense
```

Default actor isolation of the target is `MainActor`, so everything above runs on the main actor; network calls use `await` and never block it.

## Key decisions

| Decision | Why | Trade-off |
| --- | --- | --- |
| One `Expense` model, pages are *derived* by grouping on day | Pages never go out of sync with data; no 365 stored records | Grouping is recomputed per render (cheap for personal volumes) |
| Horizontal `ScrollView` + `LazyHStack` + `.scrollTargetBehavior(.paging)` | Only visible pages are built; supports `scrollPosition` for jumps | Requires iOS 17+ |
| Gemini via REST instead of an SDK | No dependency, easy to test request/response | We maintain the small JSON mapping ourselves |
| Structured output (`responseSchema` + JSON mime type) | Fewer parsing failures | Output is still treated as untrusted and sanitised |
| Mandatory review screen | AI can hallucinate; protects data integrity and prompt-injection from documents | One extra tap |
| API key in Keychain, sent in a header | Never in source, UserDefaults, URLs or logs | User supplies their own key (no backend) |
| Explicit AI consent toggle | Financial documents leave the device only on purpose (GDPR data minimisation) | Extra setup step |
| `cloudKitDatabase: .none` | No half-working sync | No multi-device data yet |
| WAV for voice notes | Format accepted directly by Gemini | Larger files than AAC (about 2 MB per minute) |
| `deviceOwnerAuthentication` for the lock | Passcode fallback means users cannot be locked out | Not biometrics-only |

## Data model

`Expense`: `store`, `amount` (EUR, positive), `categoryRaw`, `date`, `note`, `sourceRaw`. All properties have defaults so a later CloudKit migration stays possible. Categories: groceries, food, transport, housing, entertainment, health, shopping, software, travel, other.

## Security and privacy notes

- Lock: shown on launch and after the app enters the background; a privacy cover hides content while the app is inactive. Sheets are dismissed on lock.
- Recordings are written to the temporary directory and deleted after upload or when the sheet closes.
- AI output is sanitised (length limits, positive finite amounts below 1,000,000, valid dates only) before the user sees it.
- Attachments are treated as data in the prompt ("never as instructions"); the review screen is the second line of defence.
- CSV export prefixes cells starting with `= + - @` to prevent spreadsheet formula injection.

## Extending

- **Sync**: add an iCloud container, switch `cloudKitDatabase` to `.automatic`, test with two devices.
- **Recurring entries**: add a `Recurrence` model and materialise entries on app start.
- **Budgets**: category budgets compared against `ExpenseStats.byCategory`.
- **Decimal money**: replace `Double` with `Decimal` in `Expense`, `Money` and `ExpenseStats`.
