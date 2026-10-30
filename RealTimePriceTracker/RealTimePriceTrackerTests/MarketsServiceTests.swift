//
//  MarketsServiceTests.swift
//  RealTimePriceTrackerTests
//
//  Created by Kanstantsin Klinau on 25/05/26.
//

import XCTest
@testable import RealTimePriceTracker

actor MockWebSocketClient: WebSocketClientProtocol {

    var connectCallCount = 0
    var disconnectCallCount = 0

    var messages: [String] = []
    var error: Error?

    private var continuation: AsyncThrowingStream<String, Error>.Continuation?

    func connect() async {
        connectCallCount += 1
    }

    func disconnect() async {
        disconnectCallCount += 1
        continuation?.finish()
        continuation = nil
    }

    func stream() async -> AsyncThrowingStream<String, Error> {
        let pair = AsyncThrowingStream<String, Error>.makeStream()
        continuation = pair.continuation

        if let error {
            pair.continuation.finish(throwing: error)
        } else {
            messages.forEach { pair.continuation.yield($0) }
        }

        return pair.stream
    }

    // Helpers for tests
    func send(_ message: String) {
        continuation?.yield(message)
    }

    func finish() {
        continuation?.finish()
    }
}

private actor DecodedEventCounter {
    private(set) var value = 0

    func increment() {
        value += 1
    }
}

@MainActor
final class MarketsServiceTests: XCTestCase {
    
    func test_startStreaming_createsSockets_andConnects() async {
        let mock1 = MockWebSocketClient()
        let mock2 = MockWebSocketClient()

        let symbols = (0..<26).map { "SYM\($0)USDT" }

        let service = MarketsService(socketFactory: { url in
            url.absoluteString.contains("sym25usdt") ? mock2 : mock1
        })

        let stream = service.startStreaming(symbols: symbols)
        let consumer = Task {
            for await _ in stream {}
        }

        await wait {
            let firstCount = await mock1.connectCallCount
            let secondCount = await mock2.connectCallCount
            return firstCount == 1 && secondCount == 1
        }

        let firstConnectCount = await mock1.connectCallCount
        let secondConnectCount = await mock2.connectCallCount
        XCTAssertEqual(firstConnectCount, 1)
        XCTAssertEqual(secondConnectCount, 1)
        consumer.cancel()
        await consumer.value
    }

    func test_batcher_emitsLatestAssetPerSymbolAfterClockAdvances() async throws {
        let clock = ManualClock()
        let batcher = LatestAssetBatcher(
            clock: clock,
            flushInterval: MarketsService.defaultBatchInterval
        )

        await batcher.ingest(tickerMessage(symbol: "BTCUSDT", price: "100", change: "1"))
        await batcher.ingest(tickerMessage(symbol: "ETHUSDT", price: "20", change: "2"))
        await batcher.ingest(tickerMessage(symbol: "BTCUSDT", price: "101", change: "1.5"))

        let batchTask = Task {
            try await batcher.nextBatch()
        }

        await wait { clock.pendingSleepCount == 1 }

        clock.advance(by: .milliseconds(149))
        XCTAssertEqual(clock.pendingSleepCount, 1)

        clock.advance(by: .milliseconds(1))

        let assets = try await batchTask.value

        let assetsByID = Dictionary(uniqueKeysWithValues: assets.map { ($0.id, $0) })
        XCTAssertEqual(assets.count, 2)
        XCTAssertEqual(assetsByID["BTCUSDT"]?.price, 101)
        XCTAssertEqual(assetsByID["BTCUSDT"]?.change24h, 1.5)
        XCTAssertEqual(assetsByID["ETHUSDT"]?.price, 20)
    }

