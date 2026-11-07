//
//  MarketsState.swift
//  RealTimePriceTracker
//
//  Created by Константин Клинов on 19/05/26.
//

import Foundation

/// User-relevant failures produced by HTTP loading, realtime transport, or
/// freshness monitoring.
///
/// Transport-specific errors are converted here so the reducer and view do not
/// need to inspect arbitrary `Error` values.
nonisolated enum MarketsFailure: Error, Equatable, Sendable {
    case noMarketsAvailable
    case offline
    case timedOut
    case connectionLost
    case serverError(statusCode: Int)
    case invalidServerResponse
    case invalidSubscription
    case persistenceFailed
    case unexpected(String)

    init(_ error: Error) {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                self = .offline
            case .timedOut:
                self = .timedOut
            case .networkConnectionLost:
                self = .connectionLost
            default:
                self = .unexpected(urlError.localizedDescription)
            }
        } else if error is WebSocketClientError {
            self = .connectionLost
        } else if let serviceError = error as? TopSymbolsServiceError {
            switch serviceError {
            case .httpStatusCode(let statusCode):
                self = .serverError(statusCode: statusCode)
            case .invalidHTTPResponse, .invalidPayload:
                self = .invalidServerResponse
            }
        } else {
            self = .unexpected(error.localizedDescription)
        }
    }

    init(_ failure: MarketStreamFailure) {
        switch failure {
        case .timedOut:
            self = .timedOut
        case .connectionLost:
            self = .connectionLost
        case .invalidSubscription:
            self = .invalidSubscription
        case .transport(let message):
            self = .unexpected(message)
        }
    }

    var userMessage: String {
        switch self {
        case .noMarketsAvailable:
            return "No markets are available right now."
        case .offline:
            return "You appear to be offline."
        case .timedOut:
            return "The market connection timed out."
        case .connectionLost:
            return "The live market connection was lost."
        case .serverError(let statusCode):
            return "The market server returned an error (HTTP \(statusCode))."
        case .invalidServerResponse:
            return "The market server returned invalid data."
        case .invalidSubscription:
            return "No valid Binance subscriptions are available."
        case .persistenceFailed:
            return "Live prices could not be saved safely."
        case .unexpected(let message):
            return message
        }
    }
}

/// The complete connection state machine rendered by ``MarketsView``.
///
/// `stale` means cached assets remain useful but cannot be presented as live;
/// `failed` means there is no usable market result to display.
nonisolated enum MarketsConnectionState: Equatable, Sendable {
    case idle
    case loadingSymbols
    case connecting
    case reconnecting(attempt: Int, failure: MarketsFailure)
    case live
    case stale(MarketsFailure)
    case failed(MarketsFailure)
}

/// Capped exponential-backoff policy used for automatic reconnection.
///
/// The standard sequence is 0.5, 1, 2, 4, and 8 seconds.
///
/// - Warning: Delays currently have no jitter. Add injected, bounded randomness
///   before using this policy for a large population of production clients.
nonisolated struct MarketsReconnectPolicy: Equatable, Sendable {
    static let standard = Self(
        maxAttempts: 5,
        initialDelay: .milliseconds(500),
        maximumDelay: .seconds(8)
    )

    let maxAttempts: Int
    let initialDelay: Duration
    let maximumDelay: Duration

    init(
        maxAttempts: Int,
        initialDelay: Duration,
        maximumDelay: Duration
    ) {
        precondition(maxAttempts > 0)
        precondition(initialDelay > .zero)
        precondition(maximumDelay >= initialDelay)
        self.maxAttempts = maxAttempts
        self.initialDelay = initialDelay
        self.maximumDelay = maximumDelay
    }

    func delay(forAttempt attempt: Int) -> Duration {
        precondition(attempt > 0)
        var delay = initialDelay

        for _ in 1..<attempt {
            let doubled = delay + delay
            delay = doubled < maximumDelay ? doubled : maximumDelay
        }

        return delay
    }
}

/// Transient connection orchestration only. Asset values live exclusively in
/// SwiftData and are never copied into reducer state.
nonisolated struct MarketsState: Equatable {
    var connection: MarketsConnectionState = .idle
    /// Changes whenever the stream is replaced or invalidated.
    var generation = 0
    /// Receipts for quotes saved during the active stream generation.
    var committedQuoteVersions: [String: LiveQuoteVersion] = [:]
    /// Tracks transport freshness independently from price changes.
    /// An unchanged ticker event still proves that the stream is alive.
    var lastEventAt: Date?
    /// Distinguishes a running retry from its cancellable backoff delay.
    var reconnectAttemptIsActive = false
    var subscriptions: [FavoriteAssetSubscription] = []
}
