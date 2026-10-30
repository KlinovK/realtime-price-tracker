//
//  Theme.swift
//  RealTimePriceTracker
//
//  Created by Константин Клинов on 19/05/26.
//

import SwiftUI

/// Shared application background token for the current visual theme.
enum ThemeBackground {

    static let background = LinearGradient(
        colors: [
            Color.black,
            Color.indigo,
            Color.purple
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
