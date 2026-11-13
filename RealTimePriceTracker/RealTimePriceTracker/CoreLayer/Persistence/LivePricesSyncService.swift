import Foundation

nonisolated enum LivePricesSyncEvent: Equatable, Sendable {
    case batchCommitted(lastEventAt: Date, versions: [String: LiveQuoteVersion])
    case failed(MarketStreamFailure)
    case persistenceFailed
}

nonisolated protocol LivePricesSyncServiceProtocol: Sendable {
    func start(
        subscriptions: [FavoriteAssetSubscription]
    ) -> AsyncStream<LivePricesSyncEvent>
}

/// Bridges the Binance transport to the transactional SwiftData writer.
///
/// A live event is exposed to TCA only after its complete throttled batch has
/// committed. The UI matches the receipt to fields observed through `@Query`.
nonisolated struct LivePricesSyncService: LivePricesSyncServiceProtocol {
    private let transport: any MarketsServiceProtocol
    private let repository: any MarketDataRepositoryProtocol

    init(
        transport: any MarketsServiceProtocol,
        repository: any MarketDataRepositoryProtocol
    ) {
        self.transport = transport
        self.repository = repository
    }

    func start(
        subscriptions: [FavoriteAssetSubscription]
    ) -> AsyncStream<LivePricesSyncEvent> {
        AsyncStream { continuation in
            let task = Task {
                let approvedSubscriptions = subscriptions.filter {
                    BinancePairRegistry.approved.approves(
                        coinGeckoID: $0.coinGeckoID,
                        pairID: $0.binancePairID
                    )
                }
                guard !approvedSubscriptions.isEmpty else {
                    continuation.finish()
                    return
                }
                let symbols = Array(
                    Set(approvedSubscriptions.map(\.binancePairID))
                )
                .sorted()

                for await event in transport.startStreaming(symbols: symbols) {
                    guard !Task.isCancelled else { break }

                    switch event {
                    case .quotes(let quotes):
                        do {
                            let committedVersions = try await repository.applyLiveQuotes(
                                quotes,
                                subscriptions: approvedSubscriptions
                            )
                            if !committedVersions.isEmpty,
                               let lastEventAt = quotes.map(\.lastUpdated).max() {
                                continuation.yield(
                                    .batchCommitted(
                                        lastEventAt: lastEventAt,
                                        versions: committedVersions
                                    )
                                )
                            }
                        } catch is CancellationError {
                            break
                        } catch {
                            continuation.yield(.persistenceFailed)
                            continuation.finish()
                            return
                        }

                    case .failed(let failure):
                        continuation.yield(.failed(failure))
                    }
                }

                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
