//
//  AppSettings.swift
//  Phbank
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

    /// Face ID / passcode lock; offered during onboarding, off until the user turns it on.
    static var lockEnabledValue: Bool {
        UserDefaults.standard.object(forKey: lockEnabled) as? Bool ?? false
    }
}

enum AppEnvironment {
    /// UI tests launch with `-UITests`: in-memory store, sample data, no lock.
    static var isUITest: Bool {
        ProcessInfo.processInfo.arguments.contains("-UITests")
    }
}
