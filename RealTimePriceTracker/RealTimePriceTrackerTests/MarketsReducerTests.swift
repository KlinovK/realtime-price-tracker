import Foundation
import XCTest
@testable import RealTimePriceTracker

@MainActor
final class MarketsReducerTests: XCTestCase {
    private let bitcoin = FavoriteAssetSubscription(
        coinGeckoID: "bitcoin",
        binancePairID: "BTCUSDT"
    )

    func test_subscriptionStartsPersistenceBackedStreamAndWatchdog() async {
        let syncService = MockLivePricesSyncService()
        let reducer = MarketsReducer(syncService: syncService)
        var state = MarketsState()

        let effect = reducer.reduce(
            state: &state,
            action: .subscriptionsChanged([bitcoin])
        )

        XCTAssertEqual(state.subscriptions, [bitcoin])
        XCTAssertEqual(state.connection, .connecting)
        guard case let .merge(effects) = effect,
              effects.count == 2,
              case .cancel = effects[0],
              case let .merge(liveEffects) = effects[1],
              liveEffects.count == 2,
              case let .stream(_, operation) = liveEffects[0],
              case .run = liveEffects[1] else {
            return XCTFail("Expected stream replacement and watchdog")
        }

        _ = operation()
        await wait { !syncService.subscriptions.isEmpty }
        XCTAssertEqual(syncService.subscriptions, [[bitcoin]])
    }

    func test_committedBatchMarksConnectionLiveWithoutCopyingAssetData() {
        let reducer = MarketsReducer(syncService: MockLivePricesSyncService())
        let eventDate = Date(timeIntervalSince1970: 200)
        var state = MarketsState(
            connection: .connecting,
            subscriptions: [bitcoin]
        )

        let effect = reducer.reduce(
            state: &state,
            action: .syncEvent(.batchCommitted(lastEventAt: eventDate))
        )

        XCTAssertEqual(state.connection, .live)
        XCTAssertEqual(state.lastEventAt, eventDate)
        XCTAssertFalse(state.reconnectAttemptIsActive)
        guard case .run = effect else {
            return XCTFail("Expected freshness watchdog")
        }
    }

    func test_persistenceFailureStopsStreamAndKeepsPersistedSnapshotStale() {
        let reducer = MarketsReducer(syncService: MockLivePricesSyncService())
        var state = MarketsState(
            connection: .live,
            subscriptions: [bitcoin]
        )

        let effect = reducer.reduce(
            state: &state,
            action: .syncEvent(.persistenceFailed)
        )

        XCTAssertEqual(state.connection, .stale(.persistenceFailed))
        assertCancelsAll(effect)
    }

    func test_streamFailureSchedulesCappedReconnect() {
        let reducer = MarketsReducer(syncService: MockLivePricesSyncService())
        var state = MarketsState(
            connection: .live,
            subscriptions: [bitcoin]
        )

        let effect = reducer.reduce(
            state: &state,
            action: .syncEvent(.failed(.connectionLost))
        )

        XCTAssertEqual(
            state.connection,
            .reconnecting(attempt: 1, failure: .connectionLost)
        )
        XCTAssertFalse(state.reconnectAttemptIsActive)
        guard case let .merge(effects) = effect,
              effects.count == 3,
              case .run = effects[2] else {
            return XCTFail("Expected reconnect delay")
        }
    }

    func test_reconnectDelayUsesInjectedClockThenRestartsSync() async {
        let clock = ManualClock()
        let syncService = MockLivePricesSyncService()
        let reducer = MarketsReducer(
            syncService: syncService,
            clock: clock,
            reconnectPolicy: MarketsReconnectPolicy(
                maxAttempts: 2,
                initialDelay: .seconds(1),
                maximumDelay: .seconds(2)
            )
        )
        var state = MarketsState(
            connection: .live,
            subscriptions: [bitcoin]
        )

        let scheduled = reducer.reduce(
            state: &state,
            action: .websocketFailed(.connectionLost)
        )
        guard case let .merge(effects) = scheduled,
              case let .run(_, delayOperation) = effects[2] else {
            return XCTFail("Expected delay effect")
        }

        let delayTask = Task { await delayOperation() }
        await wait { clock.pendingSleepCount == 1 }
        clock.advance(by: .seconds(1))
        guard case .reconnectDelayElapsed(attempt: 1)? = await delayTask.value else {
            return XCTFail("Expected reconnect action")
        }

        let restarted = reducer.reduce(
            state: &state,
            action: .reconnectDelayElapsed(attempt: 1)
        )
        XCTAssertTrue(state.reconnectAttemptIsActive)
        guard case let .merge(liveEffects) = restarted,
              case let .stream(_, operation) = liveEffects[0] else {
            return XCTFail("Expected restarted live sync")
        }
        _ = operation()
        await wait { !syncService.subscriptions.isEmpty }
        XCTAssertEqual(syncService.subscriptions, [[bitcoin]])
    }

    func test_retryBudgetExhaustionLeavesDatabaseSnapshotVisibleAsStale() {
        let reducer = MarketsReducer(
            syncService: MockLivePricesSyncService(),
            reconnectPolicy: MarketsReconnectPolicy(
                maxAttempts: 1,
                initialDelay: .milliseconds(1),
                maximumDelay: .milliseconds(1)
            )
        )
        var state = MarketsState(
            connection: .reconnecting(
                attempt: 1,
                failure: .connectionLost
            ),
            reconnectAttemptIsActive: true,
            subscriptions: [bitcoin]
        )

        let effect = reducer.reduce(
            state: &state,
            action: .websocketFailed(.offline)
        )

        XCTAssertEqual(state.connection, .stale(.offline))
        assertCancelsAll(effect)
    }

    func test_emptySubscriptionAndDisappearCancelAllWork() {
        let reducer = MarketsReducer(syncService: MockLivePricesSyncService())
        var state = MarketsState(
            connection: .live,
            subscriptions: [bitcoin]
        )

        let emptyEffect = reducer.reduce(
            state: &state,
            action: .subscriptionsChanged([])
        )
        XCTAssertEqual(state.connection, .idle)
        XCTAssertTrue(state.subscriptions.isEmpty)
        assertCancelsAll(emptyEffect)

        let disappearEffect = reducer.reduce(
            state: &state,
            action: .onDisappear
        )
        assertCancelsAll(disappearEffect)
    }

    func test_reconnectPolicyUsesCappedExponentialBackoff() {
        let policy = MarketsReconnectPolicy(
            maxAttempts: 6,
            initialDelay: .milliseconds(500),
            maximumDelay: .seconds(8)
        )

        XCTAssertEqual(
            (1...6).map(policy.delay(forAttempt:)),
            [
                .milliseconds(500), .seconds(1), .seconds(2),
                .seconds(4), .seconds(8), .seconds(8)
            ]
        )
    }

    private func assertCancelsAll(
        _ effect: Effect<MarketsAction>,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case let .merge(effects) = effect,
              effects.count == 3,
              effects.allSatisfy({
                  if case .cancel = $0 { return true }
                  return false
              }) else {
            return XCTFail("Expected all live effects to be cancelled", file: file, line: line)
        }
    }

    private func wait(
        until condition: () -> Bool,
        attempts: Int = 100
    ) async {
        for _ in 0..<attempts {
            if condition() { return }
            await Task.yield()
        }
    }
}
