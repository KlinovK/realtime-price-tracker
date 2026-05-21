//
//  GlassCard.swift
//  RealTimePriceTracker
//
//  Created by Константин Клинов on 19/05/26.
//

import SwiftUI

/// A modern glass-style container with subtle depth, glow, and animated-friendly styling.
///
/// Designed for:
/// - Market cards
/// - Dashboard widgets
/// - Floating UI panels
struct GlassCard<Content: View>: View {

    // MARK: - Properties

    /// Corner radius of the card.
    private let cornerRadius: CGFloat

    /// Inner content of the card.
    private let content: Content

    // MARK: - Init

    init(
        cornerRadius: CGFloat = 24,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    // MARK: - Body

    var body: some View {

        ZStack {

            // Background glass layer
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)

            // Gradient glow border
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.7),
                            .cyan.opacity(0.25),
                            .blue.opacity(0.15),
                            .white.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )

            // Soft inner highlight
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.25),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
                .blur(radius: 0.3)

            // Content layer
            content
                .padding()
        }
        .shadow(color: .cyan.opacity(0.18), radius: 20, x: 0, y: 10)
        .shadow(color: .black.opacity(0.15), radius: 30, x: 0, y: 15)
        .overlay(
            // Ambient glow
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    RadialGradient(
                        colors: [
                            .cyan.opacity(0.10),
                            .clear
                        ],
                        center: .topLeading,
                        startRadius: 10,
                        endRadius: 200
                    )
                )
                .blendMode(.plusLighter)
        )
    }
}
