//
//  AssetRow.swift
//  RealTimePriceTracker
//
//  Created by Константин Клинов on 19/05/26.
//

import SwiftUI

struct AssetHeatCell: View {

    let asset: CryptoAsset

    @State private var pulse = false

    var body: some View {

        VStack(spacing: 4) {

            Text(short(asset.symbol))
                .font(.caption2.bold())
                .foregroundColor(.white)

            Text(price(asset.price))
                .font(.caption2)
                .foregroundColor(.white.opacity(0.9))

            Text(change(asset.change24h))
                .font(.caption2.bold())
                .foregroundColor(.white)
        }
        .padding(6)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(HeatColor.color(for: asset.change24h))
        )
        .scaleEffect(pulse ? 1.06 : 1.0)
        .animation(.easeInOut(duration: 0.25), value: pulse)
        .onChange(of: asset.price) { _ in
            triggerPulse()
        }
    }

    private func triggerPulse() {
        pulse = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            pulse = false
        }
    }

    private func short(_ s: String) -> String {
        String(s.prefix(4))
    }

    private func price(_ p: Double) -> String {
        String(format: "%.2f", p)
    }

    private func change(_ c: Double) -> String {
        String(format: "%+.2f%%", c)
    }
}

extension AssetHeatCell: Equatable {
    static func == (
         lhs: AssetHeatCell,
         rhs: AssetHeatCell
     ) -> Bool {
         lhs.asset == rhs.asset
     }
}
