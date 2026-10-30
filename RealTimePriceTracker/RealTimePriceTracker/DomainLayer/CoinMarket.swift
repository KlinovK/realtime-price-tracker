//
//  CoinMarket.swift
//  RealTimePriceTracker
//

import Foundation

/// CoinGecko market snapshot used by the Top 100, favorites, and details features.
///
/// Financial values remain `Decimal` throughout state and formatting. The model's
/// stable identity is CoinGecko's API ID, not its non-unique ticker symbol.
nonisolated struct CoinMarket: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let symbol: String
    let name: String
    let imageURL: URL?
    let currentPrice: Decimal?
    let marketCap: Decimal?
    let marketCapRank: Int?
    let totalVolume: Decimal?
    let high24h: Decimal?
    let low24h: Decimal?
    let priceChangePercentage24h: Decimal?

    enum CodingKeys: String, CodingKey {
        case id
        case symbol
        case name
        case imageURL = "image"
        case currentPrice = "current_price"
        case marketCap = "market_cap"
        case marketCapRank = "market_cap_rank"
        case totalVolume = "total_volume"
        case high24h = "high_24h"
        case low24h = "low_24h"
        case priceChangePercentage24h = "price_change_percentage_24h"
    }

    /// Best-effort bridge to the existing Binance USDT ticker stream.
    ///
    /// - Warning: Symbols are not globally unique and not every CoinGecko asset has
    ///   a Binance USDT market. A production multi-exchange app should persist an
    ///   explicit provider-pair mapping instead of deriving it this way.
    var binanceUSDTID: String {
        "\(symbol.uppercased())USDT"
    }
}

/// One historical price sample returned by CoinGecko's market-chart endpoint.
nonisolated struct PricePoint: Equatable, Identifiable, Sendable {
    let date: Date
    let price: Decimal

    var id: Date { date }

    /// Swift Charts uses a binary floating-point plottable value at the rendering
    /// boundary; domain and state continue to retain `Decimal`.
    var chartValue: Double {
        NSDecimalNumber(decimal: price).doubleValue
    }
}
