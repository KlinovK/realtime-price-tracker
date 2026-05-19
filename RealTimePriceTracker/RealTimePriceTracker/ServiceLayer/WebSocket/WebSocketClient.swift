//
//  WebSocketClient.swift
//  RealTimePriceTracker
//
//  Created by Константин Клинов on 19/05/26.
//

import Foundation

final class WebSocketClient {

    private var socketTask: URLSessionWebSocketTask?

    func connect() {

        socketTask = URLSession.shared.webSocketTask(
            with: Endpoint.streamURL
        )

        socketTask?.resume()
    }

    func disconnect() {
        socketTask?.cancel()
    }

    func stream() -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            func receive() {
                socketTask?.receive { result in
                    switch result {
                    case .failure(let error):
                        continuation.finish(throwing: error)
                    case .success(let message):
                        switch message {
                        case .string(let text):
                            continuation.yield(text)
                        default:
                            break
                        }
                        receive()
                    }
                }
            }
            receive()
        }
    }
}
