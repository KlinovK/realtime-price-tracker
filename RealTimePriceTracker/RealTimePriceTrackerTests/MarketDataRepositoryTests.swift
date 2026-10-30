import Foundation
import SwiftData
import XCTest
@testable import RealTimePriceTracker

@MainActor
final class MarketDataRepositoryTests: XCTestCase {
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
        try await repository.applyLiveQuotes(
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

        try await repository.applyLiveQuotes(
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

        let context = ModelContext(container)
        let assets = try context.fetch(FetchDescriptor<AssetRecord>())
        XCTAssertTrue(assets.allSatisfy { $0.livePrice == nil })
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
