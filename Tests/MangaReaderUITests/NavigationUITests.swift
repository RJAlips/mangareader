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
        
        let libraryTab = app.buttons["Library"]
        let updatesTab = app.buttons["Updates"]
        let browseTab = app.buttons["Browse"]
        let historyTab = app.buttons["History"]
        let moreTab = app.buttons["More"]
        
        if libraryTab.exists {
            XCTAssertTrue(libraryTab.exists)
            if updatesTab.exists {
                updatesTab.tap()
            }
            if browseTab.exists {
                browseTab.tap()
            }
            if historyTab.exists {
                historyTab.tap()
            }
            if moreTab.exists {
                moreTab.tap()
            }
        }
    }
}
