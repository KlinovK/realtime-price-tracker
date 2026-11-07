import Foundation

/// A view-only interpretation of persisted values and current connection evidence.
nonisolated struct FavoritePricePresentation: Equatable {
    nonisolated enum Status: Equatable {
        case live
        case snapshot
        case cached
        case missing

        var accessibilityLabel: String {
            switch self {
            case .live: "Live"
            case .snapshot: "Snapshot"
            case .cached: "Cached"
            case .missing: "Missing"
            }
        }
    }

    nonisolated enum Source: Equatable {
        case binance
        case coinGecko
        case none
    }

    let price: Decimal?
    let change24h: Decimal?
    let source: Source
    let status: Status

    init(
        snapshotPrice: Decimal?,
        snapshotChange24h: Decimal?,
        livePrice: Decimal?,
        liveChange24h: Decimal?,
        liveUpdatedAt: Date?,
        committedVersion: LiveQuoteVersion?,
        connection: MarketsConnectionState
    ) {
        let observedVersion = LiveQuoteVersion(
            price: livePrice,
            change24h: liveChange24h,
            updatedAt: liveUpdatedAt
        )
        if case .live = connection,
           let committedVersion,
           committedVersion == observedVersion,
           let livePrice {
            self.price = livePrice
            change24h = liveChange24h
            source = .binance
            status = .live
        } else if let snapshotPrice {
            price = snapshotPrice
            change24h = snapshotChange24h
            source = .coinGecko
            if case .live = connection {
                status = .snapshot
            } else {
                status = .cached
            }
        } else if let livePrice {
            price = livePrice
            change24h = liveChange24h
            source = .binance
            status = .cached
        } else {
            price = nil
            change24h = nil
            source = .none
            status = .missing
        }
    }
}
