//
//  AssetRow.swift
//  RealTimePriceTracker
//
//  Created by Константин Клинов on 19/05/26.
//

import SwiftUI

/// A compact heatmap-style cell representing a crypto asset.
///
/// `AssetHeatCell` visually encodes:
/// - Symbol (identity)
/// - Price (current value)
/// - 24h change (market momentum + heat color)
///
/// Includes a subtle pulse animation when price updates.
struct AssetHeatCell: View {

    // MARK: - Properties

    let asset: CryptoAsset

    /// Controls pulse animation when price changes.
    @State private var pulse = false

    // MARK: - Body

    var body: some View {

        VStack(spacing: 6) {
            header
            price
            change
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(background)
        .scaleEffect(pulse ? 1.06 : 1.0)
        .animation(.easeInOut(duration: 0.22), value: pulse)
        .onChange(of: asset.price) {
            triggerPulse()
        }
    }
}

// MARK: - Subviews

private extension AssetHeatCell {

    /// Symbol header (compact asset identity)
    var header: some View {
        Text(AssetHeatCellFormatting.shortSymbol(asset.symbol))
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white.opacity(0.95))
            .tracking(0.5)
    }

    /// Current asset price display
    var price: some View {
        Text(AssetHeatCellFormatting.formatPrice(asset.price))
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.white.opacity(0.9))
    }

    /// 24h change indicator
    var change: some View {
        Text(AssetHeatCellFormatting.formatChange(asset.change24h))
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
    }

    /// Heat-based background styling
    var background: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(HeatColor.color(for: asset.change24h))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
    }
}

// MARK: - Animation

private extension AssetHeatCell {

    /// Triggers a short pulse animation when price updates.
    func triggerPulse() {
        pulse = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            pulse = false
        }
    }
}
