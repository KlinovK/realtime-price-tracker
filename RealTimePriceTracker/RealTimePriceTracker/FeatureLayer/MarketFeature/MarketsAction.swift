//
//  MarketsAction.swift
//  RealTimePriceTracker
//
//  Created by Константин Клинов on 19/05/26.
//

import Foundation

/// Every event that can change the markets feature or start feature-owned work.
///
/// User intent, lifecycle events, dependency responses, stream batches, and retry
/// deadlines all enter the reducer through this single type. This makes the
/// business logic reproducible in reducer tests.
///
/// Provider events are persistence-aware: a committed-batch action means the
/// corresponding SwiftData transaction succeeded.
nonisolated enum MarketsAction: Sendable {
    case onAppear
    case onDisappear
    case retryTapped
    case subscriptionsChanged([FavoriteAssetSubscription])
    case syncEvent(LivePricesSyncEvent)
    case streamTimedOut(lastEventAt: Date?, reconnectAttempt: Int?)
    case reconnectDelayElapsed(attempt: Int)
    case websocketFailed(MarketsFailure)
}
