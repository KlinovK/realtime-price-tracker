//
//  MarketsService.swift
//  RealTimePriceTracker
//
//  Created by Константин Клинов on 19/05/26.
//

import Foundation

final class MarketsService {

    private let socket = WebSocketClient()

    func startStreaming() -> AsyncStream<MarketsAction> {
        AsyncStream { continuation in
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
    }
}
