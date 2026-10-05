//
//  PhinanzApp.swift
//  Phinanz
//
//  PHINANZ — a daily finance journal for the German market.
//

import SwiftUI
import SwiftData
import TipKit

@main
struct PhinanzApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SettingsKeys.lockEnabled) private var lockEnabled = false
    @State private var lock: AppLock

    private let container: ModelContainer

    init() {
        container = Persistence.shared
        DataProtection.removeTemporaryExports()
        let uiTesting = AppEnvironment.isUITest || AppEnvironment.isDemo
        if !uiTesting {
            try? Tips.configure([.displayFrequency(.immediate)])
        }
        let startLocked = !uiTesting && SettingsKeys.lockEnabledValue && AppLock.canAuthenticate
        _lock = State(initialValue: AppLock(startLocked: startLocked))
    }

    private var shieldVisible: Bool {
        lock.isLocked || (lockEnabled && scenePhase != .active && !AppEnvironment.isUITest)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(lock)
            // Full lock screen, or just a privacy cover while the app is inactive
            // (app switcher snapshot). Lives in its own window above sheets and alerts.
            .onChange(of: shieldVisible, initial: true) { _, visible in
                PrivacyShield.shared.update(visible: visible, lock: lock)
            }
            .task {
                if lock.isLocked { await lock.unlock() }
            }
            #if DEBUG
            .task {
                await SnapshotRenderer.runIfRequested()
                await DemoTour.runIfRequested(lock: lock)
                // Last, so this launch keeps its own language and number format.
                DebugFlags.applyLanguageRequest()
            }
            #endif
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .background:
                    lock.lockIfNeeded(enabled: lockEnabled && !AppEnvironment.isUITest)
                    DataProtection.removeTemporaryExports()
                case .active:
                    if lock.isLocked { Task { await lock.unlock() } }
                default:
                    break
                }
            }
        }
        .modelContainer(container)
    }
}
