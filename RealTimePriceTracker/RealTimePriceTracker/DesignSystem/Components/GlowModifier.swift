//
//  GlowModifier.swift
//  RealTimePriceTracker
//
//  Created by Константин Клинов on 19/05/26.
//

import SwiftUI

/// Applies a multi-layer neon glow effect to any view.
/// Designed for:
/// - Crypto prices
/// - Active states
/// - Highlighted UI elements

struct GlowModifier: ViewModifier {

    // MARK: - Properties

    let primaryColor: Color
    let secondaryColor: Color
    let intensity: CGFloat
    let radius: CGFloat

    // MARK: - Body

    func body(content: Content) -> some View {
        content
            .shadow(color: primaryColor.opacity(0.7), radius: radius)
            .shadow(color: secondaryColor.opacity(0.4), radius: radius * 1.6)
            .shadow(color: primaryColor.opacity(0.25), radius: radius * 2.2)
    }

}
