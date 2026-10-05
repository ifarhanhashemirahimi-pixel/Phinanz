//
//  PrivacyShield.swift
//  Phbank
//
//  Shows the lock screen (or the privacy cover in the app switcher) in its own
//  window above everything else — sheets, alerts and menus included — so no
//  open screen can float above the lock or leak into the app-switcher snapshot.
//

import SwiftUI
import UIKit

@MainActor
final class PrivacyShield {
    static let shared = PrivacyShield()

    private var window: UIWindow?

    private init() {}

    func update(visible: Bool, lock: AppLock) {
        visible ? show(lock: lock) : hide()
    }

    private func show(lock: AppLock) {
        if let window {
            window.layer.removeAllAnimations()
            window.alpha = 1
            window.isHidden = false
            return
        }
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive })
            ?? scenes.first(where: { $0.activationState == .foregroundInactive })
            ?? scenes.first
        else { return }

        // Close the keyboard so nothing typed stays visible above the cover.
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        let host = UIHostingController(rootView: LockScreenView(lock: lock))
        host.view.backgroundColor = .systemBackground
        window.rootViewController = host
        window.isHidden = false
        self.window = window
    }

    private func hide() {
        guard let window else { return }
        self.window = nil
        UIView.animate(withDuration: 0.25, animations: { window.alpha = 0 }) { _ in
            window.isHidden = true
        }
    }
}
