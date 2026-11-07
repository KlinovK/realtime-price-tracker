//
//  BinanceTicker24h.swift
//  RealTimePriceTracker
//
//  Created by Константин Клинов on 19/05/26.
//

import Foundation

/// HTTP transport DTO used to rank markets by 24-hour quote volume.
///
/// `TopSymbolsService` validates and converts `quoteVolume` to `Decimal` before it
/// participates in business logic.
struct BinanceTicker24h: Decodable {
    let symbol: String
    let quoteVolume: String
    let priceChangePercent: String
}
