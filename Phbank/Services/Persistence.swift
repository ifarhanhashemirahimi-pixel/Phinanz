//
//  Persistence.swift
//  Phbank
//
//  The single SwiftData container, shared by the app, Siri / Shortcuts
//  actions and the widget refresh.
//

import Foundation
import SwiftData

enum Persistence {
    @MainActor
    static let shared: ModelContainer = {
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

        let container: ModelContainer
        do {
            container = try makeContainer(inMemory: uiTesting)
        } catch {
            // Never crash-loop on a broken store; run in memory and keep the files for inspection.
            print("PHINANZ: could not open the store (\(error)). Falling back to memory.")
            do {
                container = try makeContainer(inMemory: true)
            } catch {
                fatalError("Could not create any ModelContainer: \(error)")
            }
        }
        if uiTesting { SampleData.seed(into: container.mainContext) }
        return container
    }()
}
