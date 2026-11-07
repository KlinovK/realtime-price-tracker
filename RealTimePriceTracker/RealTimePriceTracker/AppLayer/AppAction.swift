//
//  AppAction.swift
//  RealTimePriceTracker
//

/// Root action routes child-feature events and persisted favorite commands.
nonisolated enum AppAction: Sendable {
    case appBecameActive
    case appEnteredBackground
    case favoritesAppeared
    case favoritesDisappeared
    case persistenceBootstrapped(
        Result<[FavoriteAssetSubscription], MarketsFailure>
    )
    case favoriteSubscriptionsLoaded(
        Result<[FavoriteAssetSubscription], MarketsFailure>
    )
    case markets(MarketsAction)
    case topAssets(TopAssetsAction)
    case assetDetails(AssetDetailsAction)
    case toggleFavorite(coinGeckoID: String)
}
