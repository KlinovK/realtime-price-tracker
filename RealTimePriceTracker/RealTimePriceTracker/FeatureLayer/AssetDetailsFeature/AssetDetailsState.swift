//
//  AssetDetailsState.swift
//  RealTimePriceTracker
//

import Foundation

nonisolated enum AssetDetailsLoadState: Equatable, Sendable {
    case idle
    case loading
    case loaded
    case failed(CoinGeckoFailure)
}

nonisolated struct AssetDetailsState: Equatable, Sendable {
    var coinGeckoID: String?
    var loadState: AssetDetailsLoadState = .idle
}
