//
//  AppSettings.swift
//  Phinanz
//

import Foundation

enum SettingsKeys {
    static let lockEnabled = "lockEnabled"
    static let aiConsent = "aiConsent"
    static let geminiModel = "geminiModel"
    /// Keychain account name for the Gemini API key (never stored in UserDefaults).
    static let apiKeyAccount = "geminiAPIKey"
    static let startingBalance = "startingBalance"
    static let didOnboard = "didOnboard"
    static let dailyReminder = "dailyReminder"
    static let dailyReminderMinutes = "dailyReminderMinutes"
    static let paymentReminders = "paymentReminders"
    /// Widgets show "•••" instead of amounts, and no numbers are shared with them.
    static let widgetHideAmounts = "widgetHideAmounts"
    static let iCloudSync = "iCloudSync"
    static let lastAccountID = "lastAccountID"

    /// Face ID / passcode lock; offered during onboarding, off until the user turns it on.
    static var lockEnabledValue: Bool {
        UserDefaults.standard.object(forKey: lockEnabled) as? Bool ?? false
    }
}

enum AppEnvironment {
    /// UI tests launch with `-UITests`: in-memory store, sample data, no lock.
    /// Only honoured in debug builds, so a release build can never be started
    /// without the lock or with test data.
    /// Debug builds only: a scripted demo tour is being recorded (in-memory showcase data, no lock).
    static var isDemo: Bool {
        #if DEBUG
        DebugFlags.isDemo
        #else
        false
        #endif
    }

    static var isUITest: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-UITests")
        #else
        false
        #endif
    }
}
