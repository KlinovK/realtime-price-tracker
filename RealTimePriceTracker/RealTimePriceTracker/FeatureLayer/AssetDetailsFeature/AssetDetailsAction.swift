//
//  AssetDetailsAction.swift
//  RealTimePriceTracker
//

nonisolated enum AssetDetailsAction: Sendable {
    case task(coinGeckoID: String)
    case retryTapped
    case chartResponse(
        coinID: String,
        Result<Void, CoinGeckoFailure>
    )
    case onDisappear
}
