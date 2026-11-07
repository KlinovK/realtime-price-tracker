import Foundation
@testable import RealTimePriceTracker

actor MockCoinGeckoSyncService: CoinGeckoSyncServiceProtocol {
    var topSyncDate = Date(timeIntervalSince1970: 100)
    var topError: (any Error)?
    var chartError: (any Error)?
    private(set) var topCalls = 0
    private(set) var chartIDs: [String] = []

    func refreshTopAssets() async throws -> Date {
        topCalls += 1
        if let topError { throw topError }
        return topSyncDate
    }

    func refreshPriceHistory(coinGeckoID: String) async throws {
        chartIDs.append(coinGeckoID)
        if let chartError { throw chartError }
    }
}

nonisolated final class MockLivePricesSyncService:
    LivePricesSyncServiceProtocol,
    @unchecked Sendable {
    private let lock = NSLock()
    private var recordedSubscriptions: [[FavoriteAssetSubscription]] = []
    private var continuation: AsyncStream<LivePricesSyncEvent>.Continuation?

    var subscriptions: [[FavoriteAssetSubscription]] {
        lock.withLock { recordedSubscriptions }
    }

    func start(
        subscriptions: [FavoriteAssetSubscription]
    ) -> AsyncStream<LivePricesSyncEvent> {
        lock.withLock { recordedSubscriptions.append(subscriptions) }
        return AsyncStream { continuation in
            lock.withLock { self.continuation = continuation }
        }
    }

    func yield(_ event: LivePricesSyncEvent) {
        lock.withLock { continuation }?.yield(event)
    }
}

actor MockMarketDataRepository: MarketDataRepositoryProtocol {
    private(set) var favoriteIDs: Set<String>
    private(set) var importedIDs: Set<String> = []
    private(set) var liveQuoteBatches: [[CryptoAsset]] = []
    var liveQuoteError: (any Error)?
    var assetsByID: [String: CoinMarket]

    init(
        favoriteIDs: Set<String> = [],
        assets: [CoinMarket] = []
    ) {
        self.favoriteIDs = favoriteIDs
        self.assetsByID = Dictionary(
            uniqueKeysWithValues: assets.map { ($0.id, $0) }
        )
    }

    func setLiveQuoteError(_ error: any Error) {
        liveQuoteError = error
    }

    func replaceTopAssets(_ assets: [CoinMarket], fetchedAt: Date) async throws {
        assetsByID = Dictionary(uniqueKeysWithValues: assets.map { ($0.id, $0) })
    }

    func replacePriceHistory(
        coinGeckoID: String,
        points: [PricePoint]
    ) async throws {}

    func toggleFavorite(coinGeckoID: String) async throws {
        if favoriteIDs.contains(coinGeckoID) {
            favoriteIDs.remove(coinGeckoID)
        } else {
            favoriteIDs.insert(coinGeckoID)
        }
    }

    func favoriteSubscriptions() async throws -> [FavoriteAssetSubscription] {
        favoriteIDs.compactMap { id in
            assetsByID[id].map {
                FavoriteAssetSubscription(
                    coinGeckoID: id,
                    binancePairID: $0.binanceUSDTID
                )
            }
        }
        .sorted { $0.coinGeckoID < $1.coinGeckoID }
    }

    func applyLiveQuotes(
        _ quotes: [CryptoAsset],
        subscriptions: [FavoriteAssetSubscription]
    ) async throws -> [String: LiveQuoteVersion] {
        liveQuoteBatches.append(quotes)
        if let liveQuoteError { throw liveQuoteError }
        let quotesByPair = Dictionary(
            quotes.map { ($0.id.uppercased(), $0) },
            uniquingKeysWith: { _, latest in latest }
        )
        return Dictionary(uniqueKeysWithValues: subscriptions.compactMap { subscription in
            guard let quote = quotesByPair[subscription.binancePairID],
                  let version = LiveQuoteVersion(
                      price: quote.price,
                      change24h: quote.change24h,
                      updatedAt: quote.lastUpdated
                  ) else { return nil }
            return (subscription.coinGeckoID, version)
        })
    }

    func importLegacyFavorites(_ coinGeckoIDs: Set<String>) async throws {
        importedIDs.formUnion(coinGeckoIDs)
        favoriteIDs.formUnion(coinGeckoIDs)
    }
}

nonisolated final class MockLegacyFavoritesRepository:
    FavoritesRepositoryProtocol,
    @unchecked Sendable {
    private let lock = NSLock()
    private var storedIDs: Set<String>

    init(ids: Set<String> = []) {
        storedIDs = ids
    }

    var ids: Set<String> {
        lock.withLock { storedIDs }
    }

    func loadIDs() async -> Set<String> { ids }
    func saveIDs(_ ids: Set<String>) async {
        lock.withLock { storedIDs = ids }
    }
}

nonisolated func makeCoinMarket(
    id: String = "bitcoin",
    symbol: String = "btc",
    rank: Int = 1,
    price: Decimal? = 100
) -> CoinMarket {
    CoinMarket(
        id: id,
        symbol: symbol,
        name: id.capitalized,
        imageURL: URL(string: "https://example.com/\(symbol).png"),
        currentPrice: price,
        marketCap: 1_000,
        marketCapRank: rank,
        totalVolume: 500,
        high24h: 110,
        low24h: 90,
        priceChangePercentage24h: 2
    )
}
