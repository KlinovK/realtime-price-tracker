//
//  TopAssetRow.swift
//  RealTimePriceTracker
//

import SwiftUI

struct TopAssetRow: View {
    let asset: AssetRecord

    var body: some View {
        HStack(spacing: 12) {
            Text(asset.marketCapRank.map(String.init) ?? "—")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .trailing)

            AsyncImage(url: asset.imageURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit()
                } else {
                    Circle().fill(.quaternary)
                }
            }
            .frame(width: 34, height: 34)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(asset.name)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Text(asset.symbol.uppercased())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(MarketValueFormatting.price(asset.snapshotPrice))
                    .font(.subheadline.monospacedDigit().weight(.medium))
                Text(
                    MarketValueFormatting.percentage(
                        asset.snapshotChange24h
                    )
                )
                .font(.caption.monospacedDigit())
                .foregroundStyle(changeColor)
            }

        }
        .padding(.vertical, 4)
    }

    private var changeColor: Color {
        guard let change = asset.snapshotChange24h else {
            return .secondary
        }
        return change < .zero ? .red : .green
    }
}
