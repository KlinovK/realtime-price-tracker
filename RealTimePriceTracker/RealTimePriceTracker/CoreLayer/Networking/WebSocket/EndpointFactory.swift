//
//  Endpoint.swift
//  RealTimePriceTracker
//
//  Created by Константин Клинов on 19/05/26.
//

import Foundation

/// Factory responsible for building Binance WebSocket endpoints.
///
/// `EndpointFactory`:
/// - Converts symbol configurations into WebSocket stream URLs
/// - Groups streams into safe-sized chunks for iOS reliability
/// - Ensures valid Binance combined stream formatting
enum EndpointFactory {

    // MARK: - Configuration

    /// Binance combined WebSocket base URL.
    ///
    /// Format:
    /// `wss://stream.binance.com:9443/stream?streams=`
    private static let baseURL =
        "wss://stream.binance.com:9443/stream?streams="

    /// Maximum number of streams per WebSocket connection.
    ///
    /// Although Binance allows higher limits,
    /// smaller batches improve stability on mobile clients.
    private static let maxStreamsPerSocket = 25

    // MARK: - Public API

    /// Creates WebSocket URLs from a stream configuration.
    ///
    /// The function:
    /// 1. Builds Binance stream identifiers (e.g. `btcusdt@ticker`)
    /// 2. Splits them into chunks for safer connections
    /// 3. Converts each chunk into a valid WebSocket URL
    ///
    /// Example stream format:
    /// `btcusdt@ticker/ethusdt@ticker`
    ///
    /// - Parameter configuration:
    ///   Configuration containing symbols and stream type.
    ///
    /// - Returns:
    ///   Array of valid Binance WebSocket URLs.
    static func makeURLs(
        configuration: StreamConfiguration
    ) -> [URL] {

        let streams = configuration.symbols.map { symbol in
            "\(symbol.lowercased())\(configuration.streamType.rawValue)"
        }

        let chunks = streams.chunked(into: maxStreamsPerSocket)

        return chunks.compactMap { chunk in
            let joinedStreams = chunk.joined(separator: "/")
            return URL(string: baseURL + joinedStreams)
        }
    }
}

