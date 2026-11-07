import Foundation
import XCTest
@testable import RealTimePriceTracker

@MainActor
final class TopAssetsReducerTests: XCTestCase {
    func test_taskSynchronizesToPersistenceAndStartsOneRefreshLoop() async {
        let syncService = MockCoinGeckoSyncService()
        let syncedAt = Date(timeIntervalSince1970: 100)
        await syncService.setTopSyncDate(syncedAt)
        let reducer = TopAssetsReducer(syncService: syncService)
        var state = TopAssetsState()

        let effect = reducer.reduce(state: &state, action: .task)

        XCTAssertEqual(state.loadState, .loading)
        XCTAssertTrue(state.isRefreshLoopRunning)
        guard case let .merge(effects) = effect,
              effects.count == 2,
              case let .run(_, operation) = effects[0],
              case .response(.success(let date))? = await operation() else {
            return XCTFail("Expected persisted sync response and refresh loop")
        }

        _ = reducer.reduce(
            state: &state,
            action: .response(.success(date))
        )
        XCTAssertEqual(state.lastSuccessfulSync, syncedAt)
        XCTAssertEqual(state.loadState, .loaded)

        let duplicate = reducer.reduce(state: &state, action: .task)
        guard case .none = duplicate else {
            return XCTFail("Expected only one refresh loop")
        }
    }

    func test_refreshLoopUsesInjectedClock() async {
        let clock = ManualClock()
        let now = Date(timeIntervalSince1970: 100)
        let reducer = TopAssetsReducer(
            syncService: MockCoinGeckoSyncService(),
            clock: clock,
            refreshInterval: .seconds(600),
            now: { now }
        )
        var state = TopAssetsState(
            loadState: .loaded,
            lastSuccessfulSync: now
        )

        let effect = reducer.reduce(state: &state, action: .task)
        guard case let .stream(_, operation) = effect else {
            return XCTFail("Expected refresh stream")
        }

        let nextAction = Task {
            var iterator = operation().makeAsyncIterator()
            return await iterator.next()
        }
        await wait { clock.pendingSleepCount == 1 }
        clock.advance(by: .seconds(600))

        guard case .refreshTimerFired? = await nextAction.value else {
            return XCTFail("Expected refresh deadline")
        }
    }

    func test_refreshFailureKeepsPreviouslySynchronizedDataStale() {
        let reducer = TopAssetsReducer(
            syncService: MockCoinGeckoSyncService()
        )
        var state = TopAssetsState(
            loadState: .refreshing,
            lastSuccessfulSync: Date(timeIntervalSince1970: 10)
        )

        _ = reducer.reduce(
            state: &state,
            action: .response(.failure(.rateLimited))
        )

        XCTAssertEqual(state.loadState, .stale(.rateLimited))
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

private extension MockCoinGeckoSyncService {
    func setTopSyncDate(_ date: Date) {
        topSyncDate = date
    }
}
