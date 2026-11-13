import XCTest
@testable import RealTimePriceTracker

@MainActor
final class BinancePairRegistryTests: XCTestCase {
    func test_initialEntriesUseExactCoinGeckoIDsAndSpotPairs() {
        let registry = BinancePairRegistry.approved
        let expected: [(id: String, pair: String, base: String)] = [
            ("bitcoin", "BTCUSDT", "BTC"),
            ("ethereum", "ETHUSDT", "ETH"),
            ("solana", "SOLUSDT", "SOL")
        ]

        for item in expected {
            let entry = registry.entry(for: item.id)
            XCTAssertEqual(entry?.pairID, item.pair)
            XCTAssertEqual(entry?.baseAsset, item.base)
            XCTAssertEqual(entry?.quoteAsset, "USDT")
            XCTAssertTrue(registry.approves(coinGeckoID: item.id, pairID: item.pair))
        }
        XCTAssertNil(registry.entry(for: "another-bitcoin"))
        XCTAssertFalse(registry.approves(coinGeckoID: "another-bitcoin", pairID: "BTCUSDT"))
    }

    func test_ambiguousIDsOrPairsRejectEveryConflictingEntry() {
        let registry = BinancePairRegistry(entries: [
            .init(coinGeckoID: "one", pairID: "BTCUSDT", baseAsset: "BTC", quoteAsset: "USDT"),
            .init(coinGeckoID: "two", pairID: "BTCUSDT", baseAsset: "BTC", quoteAsset: "USDT"),
            .init(coinGeckoID: "three", pairID: "ETHUSDT", baseAsset: "ETH", quoteAsset: "USDT"),
            .init(coinGeckoID: "three", pairID: "SOLUSDT", baseAsset: "SOL", quoteAsset: "USDT")
        ])

        for id in ["one", "two", "three"] {
            XCTAssertNil(registry.entry(for: id))
        }
    }

    func test_malformedPairIsNotApproved() {
        let registry = BinancePairRegistry(entries: [
            .init(coinGeckoID: "one", pairID: "BTCUSDT", baseAsset: "ETH", quoteAsset: "USDT"),
            .init(coinGeckoID: "two", pairID: "ethusdt", baseAsset: "ETH", quoteAsset: "USDT")
        ])
        XCTAssertNil(registry.entry(for: "one"))
        XCTAssertNil(registry.entry(for: "two"))
    }
}
