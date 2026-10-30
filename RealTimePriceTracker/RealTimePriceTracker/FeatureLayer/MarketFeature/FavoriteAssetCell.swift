//
//  FavoriteAssetCell.swift
//  RealTimePriceTracker
//

import SwiftUI

/// Heat-map cell that prefers a Binance realtime quote and falls back to the last
/// ten-minute CoinGecko snapshot until the socket produces its first value.
struct FavoriteAssetCell: View {
    let market: AssetRecord

    @State private var pulse = false

    private var price: Decimal? {
        market.favoritePrice
    }

    private var change: Decimal {
        market.favoriteChange24h
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Text(market.symbol.uppercased())
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)

                Circle()
                    .fill(market.liveUpdatedAt == nil ? .orange : .green)
                    .frame(width: 5, height: 5)
                    .accessibilityLabel(
                        market.liveUpdatedAt == nil ? "Snapshot" : "Live"
                    )
            }

            Text(MarketValueFormatting.price(price))
                .font(.caption2.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(MarketValueFormatting.percentage(change))
                .font(.caption2.weight(.bold))
        }
        .foregroundStyle(.white)
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 82)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(HeatColor.color(for: change))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                }
        )
        .scaleEffect(pulse ? 1.05 : 1)
        .animation(.easeInOut(duration: 0.22), value: pulse)
        .onChange(of: market.livePrice) { oldPrice, newPrice in
            guard let oldPrice, let newPrice,
                  AssetHeatCellFormatting.shouldPulse(
                    from: oldPrice,
                    to: newPrice
                  ) else {
                return
            }

            pulse = true
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(150))
                pulse = false
            }
        }
        .accessibilityElement(children: .combine)
    }
}
