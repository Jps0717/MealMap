//
//  MealMapUITests.swift
//  MealMapUITests
//
//  Created by Jackson Shell on 6/4/25.
//

import XCTest

final class MealMapUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        // Cleanup after tests
    }
    // Verify home screen loads

    @MainActor
    func testAppLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["Discover Restaurants"].exists, "Home screen should display")
    }
    
    @MainActor
    func testLocationPermissionFlow() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Test location permission handling
        if app.buttons["Enable Location"].exists {
            app.buttons["Enable Location"].tap()
        }
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
