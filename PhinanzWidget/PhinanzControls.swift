//
//  PhinanzControls.swift
//  PhinanzWidget
//
//  Control Center / Lock Screen / Action button control: "New Entry".
//

import AppIntents
import SwiftUI
import WidgetKit

struct OpenNewEntryIntent: AppIntent {
    static let title: LocalizedStringResource = "New Entry"
    static let description = IntentDescription("Opens PHINANZ with a new entry for today.")

    func perform() async throws -> some IntentResult & OpensIntent {
        guard let url = URL(string: "phinanz://add") else { return .result() }
        return .result(opensIntent: OpenURLIntent(url))
    }
}

struct NewEntryControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "Farhan.Phbank.PhinanzWidget.newEntry") {
            ControlWidgetButton(action: OpenNewEntryIntent()) {
                Label("New Entry", systemImage: "square.and.pencil")
            }
        }
        .displayName("New Entry")
        .description("Opens PHINANZ with a new entry for today.")
    }
}
