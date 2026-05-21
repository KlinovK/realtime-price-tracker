//
//  AssetHeatCellFormatting.swift
//  RealTimePriceTracker
//
//  Created by Константин Клинов on 21/05/26.
//

import Foundation

enum AssetHeatCellFormatting {

    /// Shortens symbol for compact grid layout.
    static func shortSymbol(_ symbol: String) -> String {
        String(symbol.prefix(4)).uppercased()
    }

    /// Formats price with consistent precision.
    static func formatPrice(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    /// Formats percentage change with sign.
    static func formatChange(_ value: Double) -> String {
        String(format: "%+.2f%%", value)
    }
}

