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

        guard case .success(let emitted)? = await iterator.next() else {
            return XCTFail("Expected a successful symbol refresh")
        }

        // Then

        XCTAssertEqual(emitted.count, 100)
        XCTAssertEqual(emitted.first, "SYM1")
        XCTAssertEqual(emitted.last, "SYM100")
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

        guard case .success(let first)? = await iterator.next(),
              case .success(let second)? = await iterator.next() else {
            return XCTFail("Expected successful symbol refreshes")
        }

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

@MainActor
final class TopSymbolsServiceTests: XCTestCase {

    func test_fetchTopSymbols_rejectsHTTPFailure() async {
        let service = TopSymbolsService { url in
            let response = HTTPURLResponse(
                url: url,
                statusCode: 503,
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data(), response)
        }

        do {
            _ = try await service.fetchTopSymbols()
            XCTFail("Expected an HTTP status failure")
        } catch let error as TopSymbolsServiceError {
            XCTAssertEqual(error, .httpStatusCode(503))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_fetchTopSymbols_rejectsInvalidPayload() async {
        let service = TopSymbolsService { url in
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data("not-json".utf8), response)
        }

        do {
            _ = try await service.fetchTopSymbols()
            XCTFail("Expected a payload failure")
        } catch let error as TopSymbolsServiceError {
            XCTAssertEqual(error, .invalidPayload)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_fetchTopSymbols_returnsOnlyRankedUSDTMarkets() async throws {
        let payload = Data(
            """
            [
              {
                "symbol": "ETHUSDT",
                "quoteVolume": "200.0000000000000001",
                "priceChangePercent": "2.1"
              },
              {
                "symbol": "BTCUSDT",
                "quoteVolume": "100.0000000000000002",
                "priceChangePercent": "1.2"
              },
              {
                "symbol": "ETHBTC",
                "quoteVolume": "999999",
                "priceChangePercent": "0.5"
              },
              {
                "symbol": "INVALIDUSDT",
                "quoteVolume": "not-a-number",
                "priceChangePercent": "0.1"
              }
            ]
            """.utf8
        )
        let service = TopSymbolsService { url in
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (payload, response)
        }

        let symbols = try await service.fetchTopSymbols()

        XCTAssertEqual(symbols, ["ethusdt", "btcusdt"])
    }
}

// MARK: - Mocks

final class MockTopSymbolsService: TopSymbolsServiceProtocol {

    private let symbolsToReturn: [String]

    init(symbolsToReturn: [String]) {
        self.symbolsToReturn = symbolsToReturn
    }

    func fetchTopSymbols() async throws -> [String] {
        symbolsToReturn
    }
}

final class SequentialMockTopSymbolsService: TopSymbolsServiceProtocol {

    private let responses: [[String]]
    private var currentIndex = 0

    init(responses: [[String]]) {
        self.responses = responses
    }

    func fetchTopSymbols() async throws -> [String] {

        defer {
            currentIndex += 1
        }

        return responses[min(currentIndex, responses.count - 1)]
    }
}

final class CountingMockTopSymbolsService: TopSymbolsServiceProtocol {

    private(set) var callCount = 0

    func fetchTopSymbols() async throws -> [String] {
        callCount += 1
        return ["BTC"]
    }
}
