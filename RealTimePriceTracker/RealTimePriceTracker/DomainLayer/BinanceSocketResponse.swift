//
//  BinanceSocketResponse.swift
//  RealTimePriceTracker
//
//  Created by Константин Клинов on 19/05/26.
//

import Foundation

struct BinanceSocketResponse: Codable {

    let stream: String

    let data: BinanceTickerResponse

}

struct BinanceTickerResponse: Codable {
    let symbol: String
    let price: String
    let changePercent: String

    enum CodingKeys: String, CodingKey {
        case symbol = "s"
        case price = "c"
        case changePercent = "P"
    }
}
