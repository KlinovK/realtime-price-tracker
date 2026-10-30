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
nonisolated enum MarketStreamFailure: Error, Equatable, Sendable {
    case timedOut
    case connectionLost
    case invalidSubscription
    case transport(String)
}

nonisolated enum MarketStreamEvent: Equatable, Sendable {
    case quotes([CryptoAsset])
    case failed(MarketStreamFailure)
}

/// Domain-oriented Binance transport. Endpoint construction and socket details
/// remain hidden from features and persistence.
nonisolated protocol MarketsServiceProtocol: Sendable {
    func startStreaming(
        symbols: [String]
    ) -> AsyncStream<MarketStreamEvent>
}

/// Actor that owns and merges all sockets for one logical market subscription.
///
/// Each call to ``startStreaming(symbols:)`` creates one child receiver per endpoint
/// and one batching/health child in a throwing task group. A failure in any child
/// cancels its siblings, then the service disconnects the entire socket set. The
/// stream termination handler also cancels this lifecycle when its consumer stops.
///
/// Raw messages never need to enter `MainActor`: ``LatestAssetBatcher`` decodes and
/// coalesces them, then only a bounded batch is yielded approximately every 150 ms.
actor MarketsService: MarketsServiceProtocol {

    nonisolated static let defaultBatchInterval: Duration = .milliseconds(150)
    nonisolated static let defaultConnectionTimeout: Duration = .seconds(5)

    // MARK: - Properties

    /// Removing a socket set is the atomic claim that makes cleanup
    /// idempotent when normal completion races cancellation.
    private var socketsByStream: [
        UUID: [any WebSocketClientProtocol]
    ] = [:]

    private let socketFactory: @Sendable (URL) -> any WebSocketClientProtocol
    private let clock: any Clock<Duration>
    private let elapsedTime: ElapsedTimeProvider
    private let batchInterval: Duration
    private let connectionTimeout: Duration

    // MARK: - Init

    init(
        socketFactory: @escaping @Sendable (URL) -> any WebSocketClientProtocol = {
            WebSocketClient(url: $0)
        },
        clock: any Clock<Duration> = ContinuousClock(),
        batchInterval: Duration = MarketsService.defaultBatchInterval,
        connectionTimeout: Duration = MarketsService.defaultConnectionTimeout
    ) {
        precondition(batchInterval > .zero)
        precondition(connectionTimeout > batchInterval)
        self.socketFactory = socketFactory
        self.clock = clock
        self.elapsedTime = ElapsedTimeProvider(clock: clock)
        self.batchInterval = batchInterval
        self.connectionTimeout = connectionTimeout
    }

    // MARK: - Public API

    /// Creates an independently cancellable stream for Binance pair identifiers.
    ///
    /// - Important: Terminating the returned stream cancels its lifecycle task;
    ///   actor-owned cleanup then closes every socket registered under that stream.
    nonisolated func startStreaming(
        symbols: [String]
    ) -> AsyncStream<MarketStreamEvent> {
        AsyncStream { continuation in
            let configuration = StreamConfiguration(
                symbols: symbols.map { $0.lowercased() },
                streamType: .ticker
            )
            let urls = EndpointFactory.makeURLs(configuration: configuration)
            guard !urls.isEmpty else {
                continuation.yield(.failed(.invalidSubscription))
                continuation.finish()
                return
            }

            let streamID = UUID()
            let lifecycleTask = Task { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }

                await self.runStream(
                    id: streamID,
                    urls: urls,
                    continuation: continuation
                )
            }

            continuation.onTermination = { _ in
                lifecycleTask.cancel()
            }
        }
    }

    private func runStream(
        id: UUID,
        urls: [URL],
        continuation: AsyncStream<MarketStreamEvent>.Continuation
    ) async {
        let sockets = urls.map(socketFactory)
        let batcher = LatestAssetBatcher(
            clock: clock,
            flushInterval: batchInterval
        )
        let healthTracker = ConnectionHealthTracker(
            connectionIDs: Array(sockets.indices),
            elapsedTime: elapsedTime,
            timeout: connectionTimeout
        )

        socketsByStream[id] = sockets

        await withTaskCancellationHandler {
            do {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    for (connectionID, socket) in sockets.enumerated() {
                        group.addTask {
                            await socket.connect()
                            let stream = await socket.stream()
                            try await batcher.consume(stream) {
                                await healthTracker.recordActivity(
                                    for: connectionID
                                )
                            }

                            throw MarketsServiceError.connectionClosed
                        }
                    }

                    group.addTask {
                        while !Task.isCancelled {
                            let assets = try await batcher.nextBatch()
                            let timedOutConnectionIDs = await healthTracker
                                .timedOutConnectionIDs()

                            if !timedOutConnectionIDs.isEmpty {
                                throw MarketsServiceError.connectionTimedOut
                            }

                            guard !assets.isEmpty else { continue }
                            continuation.yield(.quotes(assets))
                        }
                    }

                    do {
                        _ = try await group.next()
                        group.cancelAll()
                        throw MarketsServiceError.connectionClosed
                    } catch {
                        group.cancelAll()
                        throw error
                    }
                }
            } catch is CancellationError {
                // Cancellation is a normal stream lifecycle event.
            } catch MarketsServiceError.connectionTimedOut {
                continuation.yield(.failed(.timedOut))
            } catch MarketsServiceError.connectionClosed {
                continuation.yield(.failed(.connectionLost))
            } catch {
                continuation.yield(.failed(.transport(error.localizedDescription)))
            }

            await disconnect(streamID: id)
        } onCancel: {
            Task { [weak self] in
                await self?.disconnect(streamID: id)
            }
        }

        continuation.finish()
    }

    private func disconnect(streamID: UUID) async {
        guard let sockets = socketsByStream.removeValue(forKey: streamID) else {
            return
        }

        await withTaskGroup(of: Void.self) { group in
            for socket in sockets {
                group.addTask {
                    await socket.disconnect()
                }
            }
        }
    }

}

