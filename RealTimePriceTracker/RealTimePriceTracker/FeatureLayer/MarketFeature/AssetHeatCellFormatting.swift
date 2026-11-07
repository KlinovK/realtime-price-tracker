//
//  AssetHeatCellFormatting.swift
//  RealTimePriceTracker
//
//  Created by Константин Клинов on 21/05/26.
//

import Foundation

@MainActor
enum AssetHeatCellFormatting {

    private struct FormatterKey: Hashable {
        let localeIdentifier: String
        let minimumFractionDigits: Int
        let maximumFractionDigits: Int
    }

    private static var formatters: [FormatterKey: NumberFormatter] = [:]

    /// Shortens symbol for compact grid layout.
    ///
    /// - Warning: Prefix truncation does not understand trading pairs: `BTCUSDT`
    ///   becomes `BTCU`. Model base/quote symbols or remove a verified quote suffix
    ///   before presenting this value.
    static func shortSymbol(_ symbol: String) -> String {
        String(symbol.prefix(4)).uppercased()
    }

    /// Uses more precision for sub-unit assets so a non-zero market price is
    /// never rendered as `0.00` merely because it is below one cent.
    static func formatPrice(
        _ value: Decimal,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        let magnitude = abs(value)
        let maximumFractionDigits: Int

        switch magnitude {
        case 1...:
            maximumFractionDigits = 2
        case 0.01...:
            maximumFractionDigits = 4
        default:
            maximumFractionDigits = 8
        }

        return formatDecimal(
            value,
            minimumFractionDigits: 2,
            maximumFractionDigits: maximumFractionDigits,
            locale: locale
        )
    }

    /// Binance already supplies `P` as percentage points, so append `%`
    /// without multiplying the value by 100.
    static func formatChange(
        _ value: Decimal,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        let sign = value < .zero ? "-" : "+"
        let magnitude = abs(value)
        let number = formatDecimal(
            magnitude,
            minimumFractionDigits: 2,
            maximumFractionDigits: 2,
            locale: locale
        )
        return "\(sign)\(number)%"
    }

    /// Small market ticks still update the text but do not start an animation.
    static func shouldPulse(
        from oldPrice: Decimal,
        to newPrice: Decimal,
        minimumRelativeChange: Decimal = 0.001
    ) -> Bool {
        guard oldPrice != 0 else { return newPrice != 0 }
        return abs((newPrice - oldPrice) / oldPrice) >= minimumRelativeChange
    }

    private static func formatDecimal(
        _ value: Decimal,
        minimumFractionDigits: Int,
        maximumFractionDigits: Int,
        locale: Locale
    ) -> String {
        let key = FormatterKey(
            localeIdentifier: locale.identifier,
            minimumFractionDigits: minimumFractionDigits,
            maximumFractionDigits: maximumFractionDigits
        )
        let formatter: NumberFormatter

        if let cachedFormatter = formatters[key] {
            formatter = cachedFormatter
        } else {
            let newFormatter = NumberFormatter()
            newFormatter.locale = locale
            newFormatter.numberStyle = .decimal
            newFormatter.usesGroupingSeparator = true
            newFormatter.minimumFractionDigits = minimumFractionDigits
            newFormatter.maximumFractionDigits = maximumFractionDigits
            newFormatter.roundingMode = .halfUp
            formatters[key] = newFormatter
            formatter = newFormatter
        }

        let number = NSDecimalNumber(decimal: value)
        return formatter.string(from: number) ?? number.stringValue
    }
}
