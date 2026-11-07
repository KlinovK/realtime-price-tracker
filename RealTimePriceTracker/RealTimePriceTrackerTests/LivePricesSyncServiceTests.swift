import Foundation
import SwiftData
import XCTest
@testable import RealTimePriceTracker

@MainActor
final class LivePricesSyncServiceTests: XCTestCase {
    func test_successEvidenceNamesOnlyCommittedFavorite() async throws {
        let container = try ModelContainer(
            for: AssetRecord.self, FavoriteRecord.self, PricePointRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repository = MarketDataRepository(modelContainer: container)
        try await repository.replaceTopAssets(
            [makeCoinMarket(), makeCoinMarket(id: "ethereum", symbol: "eth", rank: 2)],
            fetchedAt: Date(timeIntervalSince1970: 1)
        )
        try await repository.toggleFavorite(coinGeckoID: "bitcoin")
        try await repository.toggleFavorite(coinGeckoID: "ethereum")
        let service = LivePricesSyncService(
            transport: ScriptedMarketsService(),
            repository: repository
        )
        let subscriptions = try await repository.favoriteSubscriptions()
        XCTAssertEqual(Set(subscriptions.map(\.coinGeckoID)), ["bitcoin", "ethereum"])
        var iterator = service.start(subscriptions: subscriptions).makeAsyncIterator()
        guard case let .batchCommitted(_, versions)? = await iterator.next() else {
            return XCTFail("Expected committed IDs")
        }
        XCTAssertEqual(Set(versions.keys), ["bitcoin"])
        let records = try ModelContext(container).fetch(FetchDescriptor<AssetRecord>())
        let byID = Dictionary(uniqueKeysWithValues: records.map { ($0.coinGeckoID, $0) })
        XCTAssertEqual(byID["bitcoin"]?.livePrice, 110)
        XCTAssertNil(byID["ethereum"]?.livePrice)
    }

    func test_failedPersistenceProducesNoCommitEvidence() async {
        let repository = MockMarketDataRepository()
        await repository.setLiveQuoteError(
            MarketDataRepositoryError.persistenceFailed("injected")
        )
        let service = LivePricesSyncService(
            transport: ScriptedMarketsService(),
            repository: repository
        )
        let subscriptions = [
            FavoriteAssetSubscription(coinGeckoID: "bitcoin", binancePairID: "BTCUSDT")
        ]
        var iterator = service.start(subscriptions: subscriptions).makeAsyncIterator()
        let event = await iterator.next()
        XCTAssertEqual(event, .persistenceFailed)
        let end = await iterator.next()
        XCTAssertNil(end)
    }
}

private nonisolated struct ScriptedMarketsService: MarketsServiceProtocol {
    func startStreaming(symbols: [String]) -> AsyncStream<MarketStreamEvent> {
        AsyncStream { continuation in
            continuation.yield(.quotes([
                CryptoAsset(id: "BTCUSDT", symbol: "BTCUSDT", price: 110, change24h: 1)
            ]))
            continuation.finish()
        }
    }
}
