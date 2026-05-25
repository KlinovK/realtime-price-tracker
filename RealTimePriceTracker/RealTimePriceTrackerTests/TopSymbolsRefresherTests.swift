//
//  TopSymbolsRefresherTests.swift
//  RealTimePriceTrackerTests
//
//  Created by Kanstantsin Klinau on 25/05/26.
//

import Foundation
import XCTest
@testable import RealTimePriceTracker

@MainActor
final class TopSymbolsRefresherTests: XCTestCase {

    // MARK: - Tests

    func test_streamEmitsTop100Symbols() async {

        // Given

        let symbols = (1...150).map { "SYM\($0)" }

        let service = MockTopSymbolsService(
            symbolsToReturn: symbols
        )

        let refresher = TopSymbolsRefresher(
            service: service,
            refreshIntervalNanoseconds: 1_000_000
        )

        // When

        let stream = refresher.stream()
        var iterator = stream.makeAsyncIterator()

        let emitted = await iterator.next()

        // Then

        XCTAssertEqual(emitted?.count, 100)
        XCTAssertEqual(emitted?.first, "SYM1")
        XCTAssertEqual(emitted?.last, "SYM100")
    }

    func test_streamEmitsMultipleUpdates() async {

        // Given

        let service = SequentialMockTopSymbolsService(
            responses: [
                ["BTC", "ETH"],
                ["SOL", "XRP"]
            ]
        )

        let refresher = TopSymbolsRefresher(
            service: service,
            refreshIntervalNanoseconds: 1_000_000
        )

        // When

        let stream = refresher.stream()
        var iterator = stream.makeAsyncIterator()

        let first = await iterator.next()
        let second = await iterator.next()

        // Then

        XCTAssertEqual(first, ["BTC", "ETH"])
        XCTAssertEqual(second, ["SOL", "XRP"])
    }

    func test_fetchTopSymbolsCalledRepeatedly() async {

        // Given

        let service = CountingMockTopSymbolsService()

        let refresher = TopSymbolsRefresher(
            service: service,
            refreshIntervalNanoseconds: 1_000_000
        )

        // When

        let stream = refresher.stream()
        var iterator = stream.makeAsyncIterator()

        _ = await iterator.next()
        _ = await iterator.next()
        _ = await iterator.next()

        // Then

        XCTAssertEqual(service.callCount, 3)
    }
}

// MARK: - Mocks

final class MockTopSymbolsService: TopSymbolsServiceProtocol {

    private let symbolsToReturn: [String]

    init(symbolsToReturn: [String]) {
        self.symbolsToReturn = symbolsToReturn
    }

    func fetchTopSymbols() async -> [String] {
        symbolsToReturn
    }
}

final class SequentialMockTopSymbolsService: TopSymbolsServiceProtocol {

    private let responses: [[String]]
    private var currentIndex = 0

    init(responses: [[String]]) {
        self.responses = responses
    }

    func fetchTopSymbols() async -> [String] {

        defer {
            currentIndex += 1
        }

        return responses[min(currentIndex, responses.count - 1)]
    }
}

final class CountingMockTopSymbolsService: TopSymbolsServiceProtocol {

    private(set) var callCount = 0

    func fetchTopSymbols() async -> [String] {
        callCount += 1
        return ["BTC"]
    }
}
