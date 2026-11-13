import Foundation

/// TCA-style orchestration for the favorite Binance subscription.
///
/// The reducer owns cancellation, freshness, and retry policy. The sync service
/// owns transport-to-database ingestion and emits only after a batch commits.
@MainActor
struct MarketsReducer: ReducerProtocol {
    nonisolated static let defaultStaleTimeout: Duration = .seconds(5)

    private enum CancelID {
        static let lifecycle = EffectCancellationID("markets.lifecycle")
        static let watchdog = EffectCancellationID("markets.watchdog")
        static let reconnectDelay = EffectCancellationID("markets.reconnect-delay")
    }

    private let syncService: any LivePricesSyncServiceProtocol
    private let clock: any Clock<Duration>
    private let staleTimeout: Duration
    private let reconnectPolicy: MarketsReconnectPolicy

    init(
        syncService: any LivePricesSyncServiceProtocol,
        clock: any Clock<Duration> = ContinuousClock(),
        staleTimeout: Duration = Self.defaultStaleTimeout,
        reconnectPolicy: MarketsReconnectPolicy = .standard
    ) {
        precondition(staleTimeout > .zero)
        self.syncService = syncService
        self.clock = clock
        self.staleTimeout = staleTimeout
        self.reconnectPolicy = reconnectPolicy
    }

    func reduce(
        state: inout MarketsState,
        action: MarketsAction
    ) -> Effect<MarketsAction> {
        switch action {
        case .onAppear:
            guard !state.subscriptions.isEmpty else { return .none }
            state.reconnectAttemptIsActive = false
            state.connection = .connecting
            return beginGeneration(
                state: &state,
                reconnectAttempt: nil
            )

        case .onDisappear:
            invalidateGeneration(&state)
            state.connection = .idle
            state.reconnectAttemptIsActive = false
            return cancelLiveEffects()

        case .retryTapped:
            guard !state.subscriptions.isEmpty else { return .none }
            state.reconnectAttemptIsActive = false
            state.connection = .connecting
            return .merge([
                .cancel(id: CancelID.reconnectDelay),
                beginGeneration(
                    state: &state,
                    reconnectAttempt: nil
                )
            ])

        case .subscriptionsChanged(let subscriptions):
            state.subscriptions = normalized(subscriptions)
            state.reconnectAttemptIsActive = false
            guard !state.subscriptions.isEmpty else {
                invalidateGeneration(&state)
                state.connection = .idle
                state.lastEventAt = nil
                return cancelLiveEffects()
            }

            state.connection = .connecting
            return .merge([
                .cancel(id: CancelID.reconnectDelay),
                beginGeneration(
                    state: &state,
                    reconnectAttempt: nil
                )
            ])

        case .syncEvent(let generation, .batchCommitted(let lastEventAt, let versions)):
            guard generation == state.generation else { return .none }
            state.lastEventAt = lastEventAt
            state.connection = .live
            state.committedQuoteVersions.merge(versions) { _, newest in newest }
            state.reconnectAttemptIsActive = false
            return startWatchdog(
                generation: generation,
                lastEventAt: lastEventAt,
                reconnectAttempt: nil
            )

        case .syncEvent(let generation, .failed(let failure)):
            guard generation == state.generation else { return .none }
            return handleStreamFailure(
                MarketsFailure(failure),
                state: &state
            )

        case .syncEvent(let generation, .persistenceFailed):
            guard generation == state.generation else { return .none }
            invalidateGeneration(&state)
            state.connection = .stale(.persistenceFailed)
            state.reconnectAttemptIsActive = false
            return cancelLiveEffects()

        case let .streamTimedOut(generation, expectedLastEventAt, expectedReconnectAttempt):
            guard generation == state.generation,
                  state.lastEventAt == expectedLastEventAt else { return .none }

            switch state.connection {
            case .connecting, .live:
                guard expectedReconnectAttempt == nil else { return .none }
                return scheduleReconnect(
                    afterAttempt: 0,
                    failure: .timedOut,
                    state: &state
                )

            case .reconnecting(let attempt, _):
                guard state.reconnectAttemptIsActive,
                      expectedReconnectAttempt == attempt else {
                    return .none
                }
                return scheduleReconnect(
                    afterAttempt: attempt,
                    failure: .timedOut,
                    state: &state
                )

            case .idle, .loadingSymbols, .stale, .failed:
                return .none
            }

        case .reconnectDelayElapsed(let generation, let attempt):
            guard generation == state.generation,
                  case .reconnecting(let currentAttempt, _) = state.connection,
                  currentAttempt == attempt,
                  !state.reconnectAttemptIsActive,
                  !state.subscriptions.isEmpty else {
                return .none
            }

            state.reconnectAttemptIsActive = true
            return beginGeneration(
                state: &state,
                reconnectAttempt: attempt
            )

        case .websocketFailed(let failure):
            return handleStreamFailure(failure, state: &state)
        }
    }
}

