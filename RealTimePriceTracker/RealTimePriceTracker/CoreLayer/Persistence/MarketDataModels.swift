import Foundation
import SwiftData

/// The persisted CoinGecko snapshot plus the latest committed Binance quote.
///
/// Views render this model through `@Query`. Network DTOs never reach a view or
/// reducer state, which makes the database the only source of market truth.
@Model
final class AssetRecord {
    @Attribute(.unique) var coinGeckoID: String
    var symbol: String
    var name: String
    var imageURL: URL?
    var snapshotPrice: Decimal?
    var marketCap: Decimal?
    var marketCapRank: Int?
    var totalVolume: Decimal?
    var high24h: Decimal?
    var low24h: Decimal?
    var snapshotChange24h: Decimal?
    var snapshotUpdatedAt: Date
    var isTopAsset: Bool
    var binancePairID: String
    var livePrice: Decimal?
    var liveChange24h: Decimal?
    var liveUpdatedAt: Date?

    init(
        coinGeckoID: String,
        symbol: String,
        name: String,
        imageURL: URL?,
        snapshotPrice: Decimal?,
        marketCap: Decimal?,
        marketCapRank: Int?,
        totalVolume: Decimal?,
        high24h: Decimal?,
        low24h: Decimal?,
        snapshotChange24h: Decimal?,
        snapshotUpdatedAt: Date,
        isTopAsset: Bool = true,
        binancePairID: String,
        livePrice: Decimal? = nil,
        liveChange24h: Decimal? = nil,
        liveUpdatedAt: Date? = nil
    ) {
        self.coinGeckoID = coinGeckoID
        self.symbol = symbol
        self.name = name
        self.imageURL = imageURL
        self.snapshotPrice = snapshotPrice
        self.marketCap = marketCap
        self.marketCapRank = marketCapRank
        self.totalVolume = totalVolume
        self.high24h = high24h
        self.low24h = low24h
        self.snapshotChange24h = snapshotChange24h
        self.snapshotUpdatedAt = snapshotUpdatedAt
        self.isTopAsset = isTopAsset
        self.binancePairID = binancePairID
        self.livePrice = livePrice
        self.liveChange24h = liveChange24h
        self.liveUpdatedAt = liveUpdatedAt
    }

    var favoritePrice: Decimal? {
        livePrice ?? snapshotPrice
    }

    var favoriteChange24h: Decimal {
        liveChange24h ?? snapshotChange24h ?? .zero
    }
}

/// Favorites are normalized separately so a selection survives even when an
/// asset temporarily falls outside CoinGecko's Top 100.
@Model
final class FavoriteRecord {
    @Attribute(.unique) var coinGeckoID: String
    var addedAt: Date

    init(coinGeckoID: String, addedAt: Date) {
        self.coinGeckoID = coinGeckoID
        self.addedAt = addedAt
    }
}

/// Persisted chart samples keep the details screen available offline as well.
@Model
final class PricePointRecord {
    var coinGeckoID: String
    var date: Date
    var price: Decimal

    init(coinGeckoID: String, date: Date, price: Decimal) {
        self.coinGeckoID = coinGeckoID
        self.date = date
        self.price = price
    }

    var chartValue: Double {
        NSDecimalNumber(decimal: price).doubleValue
    }
}

nonisolated enum MarketDataSchema {
    static let schema = Schema([
        AssetRecord.self,
        FavoriteRecord.self,
        PricePointRecord.self
    ])
}
