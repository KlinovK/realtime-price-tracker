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

    private let service = TopSymbolsService()

    // MARK: - Public API

    /// Starts a continuous stream of top symbols.
    ///
    /// - Returns: AsyncStream emitting updated symbol arrays every 60 seconds.
    func stream() -> AsyncStream<[String]> {

        AsyncStream { continuation in

            Task {

                while !Task.isCancelled {

                    let symbols = await service.fetchTopSymbols()
                    let top100 = Array(symbols.prefix(100))
                    continuation.yield(top100)

                    try? await Task.sleep(nanoseconds: 60_000_000_000)
                }
            }

            continuation.onTermination = { _ in
                continuation.finish()
            }
        }
    }
}
