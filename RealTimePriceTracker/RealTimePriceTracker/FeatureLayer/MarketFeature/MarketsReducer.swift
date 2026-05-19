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

                let t = response.data

                let asset = CryptoAsset(

                    id: t.symbol,

                    symbol: t.symbol,

                    price: Double(t.price) ?? 0,

                    change24h: Double(t.changePercent) ?? 0

                )

                if let index = state.assets.firstIndex(where: { $0.id == asset.id }) {

                    state.assets[index] = asset

                } else {

                    state.assets.append(asset)

                }

            } catch {

                print("❌ DECODE ERROR:", error)

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
