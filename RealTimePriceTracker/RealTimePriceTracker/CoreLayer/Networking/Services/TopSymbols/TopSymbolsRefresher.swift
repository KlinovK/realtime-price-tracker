//
//  TopSymbolsRefresher.swift
//  RealTimePriceTracker
//
//  Created by Константин Клинов on 19/05/26.
//

import Foundation

/// A service responsible for periodically refreshing top trading symbols.
///
/// Emits updated symbol lists every 60 seconds as an AsyncStream.
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
    func stream() -> AsyncStream<[String]> {
        AsyncStream { continuation in
            let task = Task {
                while !Task.isCancelled {
                    let symbols = await service.fetchTopSymbols()
                    let top100 = Array(symbols.prefix(100))
                    continuation.yield(top100)
                    try? await Task.sleep(
                        nanoseconds: refreshIntervalNanoseconds
                    )
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
