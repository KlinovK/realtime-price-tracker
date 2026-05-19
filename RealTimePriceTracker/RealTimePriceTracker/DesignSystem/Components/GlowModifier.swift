//
//  GlowModifier.swift
//  RealTimePriceTracker
//
//  Created by Константин Клинов on 19/05/26.
//

import SwiftUI

struct GlowModifier: ViewModifier {

    func body(content: Content) -> some View {

        content
            .shadow(color: .cyan.opacity(0.6), radius: 12)
            .shadow(color: .purple.opacity(0.4), radius: 20)
    }
}

extension View {

    func glow() -> some View {
        modifier(GlowModifier())
    }
}
