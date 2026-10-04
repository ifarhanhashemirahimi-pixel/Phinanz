//
//  PhbankApp.swift
//  Phbank
//
//  PHINANZ — a leather-notebook finance journal for the German market.
//

import SwiftUI
import SwiftData

@main
struct PhbankApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SettingsKeys.lockEnabled) private var lockEnabled = false
    @State private var lock: AppLock

    private let container: ModelContainer

    init() {
        let uiTesting = AppEnvironment.isUITest
        let schema = Schema(AppSchema.models)

        func makeContainer(inMemory: Bool) throws -> ModelContainer {
            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: inMemory,
                cloudKitDatabase: .none // sync is not implemented yet
            )
            return try ModelContainer(for: schema, configurations: [configuration])
        }

        let made: ModelContainer
        do {
            made = try makeContainer(inMemory: uiTesting)
        } catch {
            // Never crash-loop on a broken store; run in memory and keep the files for inspection.
            print("PHINANZ: could not open the store (\(error)). Falling back to memory.")
            do {
                made = try makeContainer(inMemory: true)
            } catch {
                fatalError("Could not create any ModelContainer: \(error)")
            }
        }

        if uiTesting { SampleData.seed(into: made.mainContext) }
        container = made

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
