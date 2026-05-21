//
//  MarketsState.swift
//  RealTimePriceTracker
//
//  Created by Константин Клинов on 19/05/26.
//

import Foundation

struct MarketsState {
    var assets: [CryptoAsset] = []
    var isLoading = false
    var errorMessage: String?
    var streamURLs: [URL] = []
}