    func test_batcher_preservesDecimalFinancialPrecision() async throws {
        let clock = ManualClock()
        let batcher = LatestAssetBatcher(
            clock: clock,
            flushInterval: MarketsService.defaultBatchInterval
        )

        await batcher.ingest(
            tickerMessage(
                symbol: "SHIBUSDT",
                price: "0.00001234",
                change: "-2.345678"
            )
        )

        let batchTask = Task {
            try await batcher.nextBatch()
        }
        await wait { clock.pendingSleepCount == 1 }
        clock.advance(by: MarketsService.defaultBatchInterval)

        let assets = try await batchTask.value
        let asset = try XCTUnwrap(assets.first)
        XCTAssertEqual(
            asset.price,
            Decimal(
                string: "0.00001234",
                locale: Locale(identifier: "en_US_POSIX")
            )
        )
        XCTAssertEqual(
            asset.change24h,
            Decimal(
                string: "-2.345678",
                locale: Locale(identifier: "en_US_POSIX")
            )
        )
    }

    func test_batcher_recordsHealthOnlyForDecodedEvents() async throws {
        let clock = ManualClock()
        let batcher = LatestAssetBatcher(
            clock: clock,
            flushInterval: MarketsService.defaultBatchInterval
        )
        let counter = DecodedEventCounter()
        let stream = AsyncThrowingStream<String, Error> { continuation in
            continuation.yield("not-json")
            continuation.yield(
                tickerMessage(
                    symbol: "BTCUSDT",
                    price: "100",
                    change: "1"
                )
            )
            continuation.finish()
        }

        try await batcher.consume(stream) {
            await counter.increment()
        }

        let decodedEventCount = await counter.value
        XCTAssertEqual(decodedEventCount, 1)
    }

    func test_cancellingConsumer_disconnectsEverySocket() async {
        let mock1 = MockWebSocketClient()
        let mock2 = MockWebSocketClient()
        let service = MarketsService(
            socketFactory: { url in
                url.absoluteString.contains("sym25usdt") ? mock2 : mock1
            }
        )
        let symbols = (0..<26).map { "SYM\($0)USDT" }

        let consumer = Task {
            for await _ in service.startStreaming(symbols: symbols) {}
        }

        await wait {
            let firstCount = await mock1.connectCallCount
            let secondCount = await mock2.connectCallCount
            return firstCount == 1 && secondCount == 1
        }

        consumer.cancel()
        await consumer.value

        await wait {
            let firstCount = await mock1.disconnectCallCount
            let secondCount = await mock2.disconnectCallCount
            return firstCount == 1 && secondCount == 1
        }

        let firstDisconnectCount = await mock1.disconnectCallCount
        let secondDisconnectCount = await mock2.disconnectCallCount
        XCTAssertEqual(firstDisconnectCount, 1)
        XCTAssertEqual(secondDisconnectCount, 1)
    }

    func test_healthTracker_timesOutOnlySilentConnection() async {
        let clock = ManualClock()
        let tracker = ConnectionHealthTracker(
            connectionIDs: [0, 1],
            elapsedTime: ElapsedTimeProvider(clock: clock),
            timeout: .seconds(5)
        )

        clock.advance(by: .seconds(4))
        await tracker.recordActivity(for: 0)
        clock.advance(by: .seconds(1))

        let timedOutConnectionIDs = await tracker.timedOutConnectionIDs()
        XCTAssertEqual(timedOutConnectionIDs, [1])
    }

    func test_silentConnection_failsMergedStreamAndDisconnectsAllSockets() async {
        let clock = ManualClock()
        let mock1 = MockWebSocketClient()
        let mock2 = MockWebSocketClient()
        let symbols = (0..<26).map { "SYM\($0)USDT" }
        let service = MarketsService(
            socketFactory: { url in
                url.absoluteString.contains("sym25usdt") ? mock2 : mock1
            },
            clock: clock,
            batchInterval: .milliseconds(150),
            connectionTimeout: .seconds(5)
        )
        let failureTask = Task<MarketStreamFailure?, Never> {
            for await event in service.startStreaming(symbols: symbols) {
                if case .failed(let failure) = event {
                    return failure
                }
            }

            return nil
        }

        await wait {
            let firstCount = await mock1.connectCallCount
            let secondCount = await mock2.connectCallCount
            return firstCount == 1 &&
                secondCount == 1 &&
                clock.pendingSleepCount == 1
        }

        guard clock.pendingSleepCount == 1 else {
            failureTask.cancel()
            return XCTFail("Expected the health-check clock sleep")
        }

        clock.advance(by: .seconds(5))

        let failure = await failureTask.value
        XCTAssertEqual(failure, .timedOut)

        await wait {
            let firstCount = await mock1.disconnectCallCount
            let secondCount = await mock2.disconnectCallCount
            return firstCount == 1 && secondCount == 1
        }

        let firstDisconnectCount = await mock1.disconnectCallCount
        let secondDisconnectCount = await mock2.disconnectCallCount
        XCTAssertEqual(firstDisconnectCount, 1)
        XCTAssertEqual(secondDisconnectCount, 1)
    }

