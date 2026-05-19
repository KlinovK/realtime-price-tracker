//
//  HeatColor.swift
//  RealTimePriceTracker
//
//  Created by Константин Клинов on 19/05/26.
//

import SwiftUI

enum HeatColor {

    static func color(for change: Double) -> Color {

        switch change {

        case ..<(-5):
            return Color.red.opacity(0.9)

        case -5..<0:
            return Color.red.opacity(0.4)

        case 0..<2:
            return Color.green.opacity(0.25)

        case 2..<5:
            return Color.green.opacity(0.55)

        default:
            return Color.green.opacity(0.85)
        }
    }
}
