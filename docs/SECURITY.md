# Security and privacy

PHINANZ holds a person's complete financial picture, so it is built like a banking app: local-first, locked, and with nothing leaving the device unless the user explicitly sends it.

## Threat model

| Threat | Example | Protection |
| --- | --- | --- |
| Someone picks up the unlocked iPhone | A friend opens the app | Face ID / passcode lock, locks on every background; turning the lock off or deleting all data needs Face ID again |
| Shoulder surfing in the app switcher | Multitasking view shows balances | Privacy cover in its own window above sheets and alerts while the app is inactive |
| Lock bypass through a sheet or link | `phinanz://add` opens the editor over the lock | The lock lives in a separate window at alert level; deep links and Siri actions wait until the app is unlocked |
| Locked iPhone, Siri | "How much did I spend today?" on a locked phone | All App Intents use `authenticationPolicy = .requiresAuthentication` |
| Lock Screen widgets | Amounts visible on the Lock Screen | Amounts are `privacySensitive` (redacted while locked); "Hide Amounts in Widgets" stops sharing any numbers with the widget |
| Stolen device / forensic copy | Reading the database from a backup or a locked phone | SwiftData store and its journals use `FileProtectionType.completeUnlessOpen`; shared files use `.complete` and are deleted when the app goes to the background |
| Leaked backup file | Backup in a shared cloud folder | Optional password protection: PBKDF2-SHA256 (600,000 rounds, random 16-byte salt) → AES-256-GCM; the header is authenticated, wrong passwords and changed bytes are detected |
| Malicious backup / CSV | Huge file, absurd values, formula injection | Size limits (backup 50 MB, CSV 5 MB, 5,000 rows), amount and length limits, round count capped, CSV export neutralises `= + - @` |
| Network interception | Proxy on public Wi-Fi | HTTPS only (ATS), TLS 1.2+, ephemeral `URLSession` without cache, cookies or credential storage; API key sent as a header, never in a URL |
| AI prompt injection | A receipt says "ignore previous instructions" | Files are treated as data in the prompt; output is sanitised and must pass the review screen before anything is saved |
| API key theft | Key in UserDefaults or logs | Key only in the Keychain, `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` (not in backups, not synced) |
| Debug switches in production | `-UITests` launch argument disables the lock | Only honoured in DEBUG builds; the snapshot renderer is DEBUG-only |
| Notifications on the Lock Screen | "Rent €720 tomorrow" | Reminders show the payment name, never the amount |

## Data flows

- **Stays on the device:** everything by default — entries, accounts, budgets, goals, reports, bank CSV imports, PDF reports.
- **Leaves the device only on request:**
  - AI import: the one file the user picked → Google Gemini API.
  - Backup / CSV / PDF export: through the share sheet, to wherever the user sends it.
  - iCloud sync (opt-in, needs the iCloud capability): the private CloudKit database of the user's Apple Account.
- **Never:** analytics, ads, tracking, accounts, third-party SDKs.

## Privacy manifest

`PrivacyInfo.xcprivacy` (app and widget) declares no tracking, no tracking domains and the required-reason APIs used: `UserDefaults` (CA92.1 own app, 1C8F.1 App Group) and file timestamps (C617.1, files inside the app container).

## Checklist for every change

- New screen showing amounts? It is covered by the lock window automatically; check it doesn't open from a deep link while locked.
- New file written? Use `DataProtection.writeExport` (complete protection, cleaned up on background).
- New network call? Use an ephemeral session, HTTPS only, no secrets in URLs, and document it here and in the App Privacy label.
- New App Intent? Set `authenticationPolicy = .requiresAuthentication` if it reads or writes money data.
- New import format? Size and row limits, sanitise every field, show the review screen.
