import Foundation
import SwiftData

nonisolated struct FavoriteAssetSubscription: Equatable, Hashable, Sendable {
    let coinGeckoID: String
    let binancePairID: String
}

/// Process-local receipt for the persisted fields a view has actually observed.
/// It is never persisted; evidence is cleared when a connection generation ends.
nonisolated struct LiveQuoteVersion: Equatable, Sendable {
    let updatedAt: Date
    private let valueFingerprint: Int

    init?(price: Decimal?, change24h: Decimal?, updatedAt: Date?) {
        guard let price, let updatedAt else { return nil }
        self.updatedAt = updatedAt
        var hasher = Hasher()
        hasher.combine(price)
        hasher.combine(change24h)
        valueFingerprint = hasher.finalize()
    }
}

nonisolated enum MarketDataRepositoryError: Error, Equatable, Sendable {
    case emptySnapshot
    case assetNotFound
    case persistenceFailed(String)
}

nonisolated protocol MarketDataRepositoryProtocol: Sendable {
    func replaceTopAssets(_ assets: [CoinMarket], fetchedAt: Date) async throws
    func replacePriceHistory(
        coinGeckoID: String,
        points: [PricePoint]
    ) async throws
    func toggleFavorite(coinGeckoID: String) async throws
    func favoriteSubscriptions() async throws -> [FavoriteAssetSubscription]
    func applyLiveQuotes(
        _ quotes: [CryptoAsset],
        subscriptions: [FavoriteAssetSubscription]
    ) async throws -> [String: LiveQuoteVersion]
    func importLegacyFavorites(_ coinGeckoIDs: Set<String>) async throws
}

