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
            isApprovedPair: true,
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
            isApprovedPair: true,
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

    func test_duplicateTickersDoNotAuthorizeUnknownFavorites() async throws {
        let container = try makeContainer()
        let repository = MarketDataRepository(modelContainer: container)
        try await repository.replaceTopAssets(
            [
                makeCoinMarket(id: "bitcoin", symbol: "btc", rank: 1),
                makeCoinMarket(id: "impostor", symbol: "btc", rank: 2)
            ],
            fetchedAt: .now
        )
        try await repository.toggleFavorite(coinGeckoID: "bitcoin")
        try await repository.toggleFavorite(coinGeckoID: "impostor")
        let subscriptions = try await repository.favoriteSubscriptions()
        XCTAssertEqual(
            subscriptions,
            [FavoriteAssetSubscription(coinGeckoID: "bitcoin", binancePairID: "BTCUSDT")]
        )

        let committed = try await repository.applyLiveQuotes(
            [
                CryptoAsset(
                    id: "BTCUSDT",
                    symbol: "BTCUSDT",
                    price: 999,
                    change24h: 99
                )
            ],
            subscriptions: subscriptions
        )
        XCTAssertEqual(Set(committed.keys), ["bitcoin"])

        let context = ModelContext(container)
        let assets = try context.fetch(FetchDescriptor<AssetRecord>())
        let byID = Dictionary(uniqueKeysWithValues: assets.map { ($0.coinGeckoID, $0) })
        XCTAssertEqual(byID["bitcoin"]?.livePrice, 999)
        XCTAssertNil(byID["impostor"]?.livePrice)
        XCTAssertEqual(byID["impostor"]?.snapshotPrice, 100)
        XCTAssertEqual(byID["impostor"]?.binancePairID, "")
    }

    func test_singleFavoritedImpostorAndLegacyPairCannotAuthorizeQuote() async throws {
        let container = try makeContainer()
        try seedLegacyFavorite(
            in: container,
            id: "impostor",
            pairID: "BTCUSDT",
            snapshotPrice: 100,
            livePrice: 999
        )
        let repository = MarketDataRepository(modelContainer: container)

        let subscriptions = try await repository.favoriteSubscriptions()
        XCTAssertTrue(subscriptions.isEmpty)
        let committed = try await repository.applyLiveQuotes(
            [CryptoAsset(id: "BTCUSDT", symbol: "BTCUSDT", price: 500, change24h: 5)],
            subscriptions: [
                FavoriteAssetSubscription(coinGeckoID: "impostor", binancePairID: "BTCUSDT")
            ]
        )
        XCTAssertTrue(committed.isEmpty)

        let context = ModelContext(container)
        let record = try XCTUnwrap(context.fetch(FetchDescriptor<AssetRecord>()).first)
        XCTAssertEqual(record.livePrice, 999)
        XCTAssertEqual(
            try context.fetch(FetchDescriptor<FavoriteRecord>()).map(\.coinGeckoID),
            ["impostor"]
        )
        let presentation = FavoritePricePresentation(
            snapshotPrice: record.snapshotPrice,
            snapshotChange24h: record.snapshotChange24h,
            livePrice: record.livePrice,
            liveChange24h: record.liveChange24h,
            liveUpdatedAt: record.liveUpdatedAt,
            isApprovedPair: BinancePairRegistry.approved.approves(
                coinGeckoID: record.coinGeckoID,
                pairID: record.binancePairID
            ),
            committedVersion: LiveQuoteVersion(
                price: record.livePrice,
                change24h: record.liveChange24h,
                updatedAt: record.liveUpdatedAt
            ),
            connection: .live
        )
        XCTAssertEqual(presentation.price, 100)
        XCTAssertEqual(presentation.status, .snapshot)
    }

    func test_legacyPairForApprovedIDIsIgnoredUntilApprovedQuoteCommits() async throws {
        let container = try makeContainer()
        try seedLegacyFavorite(
            in: container,
            id: "bitcoin",
            pairID: "OLDUSDT",
            snapshotPrice: 100,
            livePrice: 999
        )
        let repository = MarketDataRepository(modelContainer: container)
        let subscriptions = try await repository.favoriteSubscriptions()
        XCTAssertEqual(
            subscriptions,
            [FavoriteAssetSubscription(coinGeckoID: "bitcoin", binancePairID: "BTCUSDT")]
        )
        let rejected = try await repository.applyLiveQuotes(
            [CryptoAsset(id: "OLDUSDT", symbol: "OLDUSDT", price: 500, change24h: 5)],
            subscriptions: [
                FavoriteAssetSubscription(coinGeckoID: "bitcoin", binancePairID: "OLDUSDT")
            ]
        )
        XCTAssertTrue(rejected.isEmpty)
        let beforeApprovedCommit = try XCTUnwrap(
            ModelContext(container).fetch(FetchDescriptor<AssetRecord>()).first
        )
        XCTAssertEqual(beforeApprovedCommit.binancePairID, "OLDUSDT")
        XCTAssertEqual(beforeApprovedCommit.livePrice, 999)
        XCTAssertEqual(beforeApprovedCommit.snapshotPrice, 100)
        let committed = try await repository.applyLiveQuotes(
            [CryptoAsset(id: "BTCUSDT", symbol: "BTCUSDT", price: 110, change24h: 1)],
            subscriptions: subscriptions
        )
        XCTAssertEqual(Set(committed.keys), ["bitcoin"])
        let record = try XCTUnwrap(
            ModelContext(container).fetch(FetchDescriptor<AssetRecord>()).first
        )
        XCTAssertEqual(record.binancePairID, "BTCUSDT")
        XCTAssertEqual(record.livePrice, 110)
    }

    func test_unknownIncomingPairDoesNotUpdateApprovedFavorite() async throws {
        let container = try makeContainer()
        let repository = MarketDataRepository(modelContainer: container)
        try await repository.replaceTopAssets([makeCoinMarket()], fetchedAt: .now)
        try await repository.toggleFavorite(coinGeckoID: "bitcoin")
        let subscriptions = try await repository.favoriteSubscriptions()

        let committed = try await repository.applyLiveQuotes(
            [CryptoAsset(id: "OTHERUSDT", symbol: "OTHERUSDT", price: 500, change24h: 5)],
            subscriptions: subscriptions
        )
        XCTAssertTrue(committed.isEmpty)
        let record = try XCTUnwrap(
            ModelContext(container).fetch(FetchDescriptor<AssetRecord>()).first
        )
        XCTAssertNil(record.livePrice)
        XCTAssertEqual(record.snapshotPrice, 100)
    }

    func test_unknownFavoriteRemainsSnapshotOnlyAfterRefresh() async throws {
        let container = try makeContainer()
        let repository = MarketDataRepository(modelContainer: container)
        try await repository.replaceTopAssets(
            [makeCoinMarket(id: "impostor", symbol: "btc")],
            fetchedAt: Date(timeIntervalSince1970: 1)
        )
        try await repository.toggleFavorite(coinGeckoID: "impostor")
        try await repository.replaceTopAssets(
            [makeCoinMarket(id: "impostor", symbol: "btc", price: 120)],
            fetchedAt: Date(timeIntervalSince1970: 2)
        )

        let subscriptions = try await repository.favoriteSubscriptions()
        XCTAssertTrue(subscriptions.isEmpty)
        let context = ModelContext(container)
        let record = try XCTUnwrap(context.fetch(FetchDescriptor<AssetRecord>()).first)
        XCTAssertEqual(record.snapshotPrice, 120)
        XCTAssertEqual(record.binancePairID, "")
        XCTAssertEqual(
            try context.fetch(FetchDescriptor<FavoriteRecord>()).map(\.coinGeckoID),
            ["impostor"]
        )
    }

    func test_snapshotRefreshClearsLegacyQuoteWhenPairChangesWithoutSnapshotPrice() async throws {
        let container = try makeContainer()
        try seedLegacyFavorite(
            in: container,
            id: "bitcoin",
            pairID: "OLDUSDT",
            snapshotPrice: nil,
            livePrice: 999
        )
        let repository = MarketDataRepository(modelContainer: container)
        try await repository.replaceTopAssets(
            [makeCoinMarket(price: nil)],
            fetchedAt: Date(timeIntervalSince1970: 2)
        )
        let context = ModelContext(container)
        let record = try XCTUnwrap(context.fetch(FetchDescriptor<AssetRecord>()).first)
        XCTAssertEqual(record.binancePairID, "BTCUSDT")
        XCTAssertNil(record.livePrice)
        XCTAssertEqual(
            try context.fetch(FetchDescriptor<FavoriteRecord>()).map(\.coinGeckoID),
            ["bitcoin"]
        )
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

    private func seedLegacyFavorite(
        in container: ModelContainer,
        id: String,
        pairID: String,
        snapshotPrice: Decimal?,
        livePrice: Decimal
    ) throws {
        let context = ModelContext(container)
        context.insert(AssetRecord(
            coinGeckoID: id,
            symbol: "btc",
            name: id,
            imageURL: nil,
            snapshotPrice: snapshotPrice,
            marketCap: nil,
            marketCapRank: 1,
            totalVolume: nil,
            high24h: nil,
            low24h: nil,
            snapshotChange24h: nil,
            snapshotUpdatedAt: Date(timeIntervalSince1970: 1),
            binancePairID: pairID,
            livePrice: livePrice,
            liveChange24h: 1,
            liveUpdatedAt: Date(timeIntervalSince1970: 1)
        ))
        context.insert(FavoriteRecord(coinGeckoID: id, addedAt: .now))
        try context.save()
    }
}
