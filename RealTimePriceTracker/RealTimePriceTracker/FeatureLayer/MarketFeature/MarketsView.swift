//
//  ContentView.swift
//  RealTimePriceTracker
//
//  Created by Kanstantin Klinau on 19/05/26.
//

import SwiftUI

struct MarketsView: View {

    @ObservedObject var store: Store<MarketsReducer>

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 5),
        count: 5
    )

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(store.state.assets) { asset in
                    AssetHeatCell(asset: asset)
                }
            }
            .padding(8)
        }
        .task {
            store.send(.onAppear)
        }
    }
}

