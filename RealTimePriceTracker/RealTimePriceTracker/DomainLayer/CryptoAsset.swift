//
//  CryptoAsset.swift
//  RealTimePriceTracker
//
//  Created by Константин Клинов on 19/05/26.
//

import Foundation

/// Provider-neutral transport value for one market ticker.
///
/// Financial values use `Decimal` to avoid binary floating-point display errors.
/// It crosses actor boundaries but never reaches UI directly. Equality deliberately
/// ignores `lastUpdated`; an unchanged ticker still proves transport freshness.
nonisolated struct CryptoAsset: Identifiable, Equatable, Sendable {
    let id: String
    let symbol: String
    let price: Decimal
    let change24h: Decimal
    var lastUpdated: Date = Date()

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id &&
        lhs.symbol == rhs.symbol &&
        lhs.price == rhs.price &&
        lhs.change24h == rhs.change24h
    }
}
