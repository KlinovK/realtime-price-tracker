//
//  TopSymbolsServiceTests.swift
//  RealTimePriceTrackerTests
//
//  Created by Kanstantsin Klinau on 20/05/26.
//

import XCTest
@testable import RealTimePriceTracker

@MainActor
final class TopSymbolsServiceTests: XCTestCase {
    
    func makeMockSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    // MARK: - Success case

    func testFetchTopSymbols_returnsSortedUSDT() async {
        let session = makeMockSession()

        MockURLProtocol.handler = { _ in
            let json = """
            [
                {"symbol":"BTCUSDT","quoteVolume":"200"},
                {"symbol":"ETHUSDT","quoteVolume":"300"},
                {"symbol":"BNBUSDT","quoteVolume":"100"},
                {"symbol":"DOGEUSDT","quoteVolume":"50"}
            ]
            """.data(using: .utf8)!

            let response = HTTPURLResponse(
                url: URL(string: "https://binance.com")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!

            return (response, json)
        }

        let service = TopSymbolsService(session: session)

        let result = await service.fetchTopSymbols()

        XCTAssertEqual(result, [
            "ethusdt",
            "btcusdt",
            "bnbusdt",
            "dogeusdt"
        ])
    }

    // MARK: - Filtering non-USDT symbols

    func testFetchTopSymbols_filtersOnlyUSDT() async {
        let session = makeMockSession()

        MockURLProtocol.handler = { _ in
            let json = """
            [
                {"symbol":"BTCUSDT","quoteVolume":"200"},
                {"symbol":"ETHBTC","quoteVolume":"999"}
            ]
            """.data(using: .utf8)!

            let response = HTTPURLResponse(
                url: URL(string: "https://binance.com")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!

            return (response, json)
        }

        let service = TopSymbolsService(session: session)

        let result = await service.fetchTopSymbols()

        XCTAssertEqual(result, ["btcusdt"])
    }

    // MARK: - Fallback on error

    func testFetchTopSymbols_returnsFallbackOnNetworkFailure() async {
        let session = makeMockSession()

        MockURLProtocol.handler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let service = TopSymbolsService(session: session)

        let result = await service.fetchTopSymbols()

        XCTAssertEqual(result, [
            "btcusdt",
            "ethusdt",
            "bnbusdt",
            "solusdt",
            "xrpusdt"
        ])
    }

    // MARK: - Sorting correctness

    func testFetchTopSymbols_sortsByQuoteVolume() async {
        let session = makeMockSession()

        MockURLProtocol.handler = { _ in
            let json = """
            [
                {"symbol":"AAAUSDT","quoteVolume":"10"},
                {"symbol":"BBBUSDT","quoteVolume":"999"},
                {"symbol":"CCCUSDT","quoteVolume":"100"}
            ]
            """.data(using: .utf8)!

            let response = HTTPURLResponse(
                url: URL(string: "https://binance.com")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!

            return (response, json)
        }

        let service = TopSymbolsService(session: session)

        let result = await service.fetchTopSymbols()

        XCTAssertEqual(result, [
            "bbusdt",
            "cccusdt",
            "aaausdt"
        ])
    }
}

final class MockURLProtocol: URLProtocol {

    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            fatalError("Handler not set")
        }

        do {
            let (response, data) = try handler(request)

            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)

        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
