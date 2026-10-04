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

    /// Face ID / passcode lock is on unless the user turned it off.
    static var lockEnabledValue: Bool {
        UserDefaults.standard.object(forKey: lockEnabled) as? Bool ?? true
    }
}

enum AppEnvironment {
    /// UI tests launch with `-UITests`: in-memory store, sample data, no lock.
    static var isUITest: Bool {
        ProcessInfo.processInfo.arguments.contains("-UITests")
    }
}
