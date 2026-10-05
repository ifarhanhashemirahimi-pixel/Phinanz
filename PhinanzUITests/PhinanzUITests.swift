//
//  PhinanzUITests.swift
//  PhinanzUITests
//
//  Launches with `-UITests` (in-memory store with sample data, lock and
//  onboarding disabled). Assumes the simulator language is English.
//

import XCTest

final class PhinanzUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        // Run in English whatever language the simulator uses.
        app.launchArguments = ["-UITests", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        // The launch tests rotate the simulator; these flows expect portrait.
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        return app
    }

    /// Swipes up until `element` exists (list rows below the fold aren't in the hierarchy yet).
    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication, attempts: Int = 4) -> Bool {
        if element.waitForExistence(timeout: 5) { return true }
        for _ in 0..<attempts {
            app.swipeUp()
            if element.waitForExistence(timeout: 1.5) { return true }
        }
        return false
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
        XCTAssertTrue(reveal(row, in: app))
    }

    @MainActor
    func testCreatingASavingsGoal() throws {
        let app = launchApp()
        app.buttons["Plan"].firstMatch.tap()

        let newGoal = app.buttons["new-goal"]
        XCTAssertTrue(newGoal.waitForExistence(timeout: 5))
        newGoal.tap()

        let name = app.textFields["goal-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("UITest Trip")

        let target = app.textFields["goal-target"]
        target.tap()
        target.typeText("500")

        app.buttons["save-goal"].tap()
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS 'UITest Trip'")).firstMatch
        XCTAssertTrue(reveal(row, in: app))
    }

    @MainActor
    func testSecurityOverviewOpensFromSettings() throws {
        let app = launchApp()
        app.buttons["toolbar-settings"].tap()
        let link = app.buttons["security-overview"]
        XCTAssertTrue(reveal(link, in: app))
        link.tap()
        XCTAssertTrue(app.navigationBars["Security & Privacy"].waitForExistence(timeout: 5))
    }
}
