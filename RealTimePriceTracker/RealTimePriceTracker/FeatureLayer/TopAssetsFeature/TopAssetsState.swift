//
//  TopAssetsState.swift
//  RealTimePriceTracker
//

import Foundation

nonisolated enum CoinGeckoFailure: Error, Equatable, Sendable {
    case offline
    case timedOut
    case rateLimited
    case serverError(statusCode: Int)
    case invalidResponse
    case noData
    case persistence
    case unexpected(String)

    init(_ error: Error) {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                self = .offline
            case .timedOut:
                self = .timedOut
            default:
                self = .unexpected(urlError.localizedDescription)
            }
        } else if let clientError = error as? CoinGeckoClientError {
            switch clientError {
            case .rateLimited:
                self = .rateLimited
            case .httpStatusCode(let statusCode):
                self = .serverError(statusCode: statusCode)
            case .emptyChart:
                self = .noData
            case .invalidRequest, .invalidHTTPResponse, .invalidPayload:
                self = .invalidResponse
            }
        } else if error is MarketDataRepositoryError {
            self = .persistence
        } else {
            self = .unexpected(error.localizedDescription)
        }
    }

    var userMessage: String {
        switch self {
        case .offline:
            return "You appear to be offline."
        case .timedOut:
            return "CoinGecko did not respond in time."
        case .rateLimited:
            return "CoinGecko rate limit reached. Please try again later."
        case .serverError(let statusCode):
            return "CoinGecko returned HTTP \(statusCode)."
        case .invalidResponse:
            return "CoinGecko returned invalid data."
        case .noData:
            return "No chart data is available for this asset."
        case .persistence:
            return "Downloaded data could not be saved safely."
        case .unexpected(let message):
            return message
        }
    }
}

/// Transient synchronization state. Persisted rows remain visible independently.
nonisolated enum TopAssetsLoadState: Equatable, Sendable {
    case idle
    case loading
    case loaded
    case refreshing
    case stale(CoinGeckoFailure)
    case failed(CoinGeckoFailure)
}

nonisolated struct TopAssetsState: Equatable, Sendable {
    var loadState: TopAssetsLoadState = .idle
    var lastSuccessfulSync: Date?
    var isRefreshLoopRunning = false
}
