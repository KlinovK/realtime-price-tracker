//
//  BinanceTickerResponse.swift
//  RealTimePriceTracker
//
//  Created by Константин Клинов on 19/05/26.
//

import Foundation

/// Minimal subset of a Binance realtime ticker used by the application.
///
/// Prices remain strings at the transport boundary because the exchange sends JSON
/// strings. The batching actor parses them with a fixed POSIX locale into `Decimal`.
nonisolated struct BinanceTickerResponse: Codable, Sendable {
    let symbol: String
    let price: String
    let changePercent: String

    enum CodingKeys: String, CodingKey {
        case symbol = "s"
        case price = "c"
        case changePercent = "P"
    }
}
