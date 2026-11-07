import Foundation
import XCTest
@testable import RealTimePriceTracker

private actor CoinGeckoRequestRecorder {
    private(set) var requests: [URLRequest] = []
    let data: Data
    let statusCode: Int

    init(json: String, statusCode: Int = 200) {
        self.data = Data(json.utf8)
        self.statusCode = statusCode
    }

    func load(_ request: URLRequest) throws -> (Data, URLResponse) {
        requests.append(request)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (data, response)
    }
}

@MainActor
final class CoinGeckoClientTests: XCTestCase {
    func test_fetchTopAssets_buildsRankedTop100RequestAndDecodesDecimalValues() async throws {
        let recorder = CoinGeckoRequestRecorder(json: """
        [
          {
            "id": "bitcoin",
            "symbol": "btc",
            "name": "Bitcoin",
            "image": "https://example.com/btc.png",
            "current_price": 12345.6789,
            "market_cap": 1000000,
            "market_cap_rank": 1,
            "total_volume": 500000,
            "high_24h": 13000,
            "low_24h": 12000,
            "price_change_percentage_24h": 1.25
          }
        ]
        """)
        let client = CoinGeckoClient { request in
            try await recorder.load(request)
        }

        let assets = try await client.fetchTopAssets(limit: 100)
        let recordedRequests = await recorder.requests
        let request = try XCTUnwrap(recordedRequests.first)
        let components = try XCTUnwrap(
            URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
        )
        let query = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).map {
                ($0.name, $0.value)
            }
        )

        XCTAssertEqual(assets.count, 1)
        XCTAssertEqual(assets[0].id, "bitcoin")
        XCTAssertEqual(assets[0].currentPrice, Decimal(string: "12345.6789"))
        XCTAssertEqual(query["vs_currency"], "usd")
        XCTAssertEqual(query["order"], "market_cap_desc")
        XCTAssertEqual(query["per_page"], "100")
        XCTAssertEqual(query["sparkline"], "false")
    }

    func test_fetchPriceChart_convertsMillisecondsAndSortsPoints() async throws {
        let recorder = CoinGeckoRequestRecorder(json: """
        {
          "prices": [
            [2000, 20.5],
            [1000, 10.25]
          ]
        }
        """)
        let client = CoinGeckoClient { request in
            try await recorder.load(request)
        }

        let points = try await client.fetchPriceChart(
            coinID: "bitcoin",
            days: 7
        )
        let recordedRequests = await recorder.requests
        let request = try XCTUnwrap(recordedRequests.first)

        XCTAssertEqual(request.url?.path, "/api/v3/coins/bitcoin/market_chart")
        XCTAssertEqual(points.map(\.date.timeIntervalSince1970), [1, 2])
        XCTAssertEqual(points.map(\.price), [10.25, 20.5])
    }

    func test_rateLimitResponseProducesTypedFailure() async {
        let recorder = CoinGeckoRequestRecorder(json: "{}", statusCode: 429)
        let client = CoinGeckoClient { request in
            try await recorder.load(request)
        }

        do {
            _ = try await client.fetchTopAssets(limit: 100)
            XCTFail("Expected rate limit error")
        } catch let error as CoinGeckoClientError {
            XCTAssertEqual(error, .rateLimited)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
