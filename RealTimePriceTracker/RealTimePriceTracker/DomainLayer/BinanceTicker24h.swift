//
//  BinanceTicker24h.swift
//  RealTimePriceTracker
//
//  Created by Константин Клинов on 19/05/26.
//

import Foundation

struct BinanceTicker24h: Decodable {
    let symbol: String
    let quoteVolume: String
    let priceChangePercent: String
}
