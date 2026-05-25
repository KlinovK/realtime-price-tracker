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
///
///
protocol MarketsServiceProtocol {
    func startStreaming(
        with urls: [URL]
    ) -> AsyncStream<MarketsAction>
    func stopStreaming()
}

final class MarketsService: MarketsServiceProtocol {

    // MARK: - Properties

    private var sockets: [any WebSocketClientProtocol] = []

    private let socketFactory: (URL) -> any WebSocketClientProtocol

    // MARK: - Init

    init(
        socketFactory: @escaping (URL) -> any WebSocketClientProtocol
    ) {
        self.socketFactory = socketFactory
    }

    convenience init() {
        self.init(socketFactory: Self.makeDefaultSocket)
    }

    // MARK: - Default socket

    private static func makeDefaultSocket(
        url: URL
    ) -> any WebSocketClientProtocol {
        WebSocketClient(url: url)
    }

    // MARK: - Public API

    func stopStreaming() {

        sockets.forEach { $0.disconnect() }
        sockets.removeAll()
    }

    func startStreaming(
        with urls: [URL]
    ) -> AsyncStream<MarketsAction> {

        AsyncStream<MarketsAction> { continuation in

            let sockets = urls.map(socketFactory)

            Task { @MainActor in
                self.sockets = sockets
            }

            for socket in sockets {

                Task {

                    socket.connect()

                    do {
                        for try await message in socket.stream() {
                            continuation.yield(.websocketMessage(message))
                        }
                    } catch {
                        continuation.yield(.websocketFailed(error))
                    }
                }
            }

            continuation.onTermination = { [sockets] _ in
                Task { @MainActor in
                    sockets.forEach { $0.disconnect() }
                }
            }
        }
    }
}
