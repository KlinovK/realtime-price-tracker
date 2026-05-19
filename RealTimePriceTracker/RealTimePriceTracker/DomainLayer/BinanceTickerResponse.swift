//
//  BinanceTickerResponse.swift
//  RealTimePriceTracker
//
//  Created by Константин Клинов on 19/05/26.
//

import Foundation

struct BinanceTicker: Codable {

    let symbol: String
    let price: String
    let changePercent: String

    enum CodingKeys: String, CodingKey {
        case symbol = "s"
        case price = "c"
        case changePercent = "P"
    }

}
