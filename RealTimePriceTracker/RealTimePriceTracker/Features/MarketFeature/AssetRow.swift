//
//  AssetRow.swift
//  RealTimePriceTracker
//
//  Created by Константин Клинов on 19/05/26.
//

import SwiftUI

struct AssetRow: View {

    let asset: CryptoAsset

    @State
    private var animateGlow = false

    var body: some View {

        VStack(alignment: .leading, spacing: 12) {

            HStack {

                VStack(alignment: .leading, spacing: 4) {

                    Text(asset.symbol)
                        .font(.headline)
                        .foregroundColor(.white)

                    Text(asset.formattedPrice)
                        .font(.title2.bold())
                        .foregroundColor(.white)
                }

                Spacer()

                Text(asset.formattedChange)
                    .font(.headline)
                    .foregroundColor(
                        asset.isPositive ? .green : .red
                    )
            }

            HStack(spacing: 8) {

                Circle()
                    .fill(asset.isPositive ? .green : .red)
                    .frame(width: 10, height: 10)
                    .scaleEffect(animateGlow ? 1.2 : 0.8)
                    .animation(
                        .easeInOut(duration: 1)
                        .repeatForever(),
                        value: animateGlow
                    )

                Text("LIVE")
                    .foregroundColor(.white.opacity(0.7))
                    .font(.caption)
            }
        }
        .padding()
        .background(
            GlassCard()
        )
        .onAppear {
            animateGlow = true
        }
    }

}

extension AssetRow: Equatable {
    static func == (
         lhs: AssetRow,
         rhs: AssetRow
     ) -> Bool {
         lhs.asset == rhs.asset
     }
}
