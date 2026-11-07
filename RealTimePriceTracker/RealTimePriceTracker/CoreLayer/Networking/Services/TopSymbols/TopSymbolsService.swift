//
//  TopSymbolsService.swift
//  RealTimePriceTracker
//
//  Created by Константин Клинов on 19/05/26.
//

import Foundation

/// Loads the current ranked market universe used to build realtime subscriptions.
protocol TopSymbolsServiceProtocol {
    func fetchTopSymbols() async throws -> [String]
}

nonisolated enum TopSymbolsServiceError: Error, Equatable, Sendable {
    case invalidHTTPResponse
    case httpStatusCode(Int)
    case invalidPayload
}

/// Service responsible for fetching and preparing top trading symbols.
///
/// `TopSymbolsService`:
/// - Fetches 24h ticker data from Binance API
/// - Filters and ranks symbols by trading volume
/// - Validates HTTP and decoding results before returning market data
///
/// - Warning: With the project's default main-actor isolation, payload decoding,
///   `Decimal` parsing, and sorting may execute on `MainActor` after the network
///   suspension. Move this work behind an actor or a nonisolated Sendable client if
///   profiling shows frame stalls.
/// - Warning: `URLSession.shared` supplies no feature-specific request deadline.
///   Inject a configured session or loader with an explicit timeout policy.
final class TopSymbolsService: TopSymbolsServiceProtocol {

    // MARK: - Properties
    
    private let dataLoader: (URL) async throws -> (Data, URLResponse)
    
    // MARK: - Init
    
    init(session: URLSession = .shared) {
        dataLoader = { url in
            try await session.data(from: url)
        }
    }

    init(
        dataLoader: @escaping (URL) async throws -> (Data, URLResponse)
    ) {
        self.dataLoader = dataLoader
    }

    // MARK: - Public API

    /// Fetches the top USDT trading symbols ranked by quote volume.
    ///
    /// This method:
    /// - Requests 24h ticker data from Binance
    /// - Filters symbols ending in "USDT"
    /// - Sorts them by highest quote volume
    /// - Returns the top 100 symbols in lowercase format
    ///
    /// - Returns: Array of trading symbols (lowercased).
    func fetchTopSymbols() async throws -> [String] {

        let url = URL(string: "https://api.binance.com/api/v3/ticker/24hr")!
        let (data, response) = try await dataLoader(url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TopSymbolsServiceError.invalidHTTPResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw TopSymbolsServiceError.httpStatusCode(
                httpResponse.statusCode
            )
        }

        let tickers: [BinanceTicker24h]
        do {
            tickers = try JSONDecoder().decode(
                [BinanceTicker24h].self,
                from: data
            )
        } catch {
            throw TopSymbolsServiceError.invalidPayload
        }

        return tickers
            .filter { $0.symbol.hasSuffix("USDT") }
            .compactMap { ticker -> (symbol: String, volume: Decimal)? in
                guard let volume = Decimal(
                    string: ticker.quoteVolume,
                    locale: Locale(identifier: "en_US_POSIX")
                ) else {
                    return nil
                }

                return (ticker.symbol, volume)
            }
            .sorted { $0.volume > $1.volume }
            .prefix(100)
            .map { $0.symbol.lowercased() }
    }
}
