//
//  MarketsServiceTests.swift
//  RealTimePriceTrackerTests
//
//  Created by Kanstantsin Klinau on 25/05/26.
//

import XCTest
@testable import RealTimePriceTracker

final class MockWebSocketClient: WebSocketClientProtocol {

    var connectCallCount = 0
    var disconnectCallCount = 0

    var messages: [String] = []
    var error: Error?

    private var continuation: AsyncThrowingStream<String, Error>.Continuation?

    func connect() {
        connectCallCount += 1
    }

    func disconnect() {
        disconnectCallCount += 1
    }

    func stream() -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            self.continuation = continuation

            if let error {
                continuation.finish(throwing: error)
            } else {
                messages.forEach { continuation.yield($0) }
                continuation.finish()
            }
        }
    }

    // Helpers for tests
    func send(_ message: String) {
        continuation?.yield(message)
    }

    func finish() {
        continuation?.finish()
    }
}

@MainActor
final class MarketsServiceTests: XCTestCase {
    
    func test_startStreaming_createsSockets_andConnects() async {
        let mock1 = MockWebSocketClient()
        let mock2 = MockWebSocketClient()

        let urls = [
            URL(string: "wss://1")!,
            URL(string: "wss://2")!
        ]

        let service = MarketsService(socketFactory: { url in
            switch url {
            case urls[0]: return mock1
            case urls[1]: return mock2
            default: fatalError("unexpected url")
            }
        })

        let stream = service.startStreaming(with: urls)

        _ = stream.makeAsyncIterator()

        await Task.yield()

        XCTAssertEqual(mock1.connectCallCount, 1)
        XCTAssertEqual(mock2.connectCallCount, 1)
    }
}
