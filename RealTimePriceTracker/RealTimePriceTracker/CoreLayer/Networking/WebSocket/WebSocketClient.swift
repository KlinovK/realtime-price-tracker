//
//  WebSocketClient.swift
//  RealTimePriceTracker
//
//  Created by Константин Клинов on 19/05/26.
//

import Foundation

/// A lightweight WebSocket client built on top of `URLSessionWebSocketTask`.
///
/// This client is responsible for:
/// - Establishing a WebSocket connection to a given endpoint
/// - Receiving realtime streaming messages
/// - Exposing messages as an `AsyncThrowingStream`
///
/// It is intentionally minimal and stateless aside from the active socket task.
/// It is designed to be used inside service layers (e.g. `MarketsService`).
final class WebSocketClient {

    // MARK: - Properties

    /// The underlying WebSocket task used for network communication.
    ///
    /// This task is created when `connect()` is called and is reused for
    /// receiving streaming messages until `disconnect()` is invoked.
    private var socketTask: URLSessionWebSocketTask?

    // MARK: - Connection Lifecycle

    /// Establishes a WebSocket connection to the configured endpoint.
    ///
    /// This method:
    /// 1. Creates a `URLSessionWebSocketTask` using `Endpoint.streamURL`
    /// 2. Starts the connection immediately using `resume()`
    ///
    /// ⚠️ Note:
    /// Calling `connect()` multiple times will overwrite the previous socket task
    /// without explicitly closing it. Ensure `disconnect()` is called beforehand.
    func connect() {
        socketTask = URLSession.shared.webSocketTask(
            with: Endpoint.streamURL
        )

        socketTask?.resume()
    }

    /// Terminates the active WebSocket connection.
    ///
    /// This cancels the underlying `URLSessionWebSocketTask` immediately.
    /// After calling this method, the client will no longer receive messages
    /// unless `connect()` is called again.
    func disconnect() {
        socketTask?.cancel()
    }

    // MARK: - Streaming

    /// Creates an asynchronous stream of incoming WebSocket messages.
    ///
    /// The stream:
    /// - Listens continuously for incoming WebSocket messages
    /// - Emits only string-based messages (`.string`)
    /// - Ignores non-text frames (e.g. binary, ping/pong)
    /// - Propagates errors via `AsyncThrowingStream`
    ///
    /// The stream will continue indefinitely until:
    /// - The WebSocket connection fails
    /// - `disconnect()` is called
    /// - The consumer stops iterating
    ///
    /// - Returns: An `AsyncThrowingStream<String, Error>` emitting raw text messages.
    func stream() -> AsyncThrowingStream<String, Error> {

        AsyncThrowingStream { continuation in

            /// Internal recursive receive loop.
            /// Continuously calls `socketTask?.receive` to listen for new messages.
            func receive() {

                socketTask?.receive { result in
                    print("📡 SOCKET CALLBACK FIRED") // 🔥 ADD THIS
                    switch result {

                    case .failure(let error):
                        /// If the WebSocket fails, terminate the stream with error.
                        continuation.finish(throwing: error)

                    case .success(let message):

                        switch message {

                        case .string(let text):
                            /// Emit valid text message to the stream consumer.
                            continuation.yield(text)

                        default:
                            /// Ignore unsupported message types (binary, pong, etc.)
                            break
                        }

                        /// Continue listening for the next message.
                        receive()
                    }
                }
            }

            /// Start the receive loop immediately when stream is created.
            receive()
        }
    }
}
