//
//  MarketsReducerTests.swift
//  RealTimePriceTrackerTests
//
//  Created by Kanstantsin Klinau on 25/05/26.
//

import Foundation
import XCTest
@testable import RealTimePriceTracker

@MainActor
final class MarketsReducerTests: XCTestCase {

    func test_onAppear_startsStreaming_andInitializesStreams() async {

        let service = MockMarketsService()
        let reducer = MarketsReducer(service: service)
        var state = MarketsState(
            assets: [],
            isLoading: false,
            errorMessage: nil,
            streamURLs: []
        )

        let effect = await reducer.reduce(state: &state, action: .onAppear)
        XCTAssertTrue(state.isLoading)
        XCTAssertTrue(state.streamURLs.isEmpty == false || service.startedURLs.isEmpty == false)
        // stream effect returned

        XCTAssertNotNil(effect)
    }
}

final class MockMarketsService: MarketsServiceProtocol {
    var startedURLs: [URL] = []
    var didStop = false

    func startStreaming(with urls: [URL]) -> AsyncStream<RealTimePriceTracker.MarketsAction> {
        startedURLs = urls
        return AsyncStream { continuation in
            // tests can manually yield messages if needed
        }
    }

    func stopStreaming() {
        didStop = true
    }
}
