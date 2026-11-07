//
//  RealTimePriceTrackerApp.swift
//  RealTimePriceTracker
//
//  Created by Kanstantin Klinau on 19/05/26.
//

import SwiftData
import SwiftUI
/// The main entry point for the Real Time Price Tracker application.
///
/// `RealTimePriceTrackerApp` is responsible for:
/// - Launching the application
/// - Creating the primary app window
/// - Injecting the root view into the SwiftUI scene hierarchy
///
/// SwiftUI automatically initializes this type when the app starts.
@main
struct RealTimePriceTrackerApp: App {
    private let modelContainer: ModelContainer

    @State
    private var store: Store<AppReducer>

    init() {
        do {
            let container = try ModelContainer(
                for: AssetRecord.self,
                FavoriteRecord.self,
                PricePointRecord.self
            )
            let repository = MarketDataRepository(modelContainer: container)
            let coinGeckoClient = CoinGeckoClient()
            let coinGeckoSync = CoinGeckoSyncService(
                client: coinGeckoClient,
                repository: repository
            )
            let livePricesSync = LivePricesSyncService(
                transport: MarketsService(),
                repository: repository
            )
            let reducer = AppReducer(
                marketsReducer: MarketsReducer(syncService: livePricesSync),
                topAssetsReducer: TopAssetsReducer(
                    syncService: coinGeckoSync
                ),
                assetDetailsReducer: AssetDetailsReducer(
                    syncService: coinGeckoSync
                ),
                repository: repository
            )

            modelContainer = container
            _store = State(
                initialValue: Store(
                    initialState: AppState(),
                    reducer: reducer
                )
            )
        } catch {
            fatalError("Unable to create market database: \(error)")
        }
    }

    // MARK: - Body

    /// Defines the main scene displayed by the application.
    ///
    /// `WindowGroup` manages one or more app windows depending on the
    /// platform capabilities (iPhone, iPad, macOS).
    var body: some Scene {
        WindowGroup {
            makeRootView()
        }
        .modelContainer(modelContainer)
    }

    // MARK: - View Builders

    /// Creates the application's root view.
    ///
    /// Extracting the root view creation into a dedicated method improves:
    /// - Readability
    /// - Maintainability
    /// - Future dependency injection support
    ///
    /// - Returns: The root view displayed when the app launches.
    @ViewBuilder
    func makeRootView() -> some View {
        RootView(store: store)
    }
}
