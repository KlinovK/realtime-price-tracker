//
//  MarketsReducer.swift
//  RealTimePriceTracker
//
//  Created by Константин Клинов on 19/05/26.
//

import Foundation

/// Handles all market-related business logic and state transitions.
///
/// Responsibilities:
/// - Starts and manages real-time WebSocket streaming
/// - Decodes incoming Binance ticker messages
/// - Maintains a normalized list of crypto assets
/// - Performs diff-based updates to minimize SwiftUI redraws
/// - Handles WebSocket lifecycle and failures
///
/// Architecture flow:
/// WebSocket → MarketsService → MarketsReducer → MarketsState → SwiftUI


struct MarketsReducer: ReducerProtocol {

    // MARK: - Dependencies

    /// Service responsible for WebSocket streaming.
    ///
    /// In production, this should be dependency injected for testability.
    
    private let service: MarketsServiceProtocol
    
    init(service: MarketsServiceProtocol = MarketsService()) {
          self.service = service
    }

    // MARK: - Reducer

    /// Core reducer function handling all market actions.
    ///
    /// - Parameters:
    ///   - state: Mutable application state
    ///   - action: Incoming user/system action
    ///
    /// - Returns:
    /// An asynchronous effect that may emit further actions.
    func reduce(
        state: inout MarketsState,
        action: MarketsAction
    ) async -> Effect<MarketsAction> {

        switch action {

        // MARK: - Lifecycle

        /// Triggered when the markets screen appears.
        case .onAppear:

            state.isLoading = true
            state.errorMessage = nil

            if state.streamURLs.isEmpty {
                await initializeStreams(in: &state)
            }

            let urls = state.streamURLs

            return .stream {
                service.startStreaming(with: urls)
            }

        // MARK: - WebSocket Message Handling

        /// Handles incoming WebSocket ticker updates.
        case .websocketMessage(let text):

            guard
                let data = text.data(using: .utf8),
                let response = try? JSONDecoder().decode(
                    BinanceSocketResponse.self,
                    from: data
                )
            else {
                return .none
            }

            let asset = CryptoAsset(
                id: response.data.symbol,
                symbol: response.data.symbol,
                price: Double(response.data.price) ?? 0,
                change24h: Double(response.data.changePercent) ?? 0
            )

            applyAssetUpdate(asset, to: &state)

            return .none

        // MARK: - Manual Updates

        case .updateAsset:
            return .none

        // MARK: - Failure Handling

        /// Triggered when WebSocket streaming fails.
        case .websocketFailed(let error):

            state.isLoading = false
            state.errorMessage = error.localizedDescription

            return .none

        // MARK: - Stream Rebuild

        case .rebuildStreams(let urls):

            service.stopStreaming()

            state.streamURLs = urls
            state.isLoading = true
            state.errorMessage = nil

            return .stream {
                service.startStreaming(with: urls)
            }
        }
    }
}

private extension MarketsReducer {

    /// Initializes WebSocket stream URLs if not already created.
    func initializeStreams(in state: inout MarketsState) async {

        let symbols = await TopSymbolsService().fetchTopSymbols()

        let config = StreamConfiguration(
            symbols: symbols,
            streamType: .ticker
        )

        state.streamURLs = EndpointFactory.makeURLs(configuration: config)
    }

    /// Applies incoming asset update using diff-based logic.
    func applyAssetUpdate(_ asset: CryptoAsset, to state: inout MarketsState) {

        if let index = state.assets.firstIndex(where: { $0.id == asset.id }) {

            guard state.assets[index] != asset else { return }

            state.assets[index] = asset

        } else {
            state.assets.append(asset)
        }

        if state.isLoading && !state.assets.isEmpty {
            state.isLoading = false
        }
    }
}
