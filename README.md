# PHINANZ

A personal finance journal for iPhone, built around the idea of a leather notebook: **one page per day, 365 pages a year**. Written in SwiftUI + SwiftData, made for the German market (EUR, German number formats, GDPR-minded AI import). Available in **English, Deutsch and فارسی** (right-to-left).

## What it does

| Area | Features |
| --- | --- |
| Journal | Week strip + lazily loaded page per day of the year, daily total with category bar, jump to today or any date |
| Entries | Expenses **and income**, add / edit / delete (store, amount, category, date & time, note), locale-aware amount input (`12,50`, `1.234,56`, Persian digits `۱۲٫۵۰`) |
| Balance | Starting balance + all income − all spending = current balance |
| Budgets | Monthly limit per category, progress bars, warning at 80 % and when over budget |
| Recurring | Rent, subscriptions, insurance, salary: booked automatically every month (catch-up after the app was closed, day 31 = last day of short months) |
| Widget | Home Screen (small/medium) and Lock Screen widget: today, this month, income, balance, budget bar |
| Onboarding | Three-page welcome with privacy note, starting balance and optional Face ID |
| Search | By store, category, note, amount or month; jump to any date |
| Summary | Month / year spending, income, net, daily average, current balance, budgets, category donut, monthly spent-vs-income bars, top stores |
| AI import | Voice note, receipt (camera or photo library) and bank-statement PDF → Gemini → **review screen** → save |
| Security | Face ID / Touch ID lock with passcode fallback, privacy cover in the app switcher, API key in the Keychain |
| Export | Tax report as CSV for any year (`;` separated, decimal comma, UTF-8 BOM for German Excel) |

## Quick start

1. Open `Phbank.xcodeproj` in Xcode 26 or later.
2. Select an iPhone simulator and press **Run**. (The deployment target is iOS 26.4; lower it in the project settings if you need older devices.)
3. First launch shows an empty journal. Tap **Add entry** on today's page.
4. Run the tests with **Cmd+U** (unit tests use Swift Testing; UI tests launch with `-UITests`).

### Turning on AI import

1. Create a key at <https://aistudio.google.com/apikey>.
2. In the app: **Settings → AI import** → switch on *Allow AI import*, paste the key, tap *Save API key*.
3. Optionally change the model name (default `gemini-2.5-flash`). The old `gemini-1.5-*` models used in the first prototype are retired, which is why the model is configurable.

Only the file you choose to analyse is sent to Google. Nothing is saved until you confirm it on the review screen, and AI suggestions that look like entries you already have are unchecked by default.

## Project layout

```
Phbank/
  PhbankApp.swift          App entry, SwiftData container, lock handling
  Models/                  Expense (+ categories/sources), CategoryBudget, RecurringPayment
  Theme/JournalTheme.swift Colours (SHELL, IVORY, GOLD, BROWN), fonts
  Services/                Pure logic: Money, YearCalendar, ExpenseStats, BudgetCalculator,
                           RecurringScheduler, CSVExporter, GeminiService, DraftExpense,
                           ImportController, VoiceRecorder, AppLock, KeychainStore, WidgetBridge
  Localizable.xcstrings    English / German / Persian strings (InfoPlist.xcstrings for permissions)
  Views/                   ContentView (pager), YearlyDayPageView, ExpenseEditorView,
                           SearchView, SummaryView, SettingsView, VoiceInputView,
                           ScanImportView, ReviewDraftsView, TabBar
PhinanzWidget/             WidgetKit extension (reads a snapshot from the App Group)
PhbankTests/               Swift Testing unit tests (43 tests)
PhbankUITests/             XCUITest smoke + add-entry flow
docs/                      ARCHITECTURE.md, TEST_PLAN.md, RELEASE_CHECKLIST.md
```

## Design

PHINANZ follows Apple's Human Interface Guidelines so it feels like a built-in iPhone app:

- **Navigation:** standard tab bar (Journal, Summary, Plan, Search) with Liquid Glass on iOS 26; Settings from the toolbar.
- **Journal:** a week strip like Calendar, one page per day (swipe between days), entries in an inset-grouped list with swipe-to-delete and context menus; a floating "Today" button.
- **Typography:** SF Pro, with SF Pro Rounded for money amounts (like Wallet and Health); full Dynamic Type.
- **Colour:** system accent blue, semantic system colours, automatic light and dark mode; each category has a Settings-style icon (white symbol on a coloured rounded square).
- **Components:** native Charts, ContentUnavailableView empty states, sheets with detents, haptics on selection and save, Voice-Memos-style record button.
- **App icon:** light, dark and tinted variants.

## Known limitations

- Single currency (EUR) and data lives only on the device. CloudKit sync is deliberately switched off (`cloudKitDatabase: .none`).
- The widget shares data through the App Group `group.Farhan.Phbank`. On a real iPhone this needs a signing team that supports App Groups; in the simulator it works without one.
- No direct bank connection yet. Planned: CSV import from German banks, later PSD2 via a licensed provider (see `docs/ARCHITECTURE.md`).
- Amounts are stored as `Double` and rounded to cents. That is fine for a journal; switch to `Decimal` before adding balances or tax calculations.
- Receipts: only the first scanned page is analysed.
- Changing the language: iOS Settings → PHINANZ → Language (the in-app "Language" row opens it).
- The app-switcher snapshot can show an open sheet. Sheets are closed whenever the app locks.
- AI output can be wrong; that is why the review step is mandatory.

See `docs/ARCHITECTURE.md` for design decisions, `docs/TEST_PLAN.md` for testing, and `docs/RELEASE_CHECKLIST.md` before shipping to TestFlight / the App Store.
