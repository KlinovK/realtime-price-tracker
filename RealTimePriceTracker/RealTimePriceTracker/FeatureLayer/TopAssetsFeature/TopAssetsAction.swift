//
//  TopAssetsAction.swift
//  RealTimePriceTracker
//

import Foundation

nonisolated enum TopAssetsAction: Sendable {
    case task
    case refreshRequested
    case refreshTimerFired
    case response(Result<Date, CoinGeckoFailure>)
    case stop
}
