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
///
/// - Important: The actor owns exactly one active `URLSessionWebSocketTask`.
///   Connecting again cancels and replaces that task, and terminating the message
///   stream cancels its receive loop and disconnects the socket.
/// - Note: Throttling does not belong here. The client forwards every text frame;
///   downstream actor-owned batching decides how often state reaches the UI.

nonisolated protocol WebSocketTasking: AnyObject, Sendable {
    func resume() async
    func cancel() async
    func receive() async throws -> URLSessionWebSocketTask.Message
}

extension URLSessionWebSocketTask: WebSocketTasking {}

nonisolated protocol WebSocketClientProtocol: Actor {
    func connect() async
    func disconnect() async
    func stream() async -> AsyncThrowingStream<String, Error>
}

typealias WebSocketTaskFactory = @Sendable (
    URLSession,
    URL
) -> any WebSocketTasking

nonisolated enum WebSocketClientError: Error {
    case notConnected
}

/// Actor-isolated owner of one URL session WebSocket task and its receive loop.
actor WebSocketClient: WebSocketClientProtocol {

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

    func connect() async {
        if let socketTask {
            await socketTask.cancel()
        }

        let task = taskFactory(session, url)
        socketTask = task
        await task.resume()
    }

    func disconnect() async {
        guard let task = socketTask else { return }
        socketTask = nil
        await task.cancel()
    }

    func stream() async -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let receiveTask = Task { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }

                do {
                    try await withTaskCancellationHandler {
                        while !Task.isCancelled {
                            let message = try await self.receive()

                            guard !Task.isCancelled else { break }
                            if case .string(let text) = message {
                                continuation.yield(text)
                            }
                        }

                        continuation.finish()
                    } onCancel: {
                        Task { [weak self] in
                            await self?.disconnect()
                        }
                    }
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                receiveTask.cancel()
            }
        }
    }

    private func receive() async throws -> URLSessionWebSocketTask.Message {
        guard let socketTask else {
            throw WebSocketClientError.notConnected
        }

        return try await socketTask.receive()
    }
}
