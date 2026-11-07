//
//  TopAssetsReducer.swift
//  RealTimePriceTracker
//

import Foundation

/// Orchestrates CoinGecko-to-SwiftData synchronization.
///
/// The reducer starts one identified request and one identified ten-minute refresh
/// loop. Both time and HTTP are injected, so tests never wait for wall-clock time.
@MainActor
struct TopAssetsReducer: ReducerProtocol {
    nonisolated static let defaultRefreshInterval: Duration = .seconds(600)

    private enum CancelID {
        static let request = EffectCancellationID("top-assets.request")
        static let refreshLoop = EffectCancellationID("top-assets.refresh-loop")
    }

    private let syncService: any CoinGeckoSyncServiceProtocol
    private let clock: any Clock<Duration>
    private let refreshInterval: Duration
    private let now: () -> Date

    init(
        syncService: any CoinGeckoSyncServiceProtocol,
        clock: any Clock<Duration> = ContinuousClock(),
        refreshInterval: Duration = Self.defaultRefreshInterval,
        now: @escaping () -> Date = Date.init
    ) {
        precondition(refreshInterval > .zero)
        self.syncService = syncService
        self.clock = clock
        self.refreshInterval = refreshInterval
        self.now = now
    }

    func reduce(
        state: inout TopAssetsState,
        action: TopAssetsAction
    ) -> Effect<TopAssetsAction> {
        switch action {
        case .task:
            guard !state.isRefreshLoopRunning else { return .none }
            state.isRefreshLoopRunning = true

            if shouldRefresh(lastUpdated: state.lastSuccessfulSync) {
                state.loadState = state.lastSuccessfulSync == nil
                    ? .loading
                    : .refreshing
                return .merge([loadAssets(), refreshLoop()])
            }

            return refreshLoop()

        case .refreshRequested, .refreshTimerFired:
            switch state.loadState {
            case .loading, .refreshing:
                return .none
            case .idle, .loaded, .stale, .failed:
                state.loadState = state.lastSuccessfulSync == nil
                    ? .loading
                    : .refreshing
                return loadAssets()
            }

        case .response(.success(let syncedAt)):
            state.lastSuccessfulSync = syncedAt
            state.loadState = .loaded
            return .none

        case .response(.failure(let failure)):
            return applyFailure(failure, to: &state)

        case .stop:
            state.isRefreshLoopRunning = false
            return .merge([
                .cancel(id: CancelID.request),
                .cancel(id: CancelID.refreshLoop)
            ])
        }
    }
}

private extension TopAssetsReducer {
    func shouldRefresh(lastUpdated: Date?) -> Bool {
        guard let lastUpdated else { return true }
        let components = refreshInterval.components
        let refreshSeconds = Double(components.seconds)
            + Double(components.attoseconds) / 1_000_000_000_000_000_000
        return now().timeIntervalSince(lastUpdated) >= refreshSeconds
    }

    func loadAssets() -> Effect<TopAssetsAction> {
        .run(id: CancelID.request) {
            do {
                let syncedAt = try await syncService.refreshTopAssets()
                return .response(.success(syncedAt))
            } catch is CancellationError {
                return nil
            } catch {
                return .response(.failure(CoinGeckoFailure(error)))
            }
        }
    }

    func refreshLoop() -> Effect<TopAssetsAction> {
        .stream(id: CancelID.refreshLoop) {
            AsyncStream { continuation in
                let task = Task {
                    while !Task.isCancelled {
                        do {
                            try await clock.sleep(for: refreshInterval)
                        } catch {
                            break
                        }

                        guard !Task.isCancelled else { break }
                        continuation.yield(.refreshTimerFired)
                    }
                    continuation.finish()
                }

                continuation.onTermination = { _ in
                    task.cancel()
                }
            }
        }
    }

    func applyFailure(
        _ failure: CoinGeckoFailure,
        to state: inout TopAssetsState
    ) -> Effect<TopAssetsAction> {
        state.loadState = state.lastSuccessfulSync == nil
            ? .failed(failure)
            : .stale(failure)
        return .none
    }
}
