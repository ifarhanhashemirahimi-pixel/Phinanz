//
//  PhbankUITests.swift
//  PhbankUITests
//
//  Launches with `-UITests` (in-memory store with sample data, lock and
//  onboarding disabled). Assumes the simulator language is English.
//

import XCTest

final class PhbankUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        // Run in English whatever language the simulator uses.
        app.launchArguments = ["-UITests", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        return app
    }

    @MainActor
    func testTabsAndToolbarExist() throws {
        let app = launchApp()
        for tab in ["Journal", "Summary", "Plan"] {
            XCTAssertTrue(app.buttons[tab].firstMatch.waitForExistence(timeout: 5), "Missing tab \(tab)")
        }
        for id in ["toolbar-settings", "toolbar-ai", "toolbar-add"] {
            XCTAssertTrue(app.buttons[id].waitForExistence(timeout: 5), "Missing toolbar button \(id)")
        }
    }

    @MainActor
    func testSettingsOpensAndCloses() throws {
        let app = launchApp()
        app.buttons["toolbar-settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["toolbar-add"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSummaryShowsSpendingTotal() throws {
        let app = launchApp()
        app.buttons["Summary"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["summary-total"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testAddingAnEntryShowsItOnThePage() throws {
        let app = launchApp()
        let add = app.buttons["toolbar-add"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()

        let amount = app.textFields["field-amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap()
        amount.typeText("7")

        let store = app.textFields["field-store"]
        store.tap()
        store.typeText("UITest Cafe")

        app.buttons["save-entry"].tap()

        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS 'UITest Cafe'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
    }
}