private extension MarketsReducer {
    func invalidateGeneration(_ state: inout MarketsState) {
        state.generation += 1
        state.committedQuoteVersions.removeAll()
    }

    func beginGeneration(
        state: inout MarketsState,
        reconnectAttempt: Int?
    ) -> Effect<MarketsAction> {
        invalidateGeneration(&state)
        return startLiveEffects(
            subscriptions: state.subscriptions,
            lastEventAt: state.lastEventAt,
            reconnectAttempt: reconnectAttempt,
            generation: state.generation
        )
    }

    func normalized(
        _ subscriptions: [FavoriteAssetSubscription]
    ) -> [FavoriteAssetSubscription] {
        Dictionary(
            subscriptions.map { ($0.coinGeckoID, $0) },
            uniquingKeysWith: { _, latest in latest }
        )
        .values
        .filter {
            BinancePairRegistry.approved.approves(
                coinGeckoID: $0.coinGeckoID,
                pairID: $0.binancePairID
            )
        }
        .sorted { $0.coinGeckoID < $1.coinGeckoID }
    }

    func startStreaming(
        subscriptions: [FavoriteAssetSubscription],
        generation: Int
    ) -> Effect<MarketsAction> {
        .stream(id: CancelID.lifecycle) {
            AsyncStream { continuation in
                let forwardingTask = Task {
                    for await event in syncService.start(
                        subscriptions: subscriptions
                    ) {
                        guard !Task.isCancelled else { break }
                        continuation.yield(.syncEvent(generation: generation, event))
                    }
                    continuation.finish()
                }

                continuation.onTermination = { _ in
                    forwardingTask.cancel()
                }
            }
        }
    }

    func startLiveEffects(
        subscriptions: [FavoriteAssetSubscription],
        lastEventAt: Date?,
        reconnectAttempt: Int?,
        generation: Int
    ) -> Effect<MarketsAction> {
        .merge([
            startStreaming(subscriptions: subscriptions, generation: generation),
            startWatchdog(
                generation: generation,
                lastEventAt: lastEventAt,
                reconnectAttempt: reconnectAttempt
            )
        ])
    }

    func startWatchdog(
        generation: Int,
        lastEventAt: Date?,
        reconnectAttempt: Int?
    ) -> Effect<MarketsAction> {
        .run(id: CancelID.watchdog) {
            do {
                try await clock.sleep(for: staleTimeout)
                return .streamTimedOut(
                    generation: generation,
                    lastEventAt: lastEventAt,
                    reconnectAttempt: reconnectAttempt
                )
            } catch {
                return nil
            }
        }
    }

    func handleStreamFailure(
        _ failure: MarketsFailure,
        state: inout MarketsState
    ) -> Effect<MarketsAction> {
        switch state.connection {
        case .connecting, .live:
            return scheduleReconnect(
                afterAttempt: 0,
                failure: failure,
                state: &state
            )

        case .reconnecting(let attempt, _):
            guard state.reconnectAttemptIsActive else { return .none }
            return scheduleReconnect(
                afterAttempt: attempt,
                failure: failure,
                state: &state
            )

        case .idle, .loadingSymbols, .stale, .failed:
            return .none
        }
    }

    func scheduleReconnect(
        afterAttempt attempt: Int,
        failure: MarketsFailure,
        state: inout MarketsState
    ) -> Effect<MarketsAction> {
        invalidateGeneration(&state)
        let nextAttempt = attempt + 1

        guard !state.subscriptions.isEmpty,
              nextAttempt <= reconnectPolicy.maxAttempts else {
            state.reconnectAttemptIsActive = false
            state.connection = .stale(failure)
            return cancelLiveEffects()
        }

        state.connection = .reconnecting(
            attempt: nextAttempt,
            failure: failure
        )
        state.reconnectAttemptIsActive = false
        let delay = reconnectPolicy.delay(forAttempt: nextAttempt)
        let generation = state.generation

        return .merge([
            .cancel(id: CancelID.lifecycle),
            .cancel(id: CancelID.watchdog),
            .run(id: CancelID.reconnectDelay) {
                do {
                    try await clock.sleep(for: delay)
                    return .reconnectDelayElapsed(generation: generation, attempt: nextAttempt)
                } catch {
                    return nil
                }
            }
        ])
    }

    func cancelLiveEffects() -> Effect<MarketsAction> {
        .merge([
            .cancel(id: CancelID.lifecycle),
            .cancel(id: CancelID.watchdog),
            .cancel(id: CancelID.reconnectDelay)
        ])
    }
}