/// The sole mutation boundary for app market data.
///
/// `@ModelActor` gives every operation one serial SwiftData context. A complete
/// CoinGecko response, a Binance batch, or a chart replacement is committed with
/// one `save()`, so `@Query` observers cannot see partially applied provider data.
@ModelActor
actor MarketDataRepository: MarketDataRepositoryProtocol {
    func replaceTopAssets(
        _ assets: [CoinMarket],
        fetchedAt: Date
    ) throws {
        let normalizedAssets = Dictionary(
            assets.lazy
                .filter { !$0.id.isEmpty }
                .map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        guard !normalizedAssets.isEmpty else {
            throw MarketDataRepositoryError.emptySnapshot
        }

        do {
            let records = try modelContext.fetch(FetchDescriptor<AssetRecord>())
            let favoriteIDs = try favoriteIDs()
            var recordsByID = Dictionary(
                uniqueKeysWithValues: records.map { ($0.coinGeckoID, $0) }
            )

            for (coinGeckoID, market) in normalizedAssets {
                if let record = recordsByID.removeValue(forKey: coinGeckoID) {
                    update(record, from: market, fetchedAt: fetchedAt)
                } else {
                    modelContext.insert(makeRecord(from: market, fetchedAt: fetchedAt))
                }
            }

            for record in recordsByID.values {
                record.isTopAsset = false
                if !favoriteIDs.contains(record.coinGeckoID) {
                    modelContext.delete(record)
                }
            }

            try commit()
        } catch let error as MarketDataRepositoryError {
            throw error
        } catch {
            modelContext.rollback()
            throw MarketDataRepositoryError.persistenceFailed(
                error.localizedDescription
            )
        }
    }

    func replacePriceHistory(
        coinGeckoID: String,
        points: [PricePoint]
    ) throws {
        do {
            let selectedID = coinGeckoID
            let descriptor = FetchDescriptor<PricePointRecord>(
                predicate: #Predicate { $0.coinGeckoID == selectedID }
            )
            try modelContext.fetch(descriptor).forEach(modelContext.delete)

            for point in points.sorted(by: { $0.date < $1.date }) {
                modelContext.insert(
                    PricePointRecord(
                        coinGeckoID: coinGeckoID,
                        date: point.date,
                        price: point.price
                    )
                )
            }

            try commit()
        } catch {
            modelContext.rollback()
            throw MarketDataRepositoryError.persistenceFailed(
                error.localizedDescription
            )
        }
    }

    func toggleFavorite(coinGeckoID: String) throws {
        do {
            let selectedID = coinGeckoID
            var descriptor = FetchDescriptor<FavoriteRecord>(
                predicate: #Predicate { $0.coinGeckoID == selectedID }
            )
            descriptor.fetchLimit = 1

            if let favorite = try modelContext.fetch(descriptor).first {
                modelContext.delete(favorite)
                if let asset = try assetRecord(coinGeckoID: coinGeckoID) {
                    asset.livePrice = nil
                    asset.liveChange24h = nil
                    asset.liveUpdatedAt = nil
                }
            } else {
                guard try assetRecord(coinGeckoID: coinGeckoID) != nil else {
                    throw MarketDataRepositoryError.assetNotFound
                }
                modelContext.insert(
                    FavoriteRecord(coinGeckoID: coinGeckoID, addedAt: .now)
                )
            }

            try commit()
        } catch let error as MarketDataRepositoryError {
            modelContext.rollback()
            throw error
        } catch {
            modelContext.rollback()
            throw MarketDataRepositoryError.persistenceFailed(
                error.localizedDescription
            )
        }
    }

    func favoriteSubscriptions() throws -> [FavoriteAssetSubscription] {
        do {
            let favoriteIDs = try favoriteIDs()
            let records = try modelContext.fetch(FetchDescriptor<AssetRecord>())
            return records
                .filter { favoriteIDs.contains($0.coinGeckoID) }
                .sorted(by: assetOrder)
                .map {
                    FavoriteAssetSubscription(
                        coinGeckoID: $0.coinGeckoID,
                        binancePairID: $0.binancePairID
                    )
                }
        } catch {
            throw MarketDataRepositoryError.persistenceFailed(
                error.localizedDescription
            )
        }
    }

    func applyLiveQuotes(
        _ quotes: [CryptoAsset],
        subscriptions: [FavoriteAssetSubscription]
    ) throws -> [String: LiveQuoteVersion] {
        guard !quotes.isEmpty, !subscriptions.isEmpty else { return [:] }

        do {
            try Task.checkCancellation()
            let favoriteIDs = try favoriteIDs()
            let subscriptionsByPair = Dictionary(
                grouping: subscriptions,
                by: \FavoriteAssetSubscription.binancePairID
            )
            // A ticker symbol is not a globally unique CoinGecko identity. If two
            // favorites map to the same Binance pair, applying that quote to both
            // would corrupt data, so ambiguous mappings deliberately stay snapshot-only.
            let unambiguousCoinIDByPair = subscriptionsByPair.compactMapValues {
                $0.count == 1 ? $0[0].coinGeckoID : nil
            }
            let latestQuoteByPair = Dictionary(
                quotes.map { ($0.id.uppercased(), $0) },
                uniquingKeysWith: { _, latest in latest }
            )
            var committedVersions: [String: LiveQuoteVersion] = [:]

            for (pairID, quote) in latestQuoteByPair {
                guard let coinGeckoID = unambiguousCoinIDByPair[pairID],
                      favoriteIDs.contains(coinGeckoID),
                      let record = try assetRecord(coinGeckoID: coinGeckoID) else {
                    continue
                }
                record.livePrice = quote.price
                record.liveChange24h = quote.change24h
                record.liveUpdatedAt = quote.lastUpdated
                committedVersions[coinGeckoID] = LiveQuoteVersion(
                    price: record.livePrice,
                    change24h: record.liveChange24h,
                    updatedAt: record.liveUpdatedAt
                )
            }

            try Task.checkCancellation()
            try commit()
            return committedVersions
        } catch is CancellationError {
            modelContext.rollback()
            throw CancellationError()
        } catch {
            modelContext.rollback()
            throw MarketDataRepositoryError.persistenceFailed(
                error.localizedDescription
            )
        }
    }

    func importLegacyFavorites(_ coinGeckoIDs: Set<String>) throws {
        guard !coinGeckoIDs.isEmpty else { return }

        do {
            let existingIDs = try favoriteIDs()
            for coinGeckoID in coinGeckoIDs.subtracting(existingIDs).sorted() {
                modelContext.insert(
                    FavoriteRecord(coinGeckoID: coinGeckoID, addedAt: .now)
                )
            }
            try commit()
        } catch {
            modelContext.rollback()
            throw MarketDataRepositoryError.persistenceFailed(
                error.localizedDescription
            )
        }
    }
}

private extension MarketDataRepository {
    func favoriteIDs() throws -> Set<String> {
        Set(
            try modelContext.fetch(FetchDescriptor<FavoriteRecord>())
                .map(\.coinGeckoID)
        )
    }

    func assetRecord(coinGeckoID: String) throws -> AssetRecord? {
        let selectedID = coinGeckoID
        var descriptor = FetchDescriptor<AssetRecord>(
            predicate: #Predicate { $0.coinGeckoID == selectedID }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func makeRecord(from market: CoinMarket, fetchedAt: Date) -> AssetRecord {
        AssetRecord(
            coinGeckoID: market.id,
            symbol: market.symbol,
            name: market.name,
            imageURL: market.imageURL,
            snapshotPrice: market.currentPrice,
            marketCap: market.marketCap,
            marketCapRank: market.marketCapRank,
            totalVolume: market.totalVolume,
            high24h: market.high24h,
            low24h: market.low24h,
            snapshotChange24h: market.priceChangePercentage24h,
            snapshotUpdatedAt: fetchedAt,
            binancePairID: market.binanceUSDTID
        )
    }

    func update(
        _ record: AssetRecord,
        from market: CoinMarket,
        fetchedAt: Date
    ) {
        record.symbol = market.symbol
        record.name = market.name
        record.imageURL = market.imageURL
        record.snapshotPrice = market.currentPrice
        record.marketCap = market.marketCap
        record.marketCapRank = market.marketCapRank
        record.totalVolume = market.totalVolume
        record.high24h = market.high24h
        record.low24h = market.low24h
        record.snapshotChange24h = market.priceChangePercentage24h
        record.snapshotUpdatedAt = fetchedAt
        record.isTopAsset = true
        record.binancePairID = market.binanceUSDTID
        if market.currentPrice != nil {
            record.livePrice = nil
            record.liveChange24h = nil
            record.liveUpdatedAt = nil
        }
    }

    func assetOrder(_ lhs: AssetRecord, _ rhs: AssetRecord) -> Bool {
        let lhsRank = lhs.marketCapRank ?? .max
        let rhsRank = rhs.marketCapRank ?? .max
        if lhsRank != rhsRank { return lhsRank < rhsRank }
        return lhs.coinGeckoID < rhs.coinGeckoID
    }

    func commit() throws {
        guard modelContext.hasChanges else { return }
        try modelContext.save()
    }
}
