import Charts
import SwiftData
import SwiftUI

/// Asset details whose market snapshot, favorite state, and chart all come from
/// SwiftData queries. TCA state controls only chart synchronization status.
struct AssetDetailsView: View {
    let store: Store<AppReducer>
    let coinGeckoID: String

    @Query private var assets: [AssetRecord]
    @Query private var chart: [PricePointRecord]
    @Query private var favorites: [FavoriteRecord]

    init(store: Store<AppReducer>, coinGeckoID: String) {
        self.store = store
        self.coinGeckoID = coinGeckoID

        let selectedID = coinGeckoID
        _assets = Query(
            filter: #Predicate<AssetRecord> {
                $0.coinGeckoID == selectedID
            }
        )
        _chart = Query(
            filter: #Predicate<PricePointRecord> {
                $0.coinGeckoID == selectedID
            },
            sort: \PricePointRecord.date
        )
        _favorites = Query()
    }

    private var details: AssetDetailsState {
        guard store.state.assetDetails.coinGeckoID == coinGeckoID else {
            return AssetDetailsState(
                coinGeckoID: coinGeckoID,
                loadState: .loading
            )
        }
        return store.state.assetDetails
    }

    var body: some View {
        Group {
            if let asset = assets.first {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header(asset)
                        currentPrice(asset)
                        chartSection(asset)
                        statistics(asset)
                        sourceNote
                    }
                    .padding()
                }
            } else {
                ContentUnavailableView(
                    "Asset Unavailable",
                    systemImage: "externaldrive.badge.exclamationmark",
                    description: Text("The cached asset could not be found.")
                )
            }
        }
        .navigationTitle(assets.first?.name ?? "Asset")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    store.send(.toggleFavorite(coinGeckoID: coinGeckoID))
                } label: {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .foregroundStyle(isFavorite ? .yellow : .primary)
                }
                .accessibilityLabel(
                    isFavorite ? "Remove from favorites" : "Add to favorites"
                )
            }
        }
        .task(id: coinGeckoID) {
            store.send(.assetDetails(.task(coinGeckoID: coinGeckoID)))
        }
        .onDisappear {
            store.send(.assetDetails(.onDisappear))
        }
    }
}

private extension AssetDetailsView {
    var isFavorite: Bool {
        favorites.contains { $0.coinGeckoID == coinGeckoID }
    }

    func header(_ asset: AssetRecord) -> some View {
        HStack(spacing: 14) {
            AsyncImage(url: asset.imageURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit()
                } else {
                    Circle().fill(.quaternary)
                }
            }
            .frame(width: 54, height: 54)
            .clipShape(Circle())

            VStack(alignment: .leading) {
                Text(asset.name).font(.title2.bold())
                Text(asset.symbol.uppercased())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let rank = asset.marketCapRank {
                Text("#\(rank)")
                    .font(.headline.monospacedDigit())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.quaternary, in: Capsule())
            }
        }
    }

    func currentPrice(_ asset: AssetRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(MarketValueFormatting.price(asset.snapshotPrice))
                .font(.largeTitle.monospacedDigit().bold())

            Text(
                "24h \(MarketValueFormatting.percentage(asset.snapshotChange24h))"
            )
            .font(.headline.monospacedDigit())
            .foregroundStyle(changeColor(asset))
        }
    }

    @ViewBuilder
    func chartSection(_ asset: AssetRecord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Price · 7 days").font(.headline)
                Spacer()
                if details.loadState == .loading, !chart.isEmpty {
                    ProgressView().controlSize(.small)
                }
            }

            if chart.isEmpty {
                switch details.loadState {
                case .idle, .loading:
                    ProgressView("Loading chart…")
                        .frame(maxWidth: .infinity, minHeight: 220)

                case .failed(let failure):
                    chartFailure(failure)

                case .loaded:
                    ContentUnavailableView(
                        "Chart Unavailable",
                        systemImage: "chart.xyaxis.line"
                    )
                    .frame(maxWidth: .infinity, minHeight: 220)
                }
            } else {
                Chart(chart) { point in
                    AreaMark(
                        x: .value("Time", point.date),
                        yStart: .value("Range minimum", chartDomain.lowerBound),
                        yEnd: .value("Price", point.chartValue)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [chartColor.opacity(0.35), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Time", point.date),
                        y: .value("Price", point.chartValue)
                    )
                    .foregroundStyle(chartColor)
                    .interpolationMethod(.catmullRom)
                }
                .chartYScale(domain: chartDomain)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) {
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                    }
                }
                .frame(height: 240)
                .accessibilityLabel("Seven-day price chart for \(asset.name)")

                if case .failed(let failure) = details.loadState {
                    Label(
                        "Showing cached chart. \(failure.userMessage)",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                }
            }
        }
    }

    func chartFailure(_ failure: CoinGeckoFailure) -> some View {
        ContentUnavailableView {
            Label("Chart Unavailable", systemImage: "chart.xyaxis.line")
        } description: {
            Text(failure.userMessage)
        } actions: {
            Button("Retry") {
                store.send(.assetDetails(.retryTapped))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 220)
    }

    func statistics(_ asset: AssetRecord) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 14) {
            statisticRow(
                "Market cap",
                MarketValueFormatting.compactCurrency(asset.marketCap),
                "24h volume",
                MarketValueFormatting.compactCurrency(asset.totalVolume)
            )
            statisticRow(
                "24h high",
                MarketValueFormatting.price(asset.high24h),
                "24h low",
                MarketValueFormatting.price(asset.low24h)
            )
        }
        .padding()
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
    }

    func statisticRow(
        _ firstTitle: String,
        _ firstValue: String,
        _ secondTitle: String,
        _ secondValue: String
    ) -> some View {
        GridRow {
            statistic(title: firstTitle, value: firstValue)
            statistic(title: secondTitle, value: secondValue)
        }
    }

    func statistic(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline.monospacedDigit().weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var sourceNote: some View {
        Text("Market snapshot and historical chart provided by CoinGecko.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    func changeColor(_ asset: AssetRecord) -> Color {
        guard let change = asset.snapshotChange24h else { return .secondary }
        return change < .zero ? .red : .green
    }

    var chartColor: Color {
        guard let first = chart.first, let last = chart.last else {
            return .accentColor
        }
        return last.price < first.price ? .red : .green
    }

    var chartDomain: ClosedRange<Double> {
        let values = chart.map(\.chartValue)
        guard let minimum = values.min(), let maximum = values.max() else {
            return 0...1
        }

        let spread = maximum - minimum
        let padding = max(spread * 0.1, max(abs(maximum) * 0.001, 0.01))
        return (minimum - padding)...(maximum + padding)
    }
}
