//
//  BinanceSocketResponse.swift
//  RealTimePriceTracker
//
//  Created by Константин Клинов on 19/05/26.
//

import Foundation

/// Transport DTO for Binance's combined-stream envelope.
///
/// This type must stay free of UI/business behavior. ``LatestAssetBatcher`` maps it
/// into ``CryptoAsset`` immediately after decoding.
nonisolated struct BinanceSocketResponse: Codable, Sendable {
    let stream: String
    let data: BinanceTickerResponse
}
