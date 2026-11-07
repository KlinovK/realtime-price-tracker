//
//  TopSymbolsRefresher.swift
//  RealTimePriceTracker
//
//  Created by Константин Клинов on 19/05/26.
//

import Foundation

/// A service responsible for periodically refreshing top trading symbols.
///
/// Emits typed symbol-loading results every 60 seconds as an AsyncStream.
///
/// - Warning: This legacy type is not connected to the composed application. The
///   Top 100 now comes from `TopAssetsReducer`, while realtime streams are derived
///   from favorites.
/// - Recommendation: Inject a `Clock<Duration>` instead of nanoseconds before
///   integrating this stream, then define how removed symbols leave feature state.
final class TopSymbolsRefresher {

    // MARK: - Properties

    private let service: TopSymbolsServiceProtocol
    private let refreshIntervalNanoseconds: UInt64

    // MARK: - Init

    init(
        service: TopSymbolsServiceProtocol = TopSymbolsService(),
        refreshIntervalNanoseconds: UInt64 = 60_000_000_000
    ) {
        self.service = service
        self.refreshIntervalNanoseconds = refreshIntervalNanoseconds
    }

    // MARK: - Public API
    func stream() -> AsyncStream<Result<[String], MarketsFailure>> {
        AsyncStream { continuation in
            let task = Task {
                while !Task.isCancelled {
                    do {
                        let symbols = try await service.fetchTopSymbols()
                        continuation.yield(
                            .success(Array(symbols.prefix(100)))
                        )
                    } catch is CancellationError {
                        break
                    } catch {
                        continuation.yield(
                            .failure(MarketsFailure(error))
                        )
                    }

                    do {
                        try await Task.sleep(
                            nanoseconds: refreshIntervalNanoseconds
                        )
                    } catch {
                        break
                    }
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
