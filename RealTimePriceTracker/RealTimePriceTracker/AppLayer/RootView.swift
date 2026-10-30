//
//  RootView.swift
//  RealTimePriceTracker
//

import SwiftUI

/// Owns the single application store and presents the two feature tabs.
///
/// Swift Observation tracks only `Store.state`; no Combine publisher is involved.
/// Scene lifecycle events are actions, allowing reducers to cancel polling,
/// WebSockets, freshness deadlines, and reconnect delays in the background.
struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase

    let store: Store<AppReducer>

    var body: some View {
        TabView {
            Tab("Favorites", systemImage: "star.fill") {
                MarketsView(store: store)
            }

            Tab("Top 100", systemImage: "chart.bar.fill") {
                TopAssetsView(store: store)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            store.send(.appBecameActive)
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                store.send(.appBecameActive)
            case .background:
                store.send(.appEnteredBackground)
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }
}
