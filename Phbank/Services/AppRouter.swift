//
//  AppRouter.swift
//  Phbank
//
//  Actions requested from outside the UI: deep links from the widget
//  (phinanz://add, phinanz://today) and Siri / Shortcuts.
//

import Foundation
import Observation

@Observable
final class AppRouter {
    enum Action: Equatable {
        case newEntry
        case showToday
    }

    static let shared = AppRouter()

    var pendingAction: Action?

    /// Handles phinanz://add and phinanz://today. Returns false for unknown links.
    @discardableResult
    func handle(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "phinanz" else { return false }
        switch url.host?.lowercased() {
        case "add", "new":
            pendingAction = .newEntry
        case "today", nil:
            pendingAction = .showToday
        default:
            return false
        }
        return true
    }
}
