import Foundation
import SwiftData
import XCTest
@testable import RealTimePriceTracker

@MainActor
final class MarketDataRepositoryTests: XCTestCase {
    func test_newCommitEvidenceCannotLabelOldObservedQuoteLive() async throws {
        let container = try makeContainer()
        let repository = MarketDataRepository(modelContainer: container)
        try await repository.replaceTopAssets([makeCoinMarket()], fetchedAt: .init(timeIntervalSince1970: 1))
        try await repository.toggleFavorite(coinGeckoID: "bitcoin")
        let subscriptions = try await repository.favoriteSubscriptions()
        _ = try await repository.applyLiveQuotes(
            [CryptoAsset(id: "BTCUSDT", symbol: "BTCUSDT", price: 110,
                         change24h: 1, lastUpdated: .init(timeIntervalSince1970: 10))],
            subscriptions: subscriptions
        )

        // The view context has observed A. Hold that observation while the
        // repository actor commits B and its event reaches the reducer.
        let viewContext = ModelContext(container)
        let observed = try XCTUnwrap(viewContext.fetch(FetchDescriptor<AssetRecord>()).first)
        let observedPrice = observed.livePrice
        let observedChange = observed.liveChange24h
        let observedAt = observed.liveUpdatedAt
        XCTAssertEqual(observedPrice, 110)

        let committed = try await repository.applyLiveQuotes(
            [CryptoAsset(id: "BTCUSDT", symbol: "BTCUSDT", price: 120,
                         change24h: 2, lastUpdated: .init(timeIntervalSince1970: 20))],
            subscriptions: subscriptions
        )
        XCTAssertEqual(observed.livePrice, 110)
        var state = MarketsState(connection: .connecting, subscriptions: subscriptions)
        let reducer = MarketsReducer(syncService: MockLivePricesSyncService())
        _ = reducer.reduce(
            state: &state,
            action: .syncEvent(
                generation: state.generation,
                .batchCommitted(lastEventAt: .init(timeIntervalSince1970: 20), versions: committed)
            )
        )

        let presentation = FavoritePricePresentation(
            snapshotPrice: observed.snapshotPrice,
            snapshotChange24h: observed.snapshotChange24h,
            livePrice: observedPrice,
            liveChange24h: observedChange,
            liveUpdatedAt: observedAt,
            committedVersion: state.committedQuoteVersions["bitcoin"],
            connection: state.connection
        )
        XCTAssertEqual(observedAt, .init(timeIntervalSince1970: 10))
        XCTAssertEqual(presentation.price, 100)
        XCTAssertEqual(presentation.status, .snapshot)
        let updated = try XCTUnwrap(
            ModelContext(container).fetch(FetchDescriptor<AssetRecord>()).first
        )
        let matching = FavoritePricePresentation(
            snapshotPrice: updated.snapshotPrice,
            snapshotChange24h: updated.snapshotChange24h,
            livePrice: updated.livePrice,
            liveChange24h: updated.liveChange24h,
            liveUpdatedAt: updated.liveUpdatedAt,
            committedVersion: state.committedQuoteVersions["bitcoin"],
            connection: state.connection
        )
        XCTAssertEqual(matching.price, 120)
        XCTAssertEqual(matching.status, .live)
    }

    func test_coinGeckoFavoriteAndBinanceFlowCommitsIntoOneAssetRecord() async throws {
        let container = try makeContainer()
        let repository = MarketDataRepository(modelContainer: container)
        let fetchedAt = Date(timeIntervalSince1970: 100)
        let liveAt = Date(timeIntervalSince1970: 200)

        try await repository.replaceTopAssets(
            [makeCoinMarket()],
            fetchedAt: fetchedAt
        )
        try await repository.toggleFavorite(coinGeckoID: "bitcoin")
        let subscriptions = try await repository.favoriteSubscriptions()
        let committed = try await repository.applyLiveQuotes(
            [
                CryptoAsset(
                    id: "BTCUSDT",
                    symbol: "BTCUSDT",
                    price: 101,
                    change24h: 3,
                    lastUpdated: liveAt
                )
            ],
            subscriptions: subscriptions
        )
        XCTAssertEqual(Set(committed.keys), ["bitcoin"])

        let context = ModelContext(container)
        let assets = try context.fetch(FetchDescriptor<AssetRecord>())
        let favorites = try context.fetch(FetchDescriptor<FavoriteRecord>())
        let asset = try XCTUnwrap(assets.first)

        XCTAssertEqual(asset.snapshotPrice, 100)
        XCTAssertEqual(asset.snapshotUpdatedAt, fetchedAt)
        XCTAssertEqual(asset.livePrice, 101)
        XCTAssertEqual(asset.liveChange24h, 3)
        XCTAssertEqual(asset.liveUpdatedAt, liveAt)
        XCTAssertEqual(favorites.map(\.coinGeckoID), ["bitcoin"])
        XCTAssertEqual(
            subscriptions,
            [FavoriteAssetSubscription(coinGeckoID: "bitcoin", binancePairID: "BTCUSDT")]
        )
    }

