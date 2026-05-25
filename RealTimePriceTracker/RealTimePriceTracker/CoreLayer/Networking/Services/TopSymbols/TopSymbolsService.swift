//
//  TopSymbolsService.swift
//  RealTimePriceTracker
//
//  Created by Константин Клинов on 19/05/26.
//

import Foundation

protocol TopSymbolsServiceProtocol {
    func fetchTopSymbols() async -> [String]
}

/// Service responsible for fetching and preparing top trading symbols.
///
/// `TopSymbolsService`:
/// - Fetches 24h ticker data from Binance API
/// - Filters and ranks symbols by trading volume
/// - Provides a fallback list in case of network failure
final class TopSymbolsService: TopSymbolsServiceProtocol {

    // MARK: - Properties
    
    private let session: URLSession

    /// Fallback symbols used when network request fails.
    private let fallback: [String] = [
        "btcusdt",
        "ethusdt",
        "bnbusdt",
        "solusdt",
        "xrpusdt"
    ]
    
    // MARK: - Init
    
    init(session: URLSession = .shared) {
        self.session = session
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
    /// If the request fails, a predefined fallback list is returned.
    ///
    /// - Returns: Array of trading symbols (lowercased).
    func fetchTopSymbols() async -> [String] {

        let url = URL(string: "https://api.binance.com/api/v3/ticker/24hr")!

        do {
            let (data, _) = try await session.data(from: url)
            let tickers = try JSONDecoder().decode(
                [BinanceTicker24h].self,
                from: data
            )
            return tickers
                .filter { $0.symbol.hasSuffix("USDT") }
                .sorted {
                    (Double($0.quoteVolume) ?? 0) >
                    (Double($1.quoteVolume) ?? 0)
                }
                .prefix(100)
                .map { $0.symbol.lowercased() }
        } catch {
            return fallback
        }
    }
}
