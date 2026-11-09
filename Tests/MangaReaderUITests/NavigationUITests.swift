//
//  NavigationUITests.swift
//  MangaReaderUITests
//
//  Created for MangaReader iOS.
//

import XCTest

final class NavigationUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testTabBarNavigationAndScreenshots() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Wait for UI to settle
        _ = app.wait(for: .runningForeground, timeout: 5)
        
        // 1. Library Screen
        saveScreenshot(name: "01_Library_Tab", app: app)
        
        // 2. Browse Screen (Sources)
        let browseTab = app.buttons["Browse"]
        if browseTab.waitForExistence(timeout: 5) {
            browseTab.tap()
            _ = app.wait(for: .runningForeground, timeout: 2)
            saveScreenshot(name: "02_Browse_Sources", app: app)
            
            // 3. Extensions Segment
            let extensionsSegment = app.buttons["Extensions"]
            if extensionsSegment.waitForExistence(timeout: 3) {
                extensionsSegment.tap()
                _ = app.wait(for: .runningForeground, timeout: 2)
                saveScreenshot(name: "03_Browse_Extensions", app: app)
            }
        }
        
        // 4. Updates Screen
        let updatesTab = app.buttons["Updates"]
        if updatesTab.waitForExistence(timeout: 3) {
            updatesTab.tap()
            _ = app.wait(for: .runningForeground, timeout: 2)
            saveScreenshot(name: "04_Updates_Tab", app: app)
        }
        
        // 5. History Screen
        let historyTab = app.buttons["History"]
        if historyTab.waitForExistence(timeout: 3) {
            historyTab.tap()
            _ = app.wait(for: .runningForeground, timeout: 2)
            saveScreenshot(name: "05_History_Tab", app: app)
        }
        
        // 6. More / Settings Screen
        let moreTab = app.buttons["More"]
        if moreTab.waitForExistence(timeout: 3) {
            moreTab.tap()
            _ = app.wait(for: .runningForeground, timeout: 2)
            saveScreenshot(name: "06_More_Settings", app: app)
        }
    }
    
    private func saveScreenshot(name: String, app: XCUIApplication) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