    func test_snapshotReplacementPreservesFavoritesAndDeletesUnusedOldRows() async throws {
        let container = try makeContainer()
        let repository = MarketDataRepository(modelContainer: container)
        try await repository.replaceTopAssets(
            [
                makeCoinMarket(),
                makeCoinMarket(id: "ethereum", symbol: "eth", rank: 2),
                makeCoinMarket(id: "solana", symbol: "sol", rank: 3)
            ],
            fetchedAt: Date(timeIntervalSince1970: 100)
        )
        try await repository.toggleFavorite(coinGeckoID: "ethereum")

        try await repository.replaceTopAssets(
            [makeCoinMarket(id: "solana", symbol: "sol", rank: 1)],
            fetchedAt: Date(timeIntervalSince1970: 200)
        )

        let context = ModelContext(container)
        let assets = try context.fetch(FetchDescriptor<AssetRecord>())
        let byID = Dictionary(uniqueKeysWithValues: assets.map { ($0.coinGeckoID, $0) })

        XCTAssertNil(byID["bitcoin"])
        XCTAssertEqual(byID["ethereum"]?.isTopAsset, false)
        XCTAssertEqual(byID["solana"]?.isTopAsset, true)
    }

    func test_ambiguousProviderPairIsNotWrittenToTwoCoinGeckoAssets() async throws {
        let container = try makeContainer()
        let repository = MarketDataRepository(modelContainer: container)
        try await repository.replaceTopAssets(
            [
                makeCoinMarket(id: "asset-one", symbol: "same", rank: 1),
                makeCoinMarket(id: "asset-two", symbol: "same", rank: 2)
            ],
            fetchedAt: .now
        )
        try await repository.toggleFavorite(coinGeckoID: "asset-one")
        try await repository.toggleFavorite(coinGeckoID: "asset-two")
        let subscriptions = try await repository.favoriteSubscriptions()

        let committed = try await repository.applyLiveQuotes(
            [
                CryptoAsset(
                    id: "SAMEUSDT",
                    symbol: "SAMEUSDT",
                    price: 999,
                    change24h: 99
                )
            ],
            subscriptions: subscriptions
        )
        XCTAssertTrue(committed.isEmpty)

        let context = ModelContext(container)
        let assets = try context.fetch(FetchDescriptor<AssetRecord>())
        XCTAssertTrue(assets.allSatisfy { $0.livePrice == nil })
    }

    func test_newSnapshotSupersedesOldQuoteWithoutErasingUnreplacedFavorite() async throws {
        let container = try makeContainer()
        let repository = MarketDataRepository(modelContainer: container)
        try await repository.replaceTopAssets(
            [makeCoinMarket(), makeCoinMarket(id: "ethereum", symbol: "eth", rank: 2)],
            fetchedAt: Date(timeIntervalSince1970: 100)
        )
        try await repository.toggleFavorite(coinGeckoID: "bitcoin")
        try await repository.toggleFavorite(coinGeckoID: "ethereum")
        let subscriptions = try await repository.favoriteSubscriptions()
        _ = try await repository.applyLiveQuotes(
            [
                CryptoAsset(id: "BTCUSDT", symbol: "BTCUSDT", price: 110, change24h: 3),
                CryptoAsset(id: "ETHUSDT", symbol: "ETHUSDT", price: 210, change24h: 3)
            ],
            subscriptions: subscriptions
        )

        try await repository.replaceTopAssets(
            [makeCoinMarket()],
            fetchedAt: Date(timeIntervalSince1970: 200)
        )

        let records = try ModelContext(container).fetch(FetchDescriptor<AssetRecord>())
        let byID = Dictionary(uniqueKeysWithValues: records.map { ($0.coinGeckoID, $0) })
        XCTAssertEqual(byID["bitcoin"]?.snapshotPrice, 100)
        XCTAssertNil(byID["bitcoin"]?.livePrice)
        XCTAssertEqual(byID["ethereum"]?.livePrice, 210)
        XCTAssertEqual(byID["ethereum"]?.isTopAsset, false)
    }

