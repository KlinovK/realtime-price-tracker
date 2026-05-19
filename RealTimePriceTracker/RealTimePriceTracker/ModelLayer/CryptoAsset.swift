//
//  CryptoAsset.swift
//  RealTimePriceTracker
//
//  Created by Константин Клинов on 19/05/26.
//

import Foundation

struct CryptoAsset: Identifiable, Equatable {

    let id: String
    let symbol: String
    let price: Double
    let change24h: Double

    var formattedPrice: String {
        String(format: "$%.2f", price)
    }

    var formattedChange: String {
        String(format: "%.2f%%", change24h)
    }

    var isPositive: Bool {
        change24h >= 0
    }
}
