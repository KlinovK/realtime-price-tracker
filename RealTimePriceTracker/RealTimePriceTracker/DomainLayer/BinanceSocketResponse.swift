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
