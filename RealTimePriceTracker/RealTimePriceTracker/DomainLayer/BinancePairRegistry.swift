import Foundation

/// Explicit cross-provider identities. A matching ticker is never evidence that
/// a CoinGecko asset and a Binance base asset are the same asset.
nonisolated struct BinancePairRegistry: Sendable {
    nonisolated struct Entry: Equatable, Sendable {
        let coinGeckoID: String
        let pairID: String
        let baseAsset: String
        let quoteAsset: String
    }

    /// Initial identity approvals only. Stage 4.3 will check current Spot
    /// availability, base/quote assets, and trading status with exchangeInfo.
    static let approved = Self(entries: [
        Entry(coinGeckoID: "bitcoin", pairID: "BTCUSDT", baseAsset: "BTC", quoteAsset: "USDT"),
        Entry(coinGeckoID: "ethereum", pairID: "ETHUSDT", baseAsset: "ETH", quoteAsset: "USDT"),
        Entry(coinGeckoID: "solana", pairID: "SOLUSDT", baseAsset: "SOL", quoteAsset: "USDT")
    ])

    private let entriesByCoinGeckoID: [String: Entry]

    init(entries: [Entry]) {
        let countsByID = Dictionary(grouping: entries, by: \.coinGeckoID)
        let countsByPair = Dictionary(grouping: entries, by: \.pairID)
        entriesByCoinGeckoID = Dictionary(uniqueKeysWithValues: entries.compactMap { entry in
            guard !entry.coinGeckoID.isEmpty,
                  !entry.baseAsset.isEmpty,
                  !entry.quoteAsset.isEmpty,
                  entry.pairID == entry.baseAsset + entry.quoteAsset,
                  entry.pairID == entry.pairID.uppercased(),
                  countsByID[entry.coinGeckoID]?.count == 1,
                  countsByPair[entry.pairID]?.count == 1 else {
                return nil
            }
            return (entry.coinGeckoID, entry)
        })
    }

    func entry(for coinGeckoID: String) -> Entry? {
        entriesByCoinGeckoID[coinGeckoID]
    }

    func approves(coinGeckoID: String, pairID: String) -> Bool {
        entry(for: coinGeckoID)?.pairID == pairID
    }
}
