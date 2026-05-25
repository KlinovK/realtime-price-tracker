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

        client.connect()

        let stream = client.stream()
        var iterator = stream.makeAsyncIterator()

        // simulate server messages
        mockTask.send(.string("A"))
        mockTask.send(.string("B"))

        let first = try await iterator.next()
        let second = try await iterator.next()

        XCTAssertEqual(first, "A")
        XCTAssertEqual(second, "B")
    }
}

final class MockWebSocketTask: WebSocketTasking {

    enum State {
        case resumed
        case cancelled
    }

    private(set) var state: State?
    
    private var receiveHandler: ((Result<URLSessionWebSocketTask.Message, Error>) -> Void)?

    func resume() {
        state = .resumed
    }

    func cancel() {
        state = .cancelled
    }

    func receive(completionHandler: @escaping (Result<URLSessionWebSocketTask.Message, Error>) -> Void) {
        receiveHandler = completionHandler
    }

    // MARK: - Test helpers

    func send(_ message: URLSessionWebSocketTask.Message) {
        receiveHandler?(.success(message))
    }

    func send(error: Error) {
        receiveHandler?(.failure(error))
    }
}
