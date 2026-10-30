//
//  MarketValueFormatting.swift
//  RealTimePriceTracker
//

import Foundation

@MainActor
enum MarketValueFormatting {
    static func price(_ value: Decimal?) -> String {
        guard let value else { return "—" }
        return "$\(AssetHeatCellFormatting.formatPrice(value))"
    }

    static func percentage(_ value: Decimal?) -> String {
        guard let value else { return "—" }
        return AssetHeatCellFormatting.formatChange(value)
    }

    static func compactCurrency(_ value: Decimal?) -> String {
        guard let value else { return "—" }
        let doubleValue = NSDecimalNumber(decimal: value).doubleValue
        return doubleValue.formatted(
            .currency(code: "USD")
                .notation(.compactName)
                .precision(.fractionLength(0...2))
        )
    }
}
