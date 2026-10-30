/// Composition root for the TCA-inspired feature reducers.
///
/// Root effects mutate favorites through `MarketDataRepository`; views observe the
/// resulting SwiftData transaction instead of an optimistic reducer copy.
@MainActor
struct AppReducer: ReducerProtocol {
    private enum CancelID {
        static let bootstrap = EffectCancellationID("app.persistence.bootstrap")
        static let favorites = EffectCancellationID("app.favorites.command")
    }

    private let marketsReducer: MarketsReducer
    private let topAssetsReducer: TopAssetsReducer
    private let assetDetailsReducer: AssetDetailsReducer
    private let repository: any MarketDataRepositoryProtocol
    private let legacyFavorites: any FavoritesRepositoryProtocol

    init(
        marketsReducer: MarketsReducer,
        topAssetsReducer: TopAssetsReducer,
        assetDetailsReducer: AssetDetailsReducer,
        repository: any MarketDataRepositoryProtocol,
        legacyFavorites: any FavoritesRepositoryProtocol = FavoritesRepository()
    ) {
        self.marketsReducer = marketsReducer
        self.topAssetsReducer = topAssetsReducer
        self.assetDetailsReducer = assetDetailsReducer
        self.repository = repository
        self.legacyFavorites = legacyFavorites
    }

    func reduce(
        state: inout AppState,
        action: AppAction
    ) -> Effect<AppAction> {
        switch action {
        case .appBecameActive:
            var effects: [Effect<AppAction>] = [
                topAssetsReducer.reduce(
                    state: &state.topAssets,
                    action: .task
                )
                .map(AppAction.topAssets)
            ]

            if !state.didBootstrapPersistence {
                effects.append(bootstrapPersistence())
            } else if state.isFavoritesVisible {
                effects.append(loadFavoriteSubscriptions())
            }
            return .merge(effects)

        case .appEnteredBackground:
            let topEffect = topAssetsReducer.reduce(
                state: &state.topAssets,
                action: .stop
            )
            .map(AppAction.topAssets)
            let marketsEffect = marketsReducer.reduce(
                state: &state.markets,
                action: .onDisappear
            )
            .map(AppAction.markets)
            return .merge([topEffect, marketsEffect])

        case .favoritesAppeared:
            state.isFavoritesVisible = true
            return loadFavoriteSubscriptions()

        case .favoritesDisappeared:
            state.isFavoritesVisible = false
            return marketsReducer.reduce(
                state: &state.markets,
                action: .onDisappear
            )
            .map(AppAction.markets)

        case .persistenceBootstrapped(.success(let subscriptions)):
            state.didBootstrapPersistence = true
            guard state.isFavoritesVisible else { return .none }
            return marketsReducer.reduce(
                state: &state.markets,
                action: .subscriptionsChanged(subscriptions)
            )
            .map(AppAction.markets)

        case .persistenceBootstrapped(.failure):
            guard state.isFavoritesVisible else { return .none }
            return marketsReducer.reduce(
                state: &state.markets,
                action: .syncEvent(.persistenceFailed)
            )
            .map(AppAction.markets)

        case .favoriteSubscriptionsLoaded(.success(let subscriptions)):
            guard state.isFavoritesVisible else { return .none }
            return marketsReducer.reduce(
                state: &state.markets,
                action: .subscriptionsChanged(subscriptions)
            )
            .map(AppAction.markets)

        case .favoriteSubscriptionsLoaded(.failure):
            guard state.isFavoritesVisible else { return .none }
            return marketsReducer.reduce(
                state: &state.markets,
                action: .syncEvent(.persistenceFailed)
            )
            .map(AppAction.markets)

        case .markets(let childAction):
            return marketsReducer.reduce(
                state: &state.markets,
                action: childAction
            )
            .map(AppAction.markets)

        case .topAssets(let childAction):
            let childEffect = topAssetsReducer.reduce(
                state: &state.topAssets,
                action: childAction
            )
            .map(AppAction.topAssets)

            if case .response(.success) = childAction,
               state.isFavoritesVisible {
                return .merge([childEffect, loadFavoriteSubscriptions()])
            }
            return childEffect

        case .assetDetails(let childAction):
            return assetDetailsReducer.reduce(
                state: &state.assetDetails,
                action: childAction
            )
            .map(AppAction.assetDetails)

        case .toggleFavorite(let coinGeckoID):
            return toggleFavorite(coinGeckoID: coinGeckoID)
        }
    }
}

private extension AppReducer {
    func bootstrapPersistence() -> Effect<AppAction> {
        .run(id: CancelID.bootstrap) {
            do {
                let legacyIDs = await legacyFavorites.loadIDs()
                try await repository.importLegacyFavorites(legacyIDs)
                if !legacyIDs.isEmpty {
                    await legacyFavorites.saveIDs([])
                }
                let subscriptions = try await repository.favoriteSubscriptions()
                return .persistenceBootstrapped(.success(subscriptions))
            } catch is CancellationError {
                return nil
            } catch {
                return .persistenceBootstrapped(
                    .failure(.persistenceFailed)
                )
            }
        }
    }

    func loadFavoriteSubscriptions() -> Effect<AppAction> {
        .run(id: CancelID.favorites) {
            do {
                let subscriptions = try await repository.favoriteSubscriptions()
                return .favoriteSubscriptionsLoaded(.success(subscriptions))
            } catch is CancellationError {
                return nil
            } catch {
                return .favoriteSubscriptionsLoaded(
                    .failure(.persistenceFailed)
                )
            }
        }
    }

    func toggleFavorite(coinGeckoID: String) -> Effect<AppAction> {
        .run(id: CancelID.favorites) {
            do {
                try await repository.toggleFavorite(
                    coinGeckoID: coinGeckoID
                )
                let subscriptions = try await repository.favoriteSubscriptions()
                return .favoriteSubscriptionsLoaded(.success(subscriptions))
            } catch is CancellationError {
                return nil
            } catch {
                return .favoriteSubscriptionsLoaded(
                    .failure(.persistenceFailed)
                )
            }
        }
    }
}
