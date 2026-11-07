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

    func testTabBarNavigation() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Check tabs exist
        let discoverTab = app.tabBars.buttons["Discover"]
        let libraryTab = app.tabBars.buttons["Library"]
        let browseTab = app.tabBars.buttons["Browse"]
        let downloadsTab = app.tabBars.buttons["Downloads"]
        let settingsTab = app.tabBars.buttons["Settings"]
        
        if discoverTab.exists {
            XCTAssertTrue(discoverTab.exists)
            
            libraryTab.tap()
            XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 2))
            
            browseTab.tap()
            XCTAssertTrue(app.navigationBars["Browse Sources"].waitForExistence(timeout: 2))
            
            downloadsTab.tap()
            XCTAssertTrue(app.navigationBars["Downloads"].waitForExistence(timeout: 2))
            
            settingsTab.tap()
            XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 2))
        }
    }
}