    func test_repeatedQuotesUseArrivalOrderRatherThanWallClock() async throws {
        let container = try makeContainer()
        let repository = MarketDataRepository(modelContainer: container)
        try await repository.replaceTopAssets(
            [makeCoinMarket()], fetchedAt: Date(timeIntervalSince1970: 100)
        )
        try await repository.toggleFavorite(coinGeckoID: "bitcoin")
        let subscriptions = try await repository.favoriteSubscriptions()
        let committed = try await repository.applyLiveQuotes(
            [
                CryptoAsset(
                    id: "BTCUSDT", symbol: "BTCUSDT", price: 110,
                    change24h: 1, lastUpdated: Date(timeIntervalSince1970: 300)
                ),
                CryptoAsset(
                    id: "BTCUSDT", symbol: "BTCUSDT", price: 120,
                    change24h: 2, lastUpdated: Date(timeIntervalSince1970: 200)
                )
            ],
            subscriptions: subscriptions
        )
        XCTAssertEqual(Set(committed.keys), ["bitcoin"])
        let record = try XCTUnwrap(
            ModelContext(container).fetch(FetchDescriptor<AssetRecord>()).first
        )
        XCTAssertEqual(record.livePrice, 120)
    }

    func test_snapshotWithoutPricePreservesCachedQuote() async throws {
        let container = try makeContainer()
        let repository = MarketDataRepository(modelContainer: container)
        try await repository.replaceTopAssets([makeCoinMarket()], fetchedAt: .now)
        try await repository.toggleFavorite(coinGeckoID: "bitcoin")
        let subscriptions = try await repository.favoriteSubscriptions()
        _ = try await repository.applyLiveQuotes(
            [CryptoAsset(id: "BTCUSDT", symbol: "BTCUSDT", price: 110, change24h: 3)],
            subscriptions: subscriptions
        )

        try await repository.replaceTopAssets(
            [makeCoinMarket(price: nil)], fetchedAt: .now
        )
        let record = try XCTUnwrap(
            ModelContext(container).fetch(FetchDescriptor<AssetRecord>()).first
        )
        XCTAssertNil(record.snapshotPrice)
        XCTAssertEqual(record.livePrice, 110)
    }

    func test_emptySnapshotFailurePreservesPreviouslyCommittedRecord() async throws {
        let container = try makeContainer()
        let repository = MarketDataRepository(modelContainer: container)
        try await repository.replaceTopAssets([makeCoinMarket()], fetchedAt: .now)
        do {
            try await repository.replaceTopAssets([], fetchedAt: .now)
            XCTFail("Expected empty snapshot to fail")
        } catch MarketDataRepositoryError.emptySnapshot {
            let records = try ModelContext(container).fetch(FetchDescriptor<AssetRecord>())
            XCTAssertEqual(records.count, 1)
            XCTAssertEqual(records.first?.snapshotPrice, 100)
        }
    }

    func test_chartReplacementDoesNotExposeMixedOldAndNewSamples() async throws {
        let container = try makeContainer()
        let repository = MarketDataRepository(modelContainer: container)
        try await repository.replacePriceHistory(
            coinGeckoID: "bitcoin",
            points: [PricePoint(date: Date(timeIntervalSince1970: 1), price: 1)]
        )
        try await repository.replacePriceHistory(
            coinGeckoID: "bitcoin",
            points: [
                PricePoint(date: Date(timeIntervalSince1970: 3), price: 3),
                PricePoint(date: Date(timeIntervalSince1970: 2), price: 2)
            ]
        )

        let context = ModelContext(container)
        var descriptor = FetchDescriptor<PricePointRecord>(
            sortBy: [SortDescriptor(\.date)]
        )
        descriptor.predicate = #Predicate { $0.coinGeckoID == "bitcoin" }
        let points = try context.fetch(descriptor)

        XCTAssertEqual(points.map(\.price), [2, 3])
    }

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: AssetRecord.self,
            FavoriteRecord.self,
            PricePointRecord.self,
            configurations: configuration
        )
    }
}
