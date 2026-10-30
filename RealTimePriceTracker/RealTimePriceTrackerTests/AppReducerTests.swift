import XCTest
@testable import RealTimePriceTracker

@MainActor
final class AppReducerTests: XCTestCase {
    func test_favoriteMutationCommitsBeforeRealtimeSubscriptionChanges() async {
        let bitcoin = makeCoinMarket()
        let repository = MockMarketDataRepository(assets: [bitcoin])
        let liveSync = MockLivePricesSyncService()
        let reducer = makeReducer(repository: repository, liveSync: liveSync)
        var state = AppState(isFavoritesVisible: true)

        let mutation = reducer.reduce(
            state: &state,
            action: .toggleFavorite(coinGeckoID: bitcoin.id)
        )

        XCTAssertTrue(state.markets.subscriptions.isEmpty)
        guard case let .run(_, operation) = mutation,
              case .favoriteSubscriptionsLoaded(.success(let subscriptions))? = await operation() else {
            return XCTFail("Expected subscriptions only after persistence")
        }

        _ = reducer.reduce(
            state: &state,
            action: .favoriteSubscriptionsLoaded(.success(subscriptions))
        )

        XCTAssertEqual(
            state.markets.subscriptions,
            [
                FavoriteAssetSubscription(
                    coinGeckoID: "bitcoin",
                    binancePairID: "BTCUSDT"
                )
            ]
        )
        let persistedIDs = await repository.favoriteIDs
        XCTAssertEqual(persistedIDs, ["bitcoin"])
    }

    func test_bootstrapMigratesLegacyFavoritesIntoSwiftDataBoundary() async {
        let bitcoin = makeCoinMarket()
        let repository = MockMarketDataRepository(assets: [bitcoin])
        let legacy = MockLegacyFavoritesRepository(ids: [bitcoin.id])
        let reducer = makeReducer(
            repository: repository,
            legacyFavorites: legacy
        )
        var state = AppState(isFavoritesVisible: true)

        let effect = reducer.reduce(state: &state, action: .appBecameActive)
        guard case let .merge(effects) = effect,
              effects.count == 2,
              case let .run(_, bootstrap) = effects[1],
              case .persistenceBootstrapped(.success(let subscriptions))? = await bootstrap() else {
            return XCTFail("Expected legacy migration bootstrap")
        }

        _ = reducer.reduce(
            state: &state,
            action: .persistenceBootstrapped(.success(subscriptions))
        )

        XCTAssertTrue(state.didBootstrapPersistence)
        let importedIDs = await repository.importedIDs
        let remainingLegacyIDs = legacy.ids
        XCTAssertEqual(importedIDs, [bitcoin.id])
        XCTAssertEqual(remainingLegacyIDs, [])
        XCTAssertEqual(state.markets.subscriptions.first?.coinGeckoID, bitcoin.id)
    }

    func test_backgroundCancelsRefreshAndRealtimeLifecycle() {
        let repository = MockMarketDataRepository()
        let reducer = makeReducer(repository: repository)
        var state = AppState(
            markets: MarketsState(connection: .live),
            topAssets: TopAssetsState(isRefreshLoopRunning: true),
            isFavoritesVisible: true
        )

        let effect = reducer.reduce(
            state: &state,
            action: .appEnteredBackground
        )

        XCTAssertEqual(state.markets.connection, .idle)
        XCTAssertFalse(state.topAssets.isRefreshLoopRunning)
        guard case let .merge(effects) = effect, effects.count == 2 else {
            return XCTFail("Expected child cancellation effects")
        }
    }

    private func makeReducer(
        repository: MockMarketDataRepository,
        liveSync: MockLivePricesSyncService = MockLivePricesSyncService(),
        legacyFavorites: MockLegacyFavoritesRepository = MockLegacyFavoritesRepository()
    ) -> AppReducer {
        let coinGeckoSync = MockCoinGeckoSyncService()
        return AppReducer(
            marketsReducer: MarketsReducer(syncService: liveSync),
            topAssetsReducer: TopAssetsReducer(syncService: coinGeckoSync),
            assetDetailsReducer: AssetDetailsReducer(syncService: coinGeckoSync),
            repository: repository,
            legacyFavorites: legacyFavorites
        )
    }
}
