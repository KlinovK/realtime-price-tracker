//
//  RealTimePriceTrackerTests.swift
//  RealTimePriceTrackerTests
//
//  Created by Константин Клинов on 19/05/26.
//

import XCTest
import SwiftUI
@testable import RealTimePriceTracker

final class RealTimePriceTrackerAppTests: XCTestCase {

    func testRootViewIsCreated() {
        let app = RealTimePriceTrackerApp()
        let view = app.makeRootView()

        XCTAssertTrue(view is RootView)
    }
}
