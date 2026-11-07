//
//  AppState.swift
//  RealTimePriceTracker
//

/// Root state composes transient feature orchestration.
/// Persisted assets, favorites, and charts intentionally do not appear here.
nonisolated struct AppState: Equatable {
    var markets = MarketsState()
    var topAssets = TopAssetsState()
    var assetDetails = AssetDetailsState()
    var didBootstrapPersistence = false
    var isFavoritesVisible = false
}
