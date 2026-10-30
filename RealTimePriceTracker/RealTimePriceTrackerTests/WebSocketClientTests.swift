//
//  WebSocketClientTests.swift
//  RealTimePriceTrackerTests
//
//  Created by Kanstantsin Klinau on 25/05/26.
//

import Foundation
import XCTest
@testable import RealTimePriceTracker

@MainActor
final class WebSocketClientTests: XCTestCase {

    func test_stream_yields_string_messages() async throws {

        let mockTask = MockWebSocketTask()

        let client = WebSocketClient(
            url: URL(string: "wss://test")!,
            taskFactory: { _, _ in mockTask }
        )

        await client.connect()

        let stream = await client.stream()
        var iterator = stream.makeAsyncIterator()

        // simulate server messages
        await mockTask.send(.string("A"))
        await mockTask.send(.string("B"))

        let first = try await iterator.next()
        let second = try await iterator.next()

        XCTAssertEqual(first, "A")
        XCTAssertEqual(second, "B")
    }

    func test_stream_yields_every_message_in_a_burst() async throws {
        let mockTask = MockWebSocketTask()
        let client = WebSocketClient(
            url: URL(string: "wss://test")!,
            taskFactory: { _, _ in mockTask }
        )

        await client.connect()

        let stream = await client.stream()
        var iterator = stream.makeAsyncIterator()
        let expectedMessages = (0..<250).map { "message-\($0)" }

        for message in expectedMessages {
            await mockTask.send(.string(message))
        }

        var receivedMessages: [String] = []
        for _ in expectedMessages.indices {
            let message = try await iterator.next()
            receivedMessages.append(try XCTUnwrap(message))
        }

        XCTAssertEqual(receivedMessages, expectedMessages)
    }

    func test_cancellingConsumer_disconnectsSocketTask() async {
        let mockTask = MockWebSocketTask()
        let client = WebSocketClient(
            url: URL(string: "wss://test")!,
            taskFactory: { _, _ in mockTask }
        )

        await client.connect()
        let stream = await client.stream()
        let consumer = Task {
            do {
                for try await _ in stream {}
            } catch {
                // Cancellation is the expected termination path.
            }
        }

        await Task.yield()
        consumer.cancel()
        await consumer.value

        for _ in 0..<100 {
            if await mockTask.state == .cancelled { break }
            await Task.yield()
        }

        let finalState = await mockTask.state
        XCTAssertEqual(finalState, .cancelled)
    }
}

actor MockWebSocketTask: WebSocketTasking {

    nonisolated enum State: Equatable, Sendable {
        case resumed
        case cancelled
    }

    private(set) var state: State?
    private var queuedResults: [Result<URLSessionWebSocketTask.Message, Error>] = []
    private var receiveContinuation: CheckedContinuation<
        URLSessionWebSocketTask.Message,
        Error
    >?

    func resume() {
        state = .resumed
    }

    func cancel() {
        state = .cancelled
        receiveContinuation?.resume(throwing: CancellationError())
        receiveContinuation = nil
    }

    func receive() async throws -> URLSessionWebSocketTask.Message {
        if !queuedResults.isEmpty {
            return try queuedResults.removeFirst().get()
        }

        return try await withCheckedThrowingContinuation { continuation in
            receiveContinuation = continuation
        }
    }

    // MARK: - Test helpers

    func send(_ message: URLSessionWebSocketTask.Message) {
        if let continuation = receiveContinuation {
            receiveContinuation = nil
            continuation.resume(returning: message)
        } else {
            queuedResults.append(.success(message))
        }
    }

    func send(error: Error) {
        if let continuation = receiveContinuation {
            receiveContinuation = nil
            continuation.resume(throwing: error)
        } else {
            queuedResults.append(.failure(error))
        }
    }
}
