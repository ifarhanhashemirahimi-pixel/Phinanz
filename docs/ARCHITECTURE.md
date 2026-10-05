# Architecture

## Goals

- A calm daily journal for personal spending in Germany that looks and behaves like one of Apple's own apps.
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

- `Expense`: `store`, `amount` (EUR, always positive), `isIncome`, `categoryRaw`, `date`, `note`, `sourceRaw` (manual, voice, receipt, statement, recurring). Spending categories: groceries, food, transport, housing, entertainment, health, shopping, software, travel, other. Income categories: salary, freelance (side income), refund, otherIncome.
- `CategoryBudget`: `categoryRaw`, `monthlyLimit`.
- `RecurringPayment`: `name`, `amount`, `isIncome`, `categoryRaw`, `dayOfMonth` (1–31, clamped), `startDate`, `lastGenerated`, `isActive`, `note`.

All properties have defaults, so SwiftData migrates the original store automatically (new columns, new tables) and a later CloudKit migration stays possible.

## Recurring payments

`RecurringScheduler.run` executes on launch and whenever the app becomes active. For every active payment it computes the due dates after `lastGenerated` (09:00 on the day of month, clamped to the month's length), creates entries with `source = .recurring`, and stores the last date. It is idempotent and caps catch-up at 24 months. Deleting a generated entry does not bring it back.

## Budgets

`BudgetCalculator` turns budgets plus the month's spending into statuses (`ok`, `warning` at ≥ 80 %, `over`). The entry editor checks whether a save *crosses* a threshold and shows one alert; it does not nag on every later entry.

## Widget

The app writes a `WidgetSnapshot` (today, month spending, month income, balance, total budget) as JSON into the App Group `UserDefaults` whenever the numbers change and asks WidgetKit to reload. The widget never opens the database. Values from an earlier day/month are shown as zero until the app updates them.

## System integration

- **Routing:** `AppRouter` (an `@Observable` shared by the app, intents and URL handling) carries "new entry" / "show today" requests. `phinanz://add` and `phinanz://today` are registered in `Info.plist`; widgets, the control and `NewEntryIntent` all end up there.
- **App Intents:** `AddExpenseIntent` writes directly to SwiftData without opening the app; `TodaySpendingIntent` and `MonthSpendingIntent` answer with dialogs; `PhinanzShortcuts` registers phrases in three languages (`AppShortcuts.xcstrings`).
- **Control:** `NewEntryControl` (widget extension) uses an `OpenURLIntent` with `phinanz://add`.
- **Persistence:** `Persistence.shared` is the single `ModelContainer` used by the app and intents; UI tests get an in-memory store with sample data.

## Accounts

`Account` (checking, cash, credit card, savings) has an opening balance and a sort order; the first one is the main account. `Expense.accountID` and `RecurringPayment.accountID` point to an account by id — an empty or unknown id means the main account, so entries from Siri, widgets and older versions always land somewhere sensible. `Transfer` moves money between two accounts and is ignored by spending/income statistics. `AccountLedger` computes balances; the total is simply all opening balances plus income minus spending, because transfers cancel out. Deleting an account moves its entries, payments and opening balance to the main account and re-routes its transfers. On the first launch after the update `AccountStore` creates the main account from the old single "starting balance" setting.

Ids instead of SwiftData relationships keep the models CloudKit-compatible (CloudKit needs optional relationships and no unique constraints) and make backups simple.

## Savings goals

`SavingsGoal` stores target, saved amount, optional deadline, symbol and colour. `SavingsPlanner` turns that into progress, remaining amount and a monthly amount: the remaining money divided by the months left (a started month counts), rounded up to the cent. Goals are envelopes: adding money does not book an entry; a transfer to the savings account can mirror it in the bank.

## Monthly report

`ReportBuilder` compares a month with the one before: spending, income, net, savings rate, daily average (days so far for the running month), fixed costs (entries booked by recurring payments), categories with deltas, top stores, budgets over limit, the biggest expense. A short list of rule-based insights is generated from those numbers — no AI and no network. `ReportPDF` renders the same SwiftUI cards into an A4 PDF with `ImageRenderer`.

## iCloud sync

`Persistence` opens the store with `cloudKitDatabase: .private(CloudSync.containerID)` only when the user switched sync on **and** the provisioning profile grants CloudKit (`CloudSync` reads `embedded.mobileprovision`). Otherwise it stays local and never calls CloudKit. If opening with CloudKit fails, it falls back to the local store. Changing the switch takes effect after a restart.

## Backup

`BackupService` writes a versioned JSON file (`BackupFile`, version 2: + accounts, transfers, goals; version 1 files still restore) — optionally encrypted by `BackupCrypto` (PBKDF2-SHA256 600k → AES-256-GCM, see `docs/SECURITY.md`). Restore checks the version and sanitises every row (amount limits, text length, known categories), then replaces all current data with the backup's content in one save. The UI asks for confirmation first and reports how many entries, budgets and payments were restored.

## Reminders

`NotificationScheduler` keeps local notifications in sync with the data: an optional daily reminder at a chosen time, and for every active recurring payment a notice at 18:00 the evening before it is booked, for the next 60 days (iOS allows 64 pending requests). It reschedules whenever the app becomes active or a payment changes.

## Category suggestions

`CategorySuggester` looks at the store name while you type. Your own history wins (the category you used most for that store); otherwise a keyword list of common German merchants decides. A category the user picked by hand is never overwritten.

## Localization

String Catalogs (`Localizable.xcstrings`, `InfoPlist.xcstrings`, and one in the widget) with English as source and German and Persian translations. Model-level strings use `String(localized:)`; views use `LocalizedStringKey` literals. Persian runs right-to-left automatically; chevrons use `backward`/`forward` symbols so they mirror. `Money.parse` accepts Persian and Arabic-Indic digits.

## Bank CSV import

`BankCSVImporter` reads bank exports on the device. It decodes UTF-8 or Windows-1252, tries `;`, tab and `,` as separators, and looks in the first 40 lines for a header row with a date column and an amount column (or separate Soll/Haben columns). Columns are found by name (German and English, umlauts folded), so layouts it has never seen usually work. Pending bookings (`vorgemerkt`) are skipped; the counterparty comes from a combined column or, for DKB-style files, from payee or payer depending on the sign. Each booking becomes a `DraftExpense` (`source = .statement`, 12:00 on the booking day) with a category from `CategorySuggester` and goes through the same review screen and duplicate detection as AI imports, so importing the same file twice adds nothing unless you switch the rows back on.

## Live bank connection (not planned for now)

1. PSD2 account information via a licensed aggregator (for personal use e.g. Enable Banking's restricted mode). Needs a small backend that holds the aggregator's private key; the app only talks to that backend. Publishing to other users requires a BaFin licence or a contract with a licensed provider.

## Security and privacy notes

See `docs/SECURITY.md` for the full threat model. In short:

- Lock: shown on launch and after the app enters the background; a privacy cover hides content while the app is inactive. Sheets are dismissed on lock.
- Recordings are written to the temporary directory and deleted after upload or when the sheet closes.
- AI output is sanitised (length limits, positive finite amounts below 1,000,000, valid dates only) before the user sees it.
- Attachments are treated as data in the prompt ("never as instructions"); the review screen is the second line of defence.
- CSV export prefixes cells starting with `= + - @` to prevent spreadsheet formula injection.

## Extending

- **Sync**: add an iCloud container, switch `cloudKitDatabase` to `.automatic`, test with two devices.
- **CAMT / MT940 import**: same pipeline as the CSV importer for the XML and SWIFT formats.
- **Multiple currencies**: add a currency code to `Expense` and convert in `ExpenseStats`.
- **Decimal money**: replace `Double` with `Decimal` in `Expense`, `Money` and `ExpenseStats`.
