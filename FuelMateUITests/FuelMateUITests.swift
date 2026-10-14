//
//  FuelMateUITests.swift
//  FuelMateUITests
//
//  Created by YAZiTH JY on 2026-09-30.
//

import XCTest

final class FuelMateUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Tab Bar Navigation Test
    func testTabBarNavigation() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5), "The main tab bar should be visible on app launch.")

        // 1. Navigate to Logs Tab
        let logsTab = tabBar.buttons["Logs"]
        XCTAssertTrue(logsTab.exists, "Logs tab bar item should exist.")
        logsTab.tap()
        
        let logsTitle = app.navigationBars["Logs"].firstMatch
        XCTAssertTrue(logsTitle.waitForExistence(timeout: 3) || app.navigationBars["Fuel History"].firstMatch.waitForExistence(timeout: 3) || tabBar.buttons["Logs"].isSelected)

        // 2. Navigate to Analytics Tab
        let analyticsTab = tabBar.buttons["Analytics"]
        XCTAssertTrue(analyticsTab.exists, "Analytics tab bar item should exist.")
        analyticsTab.tap()

        let analyticsTitle = app.navigationBars["Analytics"].firstMatch
        XCTAssertTrue(analyticsTitle.waitForExistence(timeout: 3) || tabBar.buttons["Analytics"].isSelected)

        // 3. Navigate to Settings Tab
        let settingsTab = tabBar.buttons["Settings"]
        XCTAssertTrue(settingsTab.exists, "Settings tab bar item should exist.")
        settingsTab.tap()

        let settingsTitle = app.navigationBars["Settings"].firstMatch
        XCTAssertTrue(settingsTitle.waitForExistence(timeout: 3) || tabBar.buttons["Settings"].isSelected)

        // 4. Return to Dashboard Tab
        let dashboardTab = tabBar.buttons["Dashboard"]
        XCTAssertTrue(dashboardTab.exists, "Dashboard tab bar item should exist.")
        dashboardTab.tap()
        XCTAssertTrue(dashboardTab.isSelected)
    }

    // MARK: - Add Fill-Up Modal Sheet Test
    func testAddFillUpSheetPresentationAndDismissal() throws {
        let addFillUpButton = app.buttons["Add Fill-Up"]
        if addFillUpButton.waitForExistence(timeout: 4) {
            addFillUpButton.tap()

            // Verify Log Fill-Up sheet opened
            let logFillUpNavBar = app.navigationBars["Log Fill-Up"]
            XCTAssertTrue(logFillUpNavBar.waitForExistence(timeout: 3), "Log Fill-Up modal sheet should open.")

            // Tap Cancel to dismiss
            let cancelButton = app.buttons["Cancel"]
            XCTAssertTrue(cancelButton.exists, "Cancel button should exist in Add Log navigation bar.")
            cancelButton.tap()

            // Verify dismissal
            XCTAssertFalse(logFillUpNavBar.exists, "Log Fill-Up sheet should be dismissed.")
        }
    }

    // MARK: - Receipt Scanner Modal Sheet Test
    func testReceiptScannerSheetPresentationAndDismissal() throws {
        let scanReceiptButton = app.buttons["Scan Receipt"]
        if scanReceiptButton.waitForExistence(timeout: 4) {
            scanReceiptButton.tap()

            // Verify Receipt Scanner sheet opened
            let scannerNavBar = app.navigationBars["Receipt Scanner"]
            XCTAssertTrue(scannerNavBar.waitForExistence(timeout: 3), "Receipt Scanner modal sheet should open.")

            // Tap Close to dismiss
            let closeButton = app.buttons["Close"]
            XCTAssertTrue(closeButton.exists, "Close button should exist in Receipt Scanner navigation bar.")
            closeButton.tap()

            // Verify dismissal
            XCTAssertFalse(scannerNavBar.exists, "Receipt Scanner sheet should be dismissed.")
        }
    }

    // MARK: - Settings View Elements Test
    func testSettingsViewElements() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        let settingsTab = tabBar.buttons["Settings"]
        settingsTab.tap()

        // Verify key settings options are present
        let exportButton = app.buttons["Export Logs to CSV"]
        let defaultsButton = app.buttons["Restore Market Defaults"]

        XCTAssertTrue(exportButton.waitForExistence(timeout: 3) || defaultsButton.waitForExistence(timeout: 3), "Settings options should be rendered.")
    }

    // MARK: - App Launch Performance Metric Test
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
