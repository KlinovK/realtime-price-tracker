//
//  ContentView.swift
//  RealTimePriceTracker
//
//  Created by Константин Клинов on 19/05/26.
//

import SwiftUI

struct MarketsView: View {

    @ObservedObject
    var store: Store<MarketsReducer>

    var body: some View {

        ZStack {

            ThemeBackground.background
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(store.state.assets) { asset in
                        AssetRow(asset: asset)
                    }
                }
                .padding()
            }
        }
        .task {
            store.send(.onAppear)
        }
    }
}

