//
//  RootView.swift
//  RealTimePriceTracker
//
//  Created by Константин Клинов on 19/05/26.
//

import SwiftUI

/// The root container view of the application.
///
/// `RootView` is responsible for:
/// - Creating and owning the application's main state store
/// - Managing the lifecycle of the shared store instance
/// - Injecting the store into the feature hierarchy
///
/// The store is initialized once using `@StateObject`,
/// ensuring it persists across SwiftUI view updates.
struct RootView: View {

    // MARK: - Properties

    /// Centralized state store for market-related features.
    ///
    /// The store manages:
    /// - `MarketsState` as the source of truth
    /// - `MarketsReducer` for handling state transitions
    @StateObject
    private var store = Store(
        initialState: MarketsState(),
        reducer: MarketsReducer()
    )

    // MARK: - Body

    /// The primary content displayed by the application.
    ///
    /// Passes the shared store into `MarketsView`.
    var body: some View {
        MarketsView(store: store)
    }
}
