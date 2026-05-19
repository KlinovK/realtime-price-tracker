//
//  MarketsService.swift
//  RealTimePriceTracker
//
//  Created by Константин Клинов on 19/05/26.
//

import Foundation

/// `MarketsService` is responsible for managing realtime market data streaming
/// using a WebSocket connection.
///
/// It acts as a bridge between the low-level `WebSocketClient` and the
/// app’s state management layer (`MarketsReducer` / `Store`).
///
/// Responsibilities:
/// - Establish WebSocket connection
/// - Listen for incoming ticker messages
/// - Convert raw messages into `MarketsAction` events
/// - Stream updates to the reducer via `AsyncStream`
final class MarketsService {

    // MARK: - Dependencies

    /// Underlying WebSocket client responsible for network communication.
    private let socket = WebSocketClient()

    // MARK: - Streaming

    /// Starts streaming realtime market updates.
    ///
    /// Each emitted value represents either:
    /// - a raw websocket message (`.websocketMessage`)
    /// - or an error event (`.websocketFailed`)
    ///
    /// The stream begins when it is iterated by a consumer.
    ///
    /// - Returns: An `AsyncStream` of `MarketsAction` events.
    func startStreaming() -> AsyncStream<MarketsAction> {
        print("🚀 [MarketsService] startStreaming called")
        return AsyncStream { continuation in
            print("🔗 [MarketsService] Creating AsyncStream continuation")
            Task {
                print("📡 [MarketsService] Connecting WebSocket...")
                socket.connect()
                print("✅ [MarketsService] WebSocket connected")
                do {
                    for try await message in socket.stream() {
                        print("📩 [MarketsService] Received message:")
                        print(message)
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        continuation.yield(
                            .websocketMessage(message)
                        )
                    }
                    print("⚠️ [MarketsService] WebSocket stream ended normally")
                    continuation.finish()
                }
                catch {
                    print("❌ [MarketsService] WebSocket error occurred:")
                    print(error.localizedDescription)
                    continuation.yield(
                        .websocketFailed(error)
                    )
                    continuation.finish()
                }
                print("🧹 [MarketsService] Streaming task finished")
            }

            // Called when the stream is cancelled by the consumer
            continuation.onTermination = { [weak self] _ in
                print("🛑 [MarketsService] AsyncStream terminated by consumer")

                Task {
                    print("🔌 [MarketsService] Disconnecting WebSocket...")
                    await self?.socket.disconnect()
                    print("🔌 [MarketsService] WebSocket disconnected")
                }
            }
        }
    }
}
