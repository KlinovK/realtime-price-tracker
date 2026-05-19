//
//  Endpoint.swift
//  RealTimePriceTracker
//
//  Created by Константин Клинов on 19/05/26.
//

import Foundation

enum Endpoint {

    static let symbols = [
        "btcusdt", "ethusdt", "bnbusdt", "solusdt", "xrpusdt",

          "adausdt", "dogeusdt", "avaxusdt", "trxusdt", "dotusdt",

          "linkusdt", "maticusdt", "tonusdt", "shibusdt", "ltcusdt",

          "bchusdt", "uniusdt", "atomusdt", "etcusdt", "nearusdt",

          "aptusdt", "icpusdt", "filusdt", "hbarusdt", "arbusdt",

          "opust", "vetusdt", "grtusdt", "sandusdt", "manausdt",

          "aaveusdt", "algousdt", "egldusdt", "flowusdt", "axsusdt"

      
    ]

    static var streamURL: URL {

        let streams = symbols
            .map { "\($0)@ticker" }
            .joined(separator: "/")

        let urlString = "wss://stream.binance.com:9443/stream?streams=\(streams)"

        return URL(string: urlString)!
    }
}

