//
//  MarketsService.swift
//  RealTimePriceTracker
//
//  Created by Константин Клинов on 19/05/26.
//

import Foundation

/// Service responsible for managing real-time market data streams.
///
/// `MarketsService`:
/// - Creates and manages websocket connections
/// - Streams incoming websocket messages
/// - Handles websocket lifecycle management
/// - Exposes a unified async stream interface
@MainActor
final class MarketsService {

    // MARK: - Properties

    /// Active websocket connections.
    private var sockets: [WebSocketClient] = []

    // MARK: - Public Methods

    /// Stops all active websocket streams.
    func stopStreaming() {
        sockets.forEach { $0.disconnect() }
        sockets.removeAll()
    }

    /// Starts streaming market data from websocket URLs.
    ///
    /// - Parameter urls:
    ///   Websocket endpoint URLs.
    ///
    /// - Returns:
    ///   Stream of `MarketsAction` events.
    func startStreaming(
        with urls: [URL]
    ) -> AsyncStream<MarketsAction> {

        AsyncStream { continuation in
            sockets = urls.map(WebSocketClient.init)
            for socket in sockets {
                Task {
                    socket.connect()
                    do {
                        for try await message in socket.stream() {
                            continuation.yield(
                                .websocketMessage(message)
                            )
                        }
                    } catch {
                        continuation.yield(
                            .websocketFailed(error)
                        )
                    }
                }
            }
            continuation.onTermination = { [self] _ in
                Task { @MainActor in
                    stopStreaming()
                }
            }
        }
    }
}
