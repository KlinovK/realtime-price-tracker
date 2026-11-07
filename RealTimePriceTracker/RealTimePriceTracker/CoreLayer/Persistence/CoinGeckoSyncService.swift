import Foundation

nonisolated protocol CoinGeckoSyncServiceProtocol: Sendable {
    func refreshTopAssets() async throws -> Date
    func refreshPriceHistory(coinGeckoID: String) async throws
}

/// Application use case that commits provider responses before reporting success.
/// Reducers therefore transition to `loaded` only after SwiftData is consistent.
nonisolated struct CoinGeckoSyncService: CoinGeckoSyncServiceProtocol {
    private let client: any CoinGeckoClientProtocol
    private let repository: any MarketDataRepositoryProtocol
    private let now: @Sendable () -> Date

    init(
        client: any CoinGeckoClientProtocol,
        repository: any MarketDataRepositoryProtocol,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.client = client
        self.repository = repository
        self.now = now
    }

    func refreshTopAssets() async throws -> Date {
        let assets = try await client.fetchTopAssets(limit: 100)
        guard !assets.isEmpty else {
            throw MarketDataRepositoryError.emptySnapshot
        }
        let fetchedAt = now()
        try await repository.replaceTopAssets(assets, fetchedAt: fetchedAt)
        return fetchedAt
    }

    func refreshPriceHistory(coinGeckoID: String) async throws {
        let points = try await client.fetchPriceChart(
            coinID: coinGeckoID,
            days: 7
        )
        try await repository.replacePriceHistory(
            coinGeckoID: coinGeckoID,
            points: points
        )
    }
}
