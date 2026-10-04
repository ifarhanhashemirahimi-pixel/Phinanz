# PHINANZ

A personal finance journal for iPhone and iPad: **one page per day**, in the style of Apple's own apps. Written in SwiftUI + SwiftData, made for the German market (EUR, German number formats, GDPR-minded AI import). Available in **English, Deutsch and فارسی** (right-to-left), in light and dark mode.

## What it does

| Area | Features |
| --- | --- |
| Journal | Week strip like Calendar, a page per day (swipe between days), daily total with category bar, floating "Today" button, title menu to jump to any date |
| Entries | Expenses **and income**, add / edit / delete (store, amount, category, date & time, note), locale-aware amount input (`12,50`, `1.234,56`, Persian digits `۱۲٫۵۰`) |
| Smart categories | Typing a store picks its category automatically: first from your own history, then from known German merchants (REWE, DB, Netflix, Miete …) |
| Balance | Starting balance + all income − all spending = current balance |
| Budgets | Monthly limit per category, progress bars, warning at 80 % and when over budget |
| Recurring | Rent, subscriptions, insurance, salary: booked automatically every month (catch-up after the app was closed, day 31 = last day of short months) |
| Reminders | Optional daily "write down today's spending" reminder and a heads-up the evening before a recurring payment is booked |
| Siri & Shortcuts | "Add an expense in PHINANZ", "How much did I spend today", "… this month", "New entry" — all in English, German and Persian |
| Widgets & Controls | Home Screen (small/medium) and Lock Screen widgets with a quick-add button; a Control Center / Action button control that opens a new entry |
| Summary | Week / month / year spending, income, net, balance, stacked bar chart by category, categories with share bars, top stores |
| Search | By store, category, note, amount or month |
| AI import | Voice note, receipt (camera, document scanner or photo library) and bank-statement PDF → Gemini → **review screen** → save |
| Backup | Full JSON backup (entries, budgets, recurring payments) to Files / share sheet, restore with confirmation; CSV export for the tax return |
| Security | Face ID / Touch ID lock with passcode fallback, privacy cover in the app switcher, API key in the Keychain |
| Help | Onboarding with privacy note and starting balance; TipKit tips for swiping days and AI import |

## Quick start

1. Open `Phbank.xcodeproj` in Xcode 26 or later.
2. Select an iPhone simulator and press **Run**. (The deployment target is iOS 26.4; lower it in the project settings if you need older devices.)
3. The onboarding asks for a starting balance; then tap **+** to add your first entry.
4. Run the tests with **Cmd+U** (unit tests use Swift Testing; UI tests launch with `-UITests` in English and an in-memory store with sample data).

### Turning on AI import

1. Create a key at <https://aistudio.google.com/apikey>.
2. In the app: **Settings → AI Import** → switch on *Allow AI import*, paste the key, tap *Save API key*.
3. Optionally change the model name (default `gemini-2.5-flash`).

Only the file you choose to analyse is sent to Google. Nothing is saved until you confirm it on the review screen, and AI suggestions that look like entries you already have are unchecked by default.

### Deep links

- `phinanz://add` opens a new entry for today.
- `phinanz://today` shows today's page.

## Project layout

```
Phbank/
  PhbankApp.swift          App entry, lock handling, TipKit
  Models/                  Expense (+ categories/sources), CategoryBudget, RecurringPayment, AppSchema
  Theme/Theme.swift        Semantic colours, category icons, card style
  Services/                Pure logic and side effects:
                           Money, YearCalendar, ExpenseStats, BudgetCalculator, RecurringScheduler,
                           CategorySuggester, CSVExporter, BackupService, NotificationScheduler,
                           GeminiService, DraftExpense, ImportController, VoiceRecorder,
                           AppLock, KeychainStore, WidgetBridge, AppRouter, Persistence, SampleData
  Intents/                 App Intents + App Shortcuts (Siri, Spotlight, Shortcuts app)
  Views/                   ContentView (tabs), JournalView, SummaryView, PlanView, SearchView,
                           SettingsView, ExpenseEditorView, BudgetsView, RecurringViews,
                           OnboardingView, VoiceInputView, ScanImportView, ReviewDraftsView,
                           Overlays (lock, AI progress), Tips
  Debug/SnapshotRenderer   DEBUG-only screenshot tool for visual QA (see docs/TEST_PLAN.md)
  *.xcstrings              English / German / Persian strings (app, Info.plist, App Shortcuts)
PhinanzWidget/             WidgetKit extension: widgets + Control Center control
PhbankTests/               Swift Testing unit tests (53 tests)
PhbankUITests/             XCUITest smoke tests + add-entry flow
docs/                      ARCHITECTURE.md, TEST_PLAN.md, RELEASE_CHECKLIST.md
```

## Design

PHINANZ follows Apple's Human Interface Guidelines so it feels like a built-in app:

- **Navigation:** tab bar with Liquid Glass (Journal, Summary, Plan, and a Search tab in the system search position). The tab bar shrinks while scrolling; on iPad it becomes a sidebar. Settings live in the toolbar.
- **Journal:** week strip like Calendar, one page per day, entries in an inset-grouped list with swipe-to-delete and context menus; empty days show a calm empty state with one button.
- **Typography:** SF Pro, with SF Pro Rounded for money amounts (like Wallet and Health); full Dynamic Type.
- **Colour:** system accent blue, semantic system colours, automatic light and dark mode; each category has a Settings-style icon.
- **Components:** Swift Charts, ContentUnavailableView, sheets with detents, glass buttons, TipKit, haptics, Voice-Memos-style record button, VisionKit document scanner.
- **App icon:** light, dark and tinted variants.

## Known limitations

- Single currency (EUR); data lives only on the device (plus your own backups). CloudKit sync is deliberately switched off.
- The widget shares data through the App Group `group.Farhan.Phbank`. On a real iPhone this needs a signing team that supports App Groups; in the simulator it works without one.
- No direct bank connection yet. Planned: CSV import from German banks, later PSD2 via a licensed provider (see `docs/ARCHITECTURE.md`).
- Amounts are stored as `Double` and rounded to cents. Fine for a journal; switch to `Decimal` before tax calculations.
- Receipts: only the first scanned page is analysed.
- Changing the language: iOS Settings → PHINANZ → Language (the in-app "Language" row opens it).
- AI output can be wrong; that is why the review step is mandatory.

See `docs/ARCHITECTURE.md` for design decisions, `docs/TEST_PLAN.md` for testing, and `docs/RELEASE_CHECKLIST.md` before shipping to TestFlight / the App Store.
