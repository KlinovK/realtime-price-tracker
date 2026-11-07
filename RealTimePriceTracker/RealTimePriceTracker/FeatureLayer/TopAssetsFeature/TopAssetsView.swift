//
//  TopAssetsView.swift
//  RealTimePriceTracker
//

import SwiftData
import SwiftUI

/// Second tab: CoinGecko's market-cap-ranked Top 100 list.
struct TopAssetsView: View {
    let store: Store<AppReducer>

    @Query(filter: #Predicate<AssetRecord> { $0.isTopAsset })
    private var queriedAssets: [AssetRecord]

    @Query
    private var favorites: [FavoriteRecord]

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Top 100")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            store.send(.topAssets(.refreshRequested))
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(isLoading)
                        .accessibilityLabel("Refresh Top 100")
                    }
                }
        }
        .task {
            store.send(.topAssets(.task))
        }
    }
}

private extension TopAssetsView {
    @ViewBuilder
    var content: some View {
        switch store.state.topAssets.loadState {
        case .idle where assets.isEmpty:
            ProgressView("Loading CoinGecko markets…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loading where assets.isEmpty:
            ProgressView("Loading CoinGecko markets…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .failed(let failure) where assets.isEmpty:
            ContentUnavailableView {
                Label("Unable to Load Markets", systemImage: "wifi.exclamationmark")
            } description: {
                Text(failure.userMessage)
            } actions: {
                Button("Retry") {
                    store.send(.topAssets(.refreshRequested))
                }
                .buttonStyle(.borderedProminent)
            }

        default:
            List {
                statusSection

                ForEach(assets) { asset in
                    HStack(spacing: 8) {
                        NavigationLink {
                            AssetDetailsView(
                                store: store,
                                coinGeckoID: asset.coinGeckoID
                            )
                        } label: {
                            TopAssetRow(asset: asset)
                        }

                        Button {
                            store.send(
                                .toggleFavorite(
                                    coinGeckoID: asset.coinGeckoID
                                )
                            )
                        } label: {
                            let isFavorite = favoriteIDs.contains(asset.coinGeckoID)
                            Image(systemName: isFavorite ? "star.fill" : "star")
                                .foregroundStyle(isFavorite ? .yellow : .secondary)
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            favoriteIDs.contains(asset.coinGeckoID)
                                ? "Remove from favorites"
                                : "Add to favorites"
                        )
                    }
                }
            }
            .listStyle(.plain)
            .refreshable {
                store.send(.topAssets(.refreshRequested))
            }
        }
    }

    @ViewBuilder
    var statusSection: some View {
        switch store.state.topAssets.loadState {
        case .refreshing:
            HStack {
                ProgressView()
                Text("Refreshing CoinGecko data…")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

        case .stale(let failure):
            Label(
                "Showing cached results. \(failure.userMessage)",
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(.caption)
            .foregroundStyle(.orange)

        case .loaded:
            if let lastUpdated {
                Text("Updated \(lastUpdated, style: .relative) · CoinGecko")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .failed(let failure):
            Label(
                "Showing cached results. \(failure.userMessage)",
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(.caption)
            .foregroundStyle(.orange)

        case .idle, .loading:
            EmptyView()
        }
    }

    var isLoading: Bool {
        switch store.state.topAssets.loadState {
        case .loading, .refreshing:
            return true
        case .idle, .loaded, .stale, .failed:
            return false
        }
    }

    var assets: [AssetRecord] {
        queriedAssets.sorted {
            let lhsRank = $0.marketCapRank ?? .max
            let rhsRank = $1.marketCapRank ?? .max
            if lhsRank != rhsRank { return lhsRank < rhsRank }
            return $0.coinGeckoID < $1.coinGeckoID
        }
    }

    var favoriteIDs: Set<String> {
        Set(favorites.map(\.coinGeckoID))
    }

    var lastUpdated: Date? {
        assets.map(\.snapshotUpdatedAt).max()
    }
}