nonisolated enum MarketsServiceError: Error {
    case connectionTimedOut
    case connectionClosed
}

/// Type-erases a clock's instant while preserving monotonic elapsed time.
/// This lets transport health remain deterministic with any injected clock.
nonisolated struct ElapsedTimeProvider: Sendable {
    private let elapsed: @Sendable () -> Duration

    init<C: Clock>(clock: C) where C.Duration == Duration {
        let origin = clock.now
        elapsed = {
            origin.duration(to: clock.now)
        }
    }

    var now: Duration {
        elapsed()
    }
}

/// Tracks successful decoded activity for every socket independently.
///
/// A busy connection cannot hide a silent sibling because each connection ID owns
/// a separate monotonic timestamp.
actor ConnectionHealthTracker {
    private var lastActivityByConnection: [Int: Duration]
    private let elapsedTime: ElapsedTimeProvider
    private let timeout: Duration

    init(
        connectionIDs: [Int],
        elapsedTime: ElapsedTimeProvider,
        timeout: Duration
    ) {
        let now = elapsedTime.now
        lastActivityByConnection = Dictionary(
            uniqueKeysWithValues: connectionIDs.map { ($0, now) }
        )
        self.elapsedTime = elapsedTime
        self.timeout = timeout
    }

    func recordActivity(for connectionID: Int) {
        guard lastActivityByConnection[connectionID] != nil else { return }
        lastActivityByConnection[connectionID] = elapsedTime.now
    }

    func timedOutConnectionIDs() -> [Int] {
        let now = elapsedTime.now

        return lastActivityByConnection.compactMap { connectionID, lastActivity in
            now - lastActivity >= timeout ? connectionID : nil
        }
        .sorted()
    }
}

/// Decodes every WebSocket frame and coalesces pending updates by symbol.
///
/// Between flushes, a newer value replaces only the older pending value for the
/// same symbol. This preserves fairness while bounding reducer and SwiftUI work.
/// The injected clock makes the timing deterministic in tests.
actor LatestAssetBatcher {

    private var assetsBySymbol: [String: CryptoAsset] = [:]
    private let clock: any Clock<Duration>
    private let flushInterval: Duration

    init(
        clock: any Clock<Duration>,
        flushInterval: Duration
    ) {
        self.clock = clock
        self.flushInterval = flushInterval
    }

    /// Owns the receive loop so raw frames do not pass through MainActor.
    func consume(
        _ stream: AsyncThrowingStream<String, Error>,
        onDecodedEvent: @escaping @Sendable () async -> Void = {}
    ) async throws {
        for try await message in stream {
            if ingest(message) {
                await onDecodedEvent()
            }
        }
    }

    /// Decodes every message away from the main actor and overwrites only the
    /// previous pending value for the same symbol.
    ///
    /// - Note: Malformed or non-ticker frames are ignored and do not count as
    ///   healthy activity. Persistent schema drift therefore becomes a timeout
    ///   instead of incorrectly presenting frozen values as live.
    @discardableResult
    func ingest(_ message: String) -> Bool {
        guard
            let data = message.data(using: .utf8),
            let response = try? JSONDecoder().decode(
                BinanceSocketResponse.self,
                from: data
            ),
            let price = Decimal(
                string: response.data.price,
                locale: Locale(identifier: "en_US_POSIX")
            ),
            let change24h = Decimal(
                string: response.data.changePercent,
                locale: Locale(identifier: "en_US_POSIX")
            )
        else {
            return false
        }

        let asset = CryptoAsset(
            id: response.data.symbol,
            symbol: response.data.symbol,
            price: price,
            change24h: change24h
        )

        assetsBySymbol[asset.id] = asset
        return true
    }

    /// Sleeps on the injected clock, then atomically returns one latest value
    /// per symbol and clears the pending batch.
    func nextBatch() async throws -> [CryptoAsset] {
        try await clock.sleep(for: flushInterval)

        let assets = assetsBySymbol.values.sorted { $0.id < $1.id }
        assetsBySymbol.removeAll(keepingCapacity: true)
        return assets
    }
}
