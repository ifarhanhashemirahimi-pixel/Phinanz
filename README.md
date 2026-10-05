# PHINANZ

A personal finance journal for iPhone and iPad: **one page per day**, in the style of Apple's own apps. Written in SwiftUI + SwiftData, made for the German market (EUR, German number formats, GDPR-minded AI import). Available in **English, Deutsch and فارسی** (right-to-left), in light and dark mode.

## What it does

| Area | Features |
| --- | --- |
| Journal | Week strip like Calendar, a page per day (swipe between days), daily total with category bar, floating "Today" button, title menu to jump to any date |
| Entries | Expenses **and income**, add / edit / delete (store, amount, category, date & time, note), locale-aware amount input (`12,50`, `1.234,56`, Persian digits `۱۲٫۵۰`) |
| Smart categories | Typing a store picks its category automatically: first from your own history, then from known German merchants (REWE, DB, Netflix, Miete …) |
| Accounts | Checking account, cash, credit card, savings — each with its own balance; transfers between accounts (ATM, savings) that don't count as spending; entries, recurring payments and CSV imports go to the account you pick |
| Savings goals | Target, saved so far, optional date → progress ring and "€150 a month until April"; add or withdraw money |
| Monthly report | Month vs. previous month by category, savings rate, fixed costs, plain-language insights ("You spent 12 % less than in September"), PDF to share or print |
| Budgets | Monthly limit per category, progress bars, warning at 80 % and when over budget |
| Recurring | Rent, subscriptions, insurance, salary: booked automatically every month (catch-up after the app was closed, day 31 = last day of short months) |
| Reminders | Optional daily "write down today's spending" reminder and a heads-up the evening before a recurring payment is booked |
| Siri & Shortcuts | "Add an expense in PHINANZ", "How much did I spend today", "… this month", "New entry" — all in English, German and Persian |
| Widgets & Controls | Home Screen (small/medium) and Lock Screen widgets with a quick-add button; a Control Center / Action button control that opens a new entry |
| Summary | Week / month / year spending, income, net, balance, stacked bar chart by category, categories with share bars, top stores |
| Search | By store, category, note, amount or month |
| Bank CSV import | CSV export from Sparkasse, ING, DKB, N26, Commerzbank, comdirect, Volksbank, Postbank and others → **review screen** → save. Read on the device: no AI, no network, no API key; categories suggested, duplicates switched off |
| AI import | Voice note, receipt (camera, document scanner or photo library) and bank-statement PDF → Gemini → **review screen** → save |
| Backup | Full backup (entries, accounts, transfers, budgets, recurring payments, goals), **password-protected with AES-256**, restore with confirmation; CSV export for the tax return |
| Security | Face ID lock in its own window above every sheet, privacy cover in the app switcher, Siri needs an unlocked iPhone, widgets can hide amounts, iOS Data Protection for the database, ephemeral network session, privacy manifest — see `docs/SECURITY.md` and Settings → Security & Privacy |
| iCloud sync | Optional, through the private CloudKit database (needs the iCloud capability, see below) |
| Help | Onboarding with privacy note and starting balance; TipKit tips for swiping days and AI import |

## Quick start

1. Open `Phinanz.xcodeproj` in Xcode 26 or later.
2. Select an iPhone simulator and press **Run**. (The deployment target is iOS 26.4; lower it in the project settings if you need older devices.)
3. The onboarding asks for a starting balance; then tap **+** to add your first entry.
4. Run the tests with **Cmd+U** (unit tests use Swift Testing; UI tests launch with `-UITests` in English and an in-memory store with sample data).

### Turning on AI import

1. Create a key at <https://aistudio.google.com/apikey>.
2. In the app: **Settings → AI Import** → switch on *Allow AI import*, paste the key, tap *Save API key*.
3. Optionally change the model name (default `gemini-2.5-flash`).

Only the file you choose to analyse is sent to Google. Nothing is saved until you confirm it on the review screen, and AI suggestions that look like entries you already have are unchecked by default.

### Turning on iCloud sync (optional)

Sync needs a paid Apple Developer account, because CloudKit is not available to personal teams.

1. Target **Phinanz** → Signing & Capabilities → choose your team.
2. **+ Capability → iCloud** → tick **CloudKit** → add the container `iCloud.Farhan.Phinanz` (or change `CloudSync.containerID` to yours).
3. **+ Capability → Background Modes** → tick **Remote notifications**.
4. Run on a device signed in to iCloud, then Settings → iCloud Sync → reopen the app.

Without the capability the switch stays disabled and PHINANZ never touches CloudKit.

### Deep links

- `phinanz://add` opens a new entry for today.
- `phinanz://today` shows today's page.

## Project layout

```
Phinanz/
  PhinanzApp.swift          App entry, lock handling, TipKit
  Models/                  Expense (+ categories/sources), CategoryBudget, RecurringPayment, AppSchema
  Theme/Theme.swift        Semantic colours, category icons, card style
  Models/                  + Account, Transfer, SavingsGoal
  Services/                Pure logic and side effects:
                           Money, YearCalendar, ExpenseStats, BudgetCalculator, RecurringScheduler,
                           AccountLedger, SavingsPlanner, MonthlyReport, CategorySuggester,
                           BankCSVImporter, CSVExporter, BackupService, BackupCrypto, NotificationScheduler,
                           GeminiService, DraftExpense, ImportController, VoiceRecorder,
                           AppLock, PrivacyShield, DataProtection, KeychainStore, CloudSync,
                           WidgetBridge, AppRouter, Persistence, SampleData
  Intents/                 App Intents + App Shortcuts (Siri, Spotlight, Shortcuts app)
  Views/                   ContentView (tabs), JournalView, SummaryView, PlanView, SearchView,
                           SettingsView, ExpenseEditorView, BudgetsView, RecurringViews,
                           AccountViews, GoalViews, ReportViews, SecurityViews,
                           OnboardingView, VoiceInputView, ScanImportView, ReviewDraftsView,
                           Overlays (lock, AI progress), Tips
  Debug/SnapshotRenderer   DEBUG-only screenshot tool for visual QA (see docs/TEST_PLAN.md)
  *.xcstrings              English / German / Persian strings (app, Info.plist, App Shortcuts)
PhinanzWidget/             WidgetKit extension: widgets + Control Center control
PhinanzTests/               Swift Testing unit tests (80 tests)
PhinanzUITests/             XCUITest smoke tests + add-entry flow
docs/                      ARCHITECTURE.md, SECURITY.md, TEST_PLAN.md, RELEASE_CHECKLIST.md
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

- Single currency (EUR). Data lives on the device (plus your own backups, and iCloud if you turn sync on).
- The widget shares data through the App Group `group.Farhan.Phinanz`. On a real iPhone this needs a signing team that supports App Groups; in the simulator it works without one.
- No live bank connection: export a CSV from your bank and import it (Import → Bank CSV). A PSD2 connection would need a licensed provider (see `docs/ARCHITECTURE.md`).
- Amounts are stored as `Double` and rounded to cents. Fine for a journal; switch to `Decimal` before tax calculations.
- Receipts: only the first scanned page is analysed.
- Changing the language: iOS Settings → PHINANZ → Language (the in-app "Language" row opens it).
- AI output can be wrong; that is why the review step is mandatory.

See `docs/ARCHITECTURE.md` for design decisions, `docs/SECURITY.md` for the threat model, `docs/TEST_PLAN.md` for testing, and `docs/RELEASE_CHECKLIST.md` before shipping to TestFlight / the App Store.
