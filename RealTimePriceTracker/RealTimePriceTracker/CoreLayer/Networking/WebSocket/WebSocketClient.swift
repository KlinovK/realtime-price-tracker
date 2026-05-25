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

protocol WebSocketTasking: AnyObject {
    func resume()
    func cancel()
    func receive(
        completionHandler: @Sendable @escaping (Result<URLSessionWebSocketTask.Message, Error>) -> Void
    )

}

extension URLSessionWebSocketTask: WebSocketTasking {}

protocol WebSocketClientProtocol: AnyObject {
    func connect()
    func disconnect()
    func stream() -> AsyncThrowingStream<String, Error>
    typealias WebSocketTaskFactory = (URLSession, URL) -> WebSocketTasking
}

final class WebSocketClient: WebSocketClientProtocol {

    private let url: URL
    private let session: URLSession
    private let taskFactory: WebSocketTaskFactory
    private var socketTask: WebSocketTasking?

    init(
        url: URL,
        session: URLSession = .shared,
        taskFactory: @escaping WebSocketTaskFactory = { session, url in
            session.webSocketTask(with: url)
        }
    ) {
        self.url = url
        self.session = session
        self.taskFactory = taskFactory
    }

    func connect() {
        socketTask = taskFactory(session, url)
        socketTask?.resume()
    }

    func disconnect() {
        socketTask?.cancel()
    }

    func stream() -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in

            func receiveNext() {
                socketTask?.receive { result in
                    switch result {
                    case .failure(let error):
                        continuation.finish(throwing: error)

                    case .success(let message):
                        if case .string(let text) = message {
                            continuation.yield(text)
                        }
                        receiveNext()
                    }
                }
            }

            receiveNext()
        }
    }
}
