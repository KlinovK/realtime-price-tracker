//
//  RootView.swift
//  RealTimePriceTracker
//
//  Created by Константин Клинов on 19/05/26.
//

import SwiftUI

struct RootView: View {

    @StateObject
    private var store = Store(
        initialState: MarketsState(),
        reducer: MarketsReducer()
    )

    var body: some View {
        MarketsView(store: store)
    }
}
