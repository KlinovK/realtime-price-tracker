//
//  RealTimePriceTrackerUITests.swift
//  RealTimePriceTrackerUITests
//
//  Created by Константин Клинов on 19/05/26.
//

import XCTest

final class RootViewUITests: XCTestCase {

    func testRootViewDisplaysMarketsView() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.otherElements["MarketsView"].exists)
    }
}
