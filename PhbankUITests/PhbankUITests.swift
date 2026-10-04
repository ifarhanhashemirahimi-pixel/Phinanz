//
//  PhbankUITests.swift
//  PhbankUITests
//
//  Launches with `-UITests` (in-memory store with sample data, lock disabled).
//

import XCTest

final class PhbankUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITests"]
        app.launch()
        return app
    }

    @MainActor
    func testTabBarShowsAllActions() throws {
        let app = launchApp()
        for id in ["tab-settings", "tab-search", "tab-voice", "tab-scan", "tab-summary", "tab-today"] {
            XCTAssertTrue(app.buttons[id].waitForExistence(timeout: 5), "Missing tab bar button \(id)")
        }
    }

    @MainActor
    func testSettingsOpensAndCloses() throws {
        let app = launchApp()
        app.buttons["tab-settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["tab-settings"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSummaryShowsSampleSpending() throws {
        let app = launchApp()
        app.buttons["tab-summary"].tap()
        XCTAssertTrue(app.navigationBars["Summary"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Total spent"].exists)
    }

    @MainActor
    func testAddingAnEntryShowsItOnThePage() throws {
        let app = launchApp()
        let addButton = app.buttons.matching(
            NSPredicate(format: "identifier == 'add-entry' AND isHittable == true")
        ).firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        let store = app.textFields["field-store"]
        XCTAssertTrue(store.waitForExistence(timeout: 5))
        store.tap()
        store.typeText("UITest Cafe")

        let amount = app.textFields["field-amount"]
        amount.tap()
        amount.typeText("7")

        app.buttons["save-entry"].tap()

        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS 'UITest Cafe'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
    }
}
