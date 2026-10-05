//
//  Persistence.swift
//  Phbank
//
//  The single SwiftData container, shared by the app, Siri / Shortcuts
//  actions and the widget refresh. Local by default; iCloud (CloudKit private
//  database) when the user switches it on and the build supports it.
//

import Foundation
import SwiftData
import os

enum Persistence {
    @MainActor
    static let shared: ModelContainer = {
        let uiTesting = AppEnvironment.isUITest
        let demo = AppEnvironment.isDemo
        let schema = Schema(AppSchema.models)

        // iCloud only when switched on in Settings and the build has the capability.
        let wantsCloud = !uiTesting && !demo && CloudSync.isEnabled && CloudSync.isAvailable

        func makeContainer(inMemory: Bool, cloud: Bool = false) throws -> ModelContainer {
            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: inMemory,
                cloudKitDatabase: cloud ? .private(CloudSync.containerID) : .none
            )
            return try ModelContainer(for: schema, configurations: [configuration])
        }

        let log = Logger(subsystem: "Farhan.Phbank", category: "store")
        var opened: ModelContainer?
        if wantsCloud {
            do {
                opened = try makeContainer(inMemory: false, cloud: true)
                CloudSync.isActive = true
            } catch {
                log.error("iCloud sync unavailable: \(error.localizedDescription, privacy: .public). Staying local.")
            }
        }

        let container: ModelContainer
        do {
            container = try opened ?? makeContainer(inMemory: uiTesting || demo)
        } catch {
            // Never crash-loop on a broken store; run in memory and keep the files for inspection.
            log.error("Could not open the store: \(error.localizedDescription, privacy: .public). Falling back to memory.")
            do {
                container = try makeContainer(inMemory: true)
            } catch {
                fatalError("Could not create any ModelContainer: \(error)")
            }
        }
        if uiTesting { SampleData.seed(into: container.mainContext) }
        if demo { SampleData.seedShowcase(into: container.mainContext) }
        AccountStore.ensurePrimaryAccount(in: container.mainContext)
        if let url = container.configurations.first?.url, !uiTesting, !demo {
            DataProtection.protectStore(at: url)
        }
        return container
    }()
}
