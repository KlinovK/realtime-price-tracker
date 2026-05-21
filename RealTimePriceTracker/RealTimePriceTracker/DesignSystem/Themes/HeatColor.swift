//
//  HeatColor.swift
//  RealTimePriceTracker
//
//  Created by Константин Клинов on 19/05/26.
//

import SwiftUI

/// A utility for mapping market performance values into visually meaningful colors.
///
/// `HeatColor` is designed for crypto/market UIs where price movement
/// needs to be expressed as a "heat map" style indicator.
///
/// The intensity of the color reflects the magnitude of change:
/// - Strong negative → deep red
/// - Mild negative → soft red
/// - Neutral → muted green
/// - Positive → stronger greens
/// - Strong positive → bright green
enum HeatColor {

    // MARK: - Public API

    enum Bucket: Equatable {
        case deepRed
        case strongRed
        case softRed
        case neutral
        case softGreen
        case strongGreen
        case brightGreen
    }

    static func bucket(for change: Double) -> Bucket {
        switch change {
        case ..<(-10):
            return .deepRed
        case -10..<(-5):
            return .strongRed
        case -5..<0:
            return .softRed
        case 0..<1:
            return .neutral
        case 1..<3:
            return .softGreen
        case 3..<6:
            return .strongGreen
        default:
            return .brightGreen
        }
    }

    /// Returns a semantic color representing market performance.
    ///
    /// This creates a "heat map" effect for price changes, making it
    /// easier to visually scan market momentum.
    ///
    /// Example:
    /// ```swift
    /// HeatColor.color(for: -7.2) // strong red
    /// HeatColor.color(for: 3.5)  // medium green
    /// ```
    ///
    /// - Parameter change:
    ///   Percentage change (e.g. `-3.2`, `+4.8`).
    ///
    /// - Returns:
    ///   A SwiftUI `Color` representing intensity of movement.
    static func color(for change: Double) -> Color {
        switch bucket(for: change) {
        case .deepRed:
            return Self.deepRed
        case .strongRed:
            return Self.strongRed
        case .softRed:
            return Self.softRed
        case .neutral:
            return Self.neutral
        case .softGreen:
            return Self.softGreen
        case .strongGreen:
            return Self.strongGreen
        case .brightGreen:
            return Self.brightGreen
        }
    }
}

// MARK: - Design System Colors

private extension HeatColor {

    static let deepRed = Color.red.opacity(0.95)
    static let strongRed = Color.red.opacity(0.75)
    static let softRed = Color.red.opacity(0.35)

    static let neutral = Color.gray.opacity(0.2)

    static let softGreen = Color.green.opacity(0.35)
    static let strongGreen = Color.green.opacity(0.65)
    static let brightGreen = Color.green.opacity(0.9)
}
