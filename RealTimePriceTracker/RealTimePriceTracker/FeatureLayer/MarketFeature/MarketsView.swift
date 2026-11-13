//
//  MarketsView.swift
//  RealTimePriceTracker
//

import SwiftData
import SwiftUI

/// First tab: a realtime heat-map containing only user-selected favorites.
struct MarketsView: View {
    let store: Store<AppReducer>

    @Query
    private var queriedAssets: [AssetRecord]

    @Query(sort: \FavoriteRecord.addedAt)
    private var favorites: [FavoriteRecord]

    private let columns = [
        GridItem(.adaptive(minimum: 82), spacing: 6)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !favoriteAssets.isEmpty {
                    connectionBanner
                }

                if favoriteAssets.isEmpty {
                    ContentUnavailableView(
                        "No Favorites",
                        systemImage: "star",
                        description: Text(
                            "Open Top 100 and add assets to your realtime collection."
                        )
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 6) {
                            ForEach(favoriteAssets) { market in
                                FavoriteAssetCell(
                                    market: market,
                                    presentation: FavoritePricePresentation(
                                        snapshotPrice: market.snapshotPrice,
                                        snapshotChange24h: market.snapshotChange24h,
                                        livePrice: market.livePrice,
                                        liveChange24h: market.liveChange24h,
                                        liveUpdatedAt: market.liveUpdatedAt,
                                        isApprovedPair: BinancePairRegistry.approved.approves(
                                            coinGeckoID: market.coinGeckoID,
                                            pairID: market.binancePairID
                                        ),
                                        committedVersion: store.state.markets
                                            .committedQuoteVersions[market.coinGeckoID],
                                        connection: store.state.markets.connection
                                    )
                                )
                            }
                        }
                        .padding(8)
                    }
                }
            }
            .navigationTitle("Favorites")
            .background(ThemeBackground.background.ignoresSafeArea())
        }
        .task {
            store.send(.favoritesAppeared)
        }
        .onDisappear {
            store.send(.favoritesDisappeared)
        }
    }
}

private extension MarketsView {
    var favoriteAssets: [AssetRecord] {
        let favoriteIDs = Set(favorites.map(\.coinGeckoID))
        return queriedAssets
            .filter { favoriteIDs.contains($0.coinGeckoID) }
            .sorted {
                let lhsRank = $0.marketCapRank ?? .max
                let rhsRank = $1.marketCapRank ?? .max
                if lhsRank != rhsRank { return lhsRank < rhsRank }
                return $0.coinGeckoID < $1.coinGeckoID
            }
    }

    @ViewBuilder
    var connectionBanner: some View {
        switch store.state.markets.connection {
        case .idle:
            EmptyView()

        case .loadingSymbols, .connecting:
            statusRow(color: .blue) {
                ProgressView().tint(.white)
                Text("Connecting to live prices…")
            }

        case let .reconnecting(attempt, failure):
            statusRow(color: .orange) {
                ProgressView().tint(.white)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reconnecting — attempt \(attempt)")
                        .fontWeight(.semibold)
                    Text(failure.userMessage).font(.caption)
                }
                Spacer()
                retryButton
            }

        case .live:
            statusRow(color: .green) {
                Circle().fill(.green).frame(width: 8, height: 8)
                Text("Live").fontWeight(.semibold)
                Spacer()
                if let lastEventAt = store.state.markets.lastEventAt {
                    Text(lastEventAt, style: .relative)
                        .foregroundStyle(.secondary)
                }
            }

        case .stale(let failure):
            statusRow(color: .orange) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text("Snapshot only. \(failure.userMessage)")
                    .font(.caption)
                Spacer()
                retryButton
            }

        case .failed(let failure):
            statusRow(color: .red) {
                Image(systemName: "wifi.exclamationmark")
                Text(failure.userMessage).font(.caption)
                Spacer()
                retryButton
            }
        }
    }

    func statusRow<Content: View>(
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 8) { content() }
            .font(.subheadline)
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(color.opacity(0.28))
            .accessibilityElement(children: .combine)
    }

    var retryButton: some View {
        Button("Retry") {
            store.send(.markets(.retryTapped))
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .tint(.white.opacity(0.2))
    }
}
