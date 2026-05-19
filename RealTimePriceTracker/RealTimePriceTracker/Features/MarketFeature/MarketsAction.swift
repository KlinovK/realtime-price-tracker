//
//  MarketsAction.swift
//  RealTimePriceTracker
//
//  Created by Константин Клинов on 19/05/26.
//

import Foundation

enum MarketsAction {
    case onAppear
    case websocketMessage(String)
    case updateAsset(CryptoAsset)
    case websocketFailed(Error)
}
