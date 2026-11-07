import XCTest
@testable import RealTimePriceTracker

@MainActor
final class AssetDetailsReducerTests: XCTestCase {
    func test_taskPersistsSevenDayChartForSelectedAsset() async {
        let syncService = MockCoinGeckoSyncService()
        let reducer = AssetDetailsReducer(syncService: syncService)
        var state = AssetDetailsState()

        let effect = reducer.reduce(
            state: &state,
            action: .task(coinGeckoID: "bitcoin")
        )

        XCTAssertEqual(state.coinGeckoID, "bitcoin")
        XCTAssertEqual(state.loadState, .loading)
        guard case let .run(_, operation) = effect,
              case .chartResponse(let coinID, .success)? = await operation() else {
            return XCTFail("Expected committed chart response")
        }

        _ = reducer.reduce(
            state: &state,
            action: .chartResponse(coinID: coinID, .success(()))
        )

        XCTAssertEqual(state.loadState, .loaded)
        let chartIDs = await syncService.chartIDs
        XCTAssertEqual(chartIDs, ["bitcoin"])
    }

    func test_oldChartResponseCannotChangeNewSelectionStatus() {
        let reducer = AssetDetailsReducer(
            syncService: MockCoinGeckoSyncService()
        )
        var state = AssetDetailsState(
            coinGeckoID: "ethereum",
            loadState: .loading
        )

        _ = reducer.reduce(
            state: &state,
            action: .chartResponse(coinID: "bitcoin", .success(()))
        )

        XCTAssertEqual(state.coinGeckoID, "ethereum")
        XCTAssertEqual(state.loadState, .loading)
    }
}
