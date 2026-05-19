//
//  MarketsReducer.swift
//  RealTimePriceTracker
//
//  Created by Константин Клинов on 19/05/26.
//

import Foundation

struct MarketsReducer: ReducerProtocol {

    private let service = MarketsService()

    func reduce(
        state: inout MarketsState,
        action: MarketsAction
    ) async -> Effect<MarketsAction> {

        switch action {

        case .onAppear:

            state.isLoading = true

            return .stream {
                service.startStreaming()
            }

        case .websocketMessage(let text):

            guard let data = text.data(using: .utf8) else {
                return .none
            }

            do {

                let response = try JSONDecoder().decode(
                    BinanceSocketResponse.self,
                    from: data
                )

                let ticker = response.data

                let asset = CryptoAsset(
                    id: ticker.symbol,
                    symbol: ticker.symbol,
                    price: Double(ticker.currentPrice) ?? 0,
                    change24h: Double(ticker.changePercent) ?? 0
                )

                if let index = state.assets.firstIndex(
                    where: { $0.id == asset.id }
                ) {

                    state.assets[index] = asset

                } else {

                    state.assets.append(asset)
                }

            } catch {
                state.errorMessage = error.localizedDescription
            }

            return .none

        case .updateAsset:
            return .none

        case .websocketFailed(let error):

            state.errorMessage = error.localizedDescription

            return .none
        }
    }
}

struct BinanceSocketResponse: Codable {
    let stream: String
    let data: BinanceTickerResponse
}
