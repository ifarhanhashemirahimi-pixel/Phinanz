//
//  AppLock.swift
//  Phinanz
//
//  Face ID / Touch ID lock with device-passcode fallback.
//

import Foundation
import LocalAuthentication
import Observation

@Observable
final class AppLock {
    var isLocked: Bool
    var isAuthenticating = false

    init(startLocked: Bool) {
        self.isLocked = startLocked
    }

    /// False on devices without a passcode — the lock is skipped there instead of trapping the user.
    static var canAuthenticate: Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    func lockIfNeeded(enabled: Bool) {
        guard enabled, Self.canAuthenticate else { return }
        isLocked = true
    }

    func unlock() async {
        guard isLocked, !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }
        if await Self.authenticate(reason: String(localized: "Unlock your PHINANZ journal")) {
            isLocked = false
        }
    }

    static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return false }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }
}
