//
//  AssetDetailsReducer.swift
//  RealTimePriceTracker
//

/// Orchestrates one asset's seven-day chart synchronization into SwiftData.
@MainActor
struct AssetDetailsReducer: ReducerProtocol {
    private static let requestID = EffectCancellationID("asset-details.chart")

    private let syncService: any CoinGeckoSyncServiceProtocol

    init(syncService: any CoinGeckoSyncServiceProtocol) {
        self.syncService = syncService
    }

    func reduce(
        state: inout AssetDetailsState,
        action: AssetDetailsAction
    ) -> Effect<AssetDetailsAction> {
        switch action {
        case .task(let coinGeckoID):
            if state.coinGeckoID == coinGeckoID,
               state.loadState == .loaded {
                return .none
            }

            state.coinGeckoID = coinGeckoID
            state.loadState = .loading
            return loadChart(for: coinGeckoID)

        case .retryTapped:
            guard let coinGeckoID = state.coinGeckoID else { return .none }
            state.loadState = .loading
            return loadChart(for: coinGeckoID)

        case let .chartResponse(coinID, .success):
            guard state.coinGeckoID == coinID else { return .none }
            state.loadState = .loaded
            return .none

        case let .chartResponse(coinID, .failure(failure)):
            guard state.coinGeckoID == coinID else { return .none }
            state.loadState = .failed(failure)
            return .none

        case .onDisappear:
            return .cancel(id: Self.requestID)
        }
    }
}

private extension AssetDetailsReducer {
    func loadChart(for coinID: String) -> Effect<AssetDetailsAction> {
        .run(id: Self.requestID) {
            do {
                try await syncService.refreshPriceHistory(
                    coinGeckoID: coinID
                )
                return .chartResponse(coinID: coinID, .success(()))
            } catch is CancellationError {
                return nil
            } catch {
                return .chartResponse(
                    coinID: coinID,
                    .failure(CoinGeckoFailure(error))
                )
            }
        }
    }
}
