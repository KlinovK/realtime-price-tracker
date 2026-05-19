//
//  Endpoint.swift
//  RealTimePriceTracker
//
//  Created by Константин Клинов on 19/05/26.
//

import Foundation

enum Endpoint {
    static let streamURL = URL(
        string: "wss://stream.binance.com:9443/stream?streams=btcusdt@ticker/ethusdt@ticker/solusdt@ticker"
    )!
}
