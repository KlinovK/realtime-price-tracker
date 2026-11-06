import XCTest
@testable import RealTimePriceTracker

@MainActor
final class FavoritePricePresentationTests: XCTestCase {
    func test_relaunchAndReconnectNeverTreatPersistedQuoteAsLive() {
        for connection: MarketsConnectionState in [
            .idle, .connecting, .reconnecting(attempt: 1, failure: .connectionLost)
        ] {
            let result = presentation(
                snapshot: 100,
                quote: 110,
                hasEvidence: false,
                connection: connection
            )
            XCTAssertEqual(result.price, 100)
            XCTAssertEqual(result.source, .coinGecko)
            XCTAssertEqual(result.status, .cached)
        }
    }

    func test_committedQuoteRequiresLiveConnectionAndPerAssetEvidence() {
        let live = presentation(
            snapshot: 100, quote: 110,
            hasEvidence: true, connection: .live
        )
        XCTAssertEqual(live.price, 110)
        XCTAssertEqual(live.status, .live)

        let otherFavorite = presentation(
            snapshot: 200, quote: 210,
            hasEvidence: false, connection: .live
        )
        XCTAssertEqual(otherFavorite.price, 200)
        XCTAssertEqual(otherFavorite.status, .snapshot)

        let disconnected = presentation(
            snapshot: 100, quote: 110,
            hasEvidence: true, connection: .stale(.connectionLost)
        )
        XCTAssertEqual(disconnected.price, 100)
        XCTAssertEqual(disconnected.status, .cached)
    }

    func test_cachedQuoteWithoutSnapshotAndMissingPrices() {
        let cached = presentation(
            snapshot: nil, quote: 110,
            hasEvidence: false, connection: .idle
        )
        XCTAssertEqual(cached.price, 110)
        XCTAssertEqual(cached.source, .binance)
        XCTAssertEqual(cached.status, .cached)

        let missing = presentation(
            snapshot: nil, quote: nil,
            hasEvidence: false, connection: .idle
        )
        XCTAssertNil(missing.price)
        XCTAssertEqual(missing.source, .none)
        XCTAssertEqual(missing.status, .missing)
    }

    func test_sameTimestampWithDifferentObservedValueIsNotLive() {
        let timestamp = Date(timeIntervalSince1970: 10)
        let committed = LiveQuoteVersion(
            price: 120, change24h: 2, updatedAt: timestamp
        )
        let result = FavoritePricePresentation(
            snapshotPrice: 100,
            snapshotChange24h: 1,
            livePrice: 110,
            liveChange24h: 2,
            liveUpdatedAt: timestamp,
            committedVersion: committed,
            connection: .live
        )
        XCTAssertEqual(result.price, 100)
        XCTAssertEqual(result.status, .snapshot)
    }

    private func presentation(
        snapshot: Decimal?,
        quote: Decimal?,
        hasEvidence: Bool,
        connection: MarketsConnectionState
    ) -> FavoritePricePresentation {
        FavoritePricePresentation(
            snapshotPrice: snapshot,
            snapshotChange24h: 2,
            livePrice: quote,
            liveChange24h: 3,
            liveUpdatedAt: quote == nil ? nil : Date(timeIntervalSince1970: 10),
            committedVersion: hasEvidence
                ? LiveQuoteVersion(price: quote, change24h: 3,
                                   updatedAt: Date(timeIntervalSince1970: 10))
                : nil,
            connection: connection
        )
    }
}
