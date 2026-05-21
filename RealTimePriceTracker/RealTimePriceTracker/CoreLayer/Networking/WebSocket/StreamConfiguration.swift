//
//  StreamConfiguration.swift
//  RealTimePriceTracker
//
//  Created by Константин Клинов on 19/05/26.
//

import Foundation

/// Defines configuration for Binance WebSocket streaming.
///
/// `StreamConfiguration` describes:
/// - Which symbols to subscribe to
/// - Which type of market data stream to use
///
/// This configuration is used by `EndpointFactory` to generate
/// valid combined WebSocket URLs.
struct StreamConfiguration {

    /// List of Binance trading symbols (e.g. `["BTCUSDT", "ETHUSDT"]`).
    let symbols: [String]

    /// The type of WebSocket stream to subscribe to.
    ///
    /// Examples:
    /// - `@ticker` → full 24h ticker updates
    /// - `@miniTicker` → lightweight price updates
    let streamType: StreamType

    // MARK: - Stream Type

    /// Supported Binance WebSocket stream types.
    enum StreamType: String {

        /// Full 24h ticker stream with detailed market data.
        case ticker = "@ticker"

        /// Lightweight ticker stream optimized for performance.
        case miniTicker = "@miniTicker"
    }
}