    private func wait(
        until condition: () async -> Bool,
        attempts: Int = 100
    ) async {
        for _ in 0..<attempts {
            if await condition() { return }
            await Task.yield()
        }
    }

    private func tickerMessage(
        symbol: String,
        price: String,
        change: String
    ) -> String {
        """
        {
          "stream": "\(symbol.lowercased())@ticker",
          "data": {
            "s": "\(symbol)",
            "c": "\(price)",
            "P": "\(change)"
          }
        }
        """
    }
}

nonisolated struct ManualInstant: InstantProtocol, Sendable {
    typealias Duration = Swift.Duration

    let offset: Duration

    func advanced(by duration: Duration) -> Self {
        Self(offset: offset + duration)
    }

    func duration(to other: Self) -> Duration {
        other.offset - offset
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.offset < rhs.offset
    }
}

nonisolated final class ManualClock: Clock, @unchecked Sendable {
    typealias Instant = ManualInstant
    typealias Duration = Swift.Duration

    private struct Sleeper {
        let deadline: Instant
        let continuation: CheckedContinuation<Void, Error>
    }

    private let lock = NSLock()
    private var currentInstant = Instant(offset: .zero)
    private var sleepers: [UUID: Sleeper] = [:]
    private var cancelledSleepIDs: Set<UUID> = []

    var now: Instant {
        lock.withLock { currentInstant }
    }

    var minimumResolution: Duration {
        .nanoseconds(1)
    }

    var pendingSleepCount: Int {
        lock.withLock { sleepers.count }
    }

    func sleep(
        until deadline: Instant,
        tolerance: Duration?
    ) async throws {
        try Task.checkCancellation()
        let id = UUID()

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                register(
                    id: id,
                    deadline: deadline,
                    continuation: continuation
                )
            }
        } onCancel: {
            cancelSleep(id: id)
        }
    }

    func advance(by duration: Duration) {
        let readyContinuations: [CheckedContinuation<Void, Error>] = lock.withLock {
            currentInstant = currentInstant.advanced(by: duration)

            let readyIDs = sleepers.compactMap { id, sleeper in
                sleeper.deadline <= currentInstant ? id : nil
            }

            return readyIDs.compactMap { id in
                sleepers.removeValue(forKey: id)?.continuation
            }
        }

        readyContinuations.forEach { $0.resume() }
    }

    private func register(
        id: UUID,
        deadline: Instant,
        continuation: CheckedContinuation<Void, Error>
    ) {
        let immediateResult: Result<Void, Error>? = lock.withLock {
            if cancelledSleepIDs.remove(id) != nil {
                return .failure(CancellationError())
            }

            if deadline <= currentInstant {
                return .success(())
            }

            sleepers[id] = Sleeper(
                deadline: deadline,
                continuation: continuation
            )
            return nil
        }

        if let immediateResult {
            continuation.resume(with: immediateResult)
        }
    }

    private func cancelSleep(id: UUID) {
        let continuation: CheckedContinuation<Void, Error>? = lock.withLock {
            guard let sleeper = sleepers.removeValue(forKey: id) else {
                cancelledSleepIDs.insert(id)
                return nil
            }

            return sleeper.continuation
        }

        continuation?.resume(throwing: CancellationError())
    }
}
