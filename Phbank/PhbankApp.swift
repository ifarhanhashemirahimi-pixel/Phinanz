//
//  PhbankApp.swift
//  Phbank
//
//  PHINANZ — a daily finance journal for the German market.
//

import SwiftUI
import SwiftData
import TipKit

@main
struct PhbankApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SettingsKeys.lockEnabled) private var lockEnabled = false
    @State private var lock: AppLock

    private let container: ModelContainer

    init() {
        container = Persistence.shared
        let uiTesting = AppEnvironment.isUITest
        if !uiTesting {
            try? Tips.configure([.displayFrequency(.immediate)])
        }
        let startLocked = !uiTesting && SettingsKeys.lockEnabledValue && AppLock.canAuthenticate
        _lock = State(initialValue: AppLock(startLocked: startLocked))
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environment(lock)

                // Full lock screen, or just a privacy cover while the app is inactive
                // (app switcher snapshot).
                if lock.isLocked || (lockEnabled && scenePhase != .active) {
                    LockScreenView(lock: lock)
                        .transition(.opacity)
                }
            }
            .task {
                if lock.isLocked { await lock.unlock() }
            }
            #if DEBUG
            .task {
                await SnapshotRenderer.runIfRequested()
            }
            #endif
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .background:
                    lock.lockIfNeeded(enabled: lockEnabled && !AppEnvironment.isUITest)
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
