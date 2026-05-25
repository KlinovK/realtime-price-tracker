//
//  AssetHeatCellTests.swift
//  RealTimePriceTrackerTests
//
//  Created by Kanstantsin Klinau on 21/05/26.
//

import XCTest
@testable import RealTimePriceTracker

@MainActor
final class AssetHeatCellTests: XCTestCase {

    // MARK: - Formatting

    func testShortSymbol_uppercasesAndTruncatesToFour() {
        XCTAssertEqual(AssetHeatCellFormatting.shortSymbol("btcusdt"), "BTCU")
        XCTAssertEqual(AssetHeatCellFormatting.shortSymbol("Eth"), "ETH")
        XCTAssertEqual(AssetHeatCellFormatting.shortSymbol("solana"), "SOLA")
    }

    func testFormatPrice_formatsToTwoDecimals() {
        XCTAssertEqual(AssetHeatCellFormatting.formatPrice(0), "0.00")
        XCTAssertEqual(AssetHeatCellFormatting.formatPrice(1.2), "1.20")
        XCTAssertEqual(AssetHeatCellFormatting.formatPrice(1.236), "1.24")
    }

    func testFormatChange_includesSignAndPercent() {
        XCTAssertEqual(AssetHeatCellFormatting.formatChange(0), "+0.00%")
        XCTAssertEqual(AssetHeatCellFormatting.formatChange(2), "+2.00%")
        XCTAssertEqual(AssetHeatCellFormatting.formatChange(-2), "-2.00%")
        XCTAssertEqual(AssetHeatCellFormatting.formatChange(-2.345), "-2.35%")
    }

    // MARK: - Heat mapping

    func testHeatBucket_thresholdBoundaries() {
        XCTAssertEqual(HeatColor.bucket(for: -10.01), .deepRed)
        XCTAssertEqual(HeatColor.bucket(for: -10), .strongRed)
        XCTAssertEqual(HeatColor.bucket(for: -5.0001), .strongRed)
        XCTAssertEqual(HeatColor.bucket(for: -5), .softRed)
        XCTAssertEqual(HeatColor.bucket(for: -0.0001), .softRed)
        XCTAssertEqual(HeatColor.bucket(for: 0), .neutral)
        XCTAssertEqual(HeatColor.bucket(for: 0.999), .neutral)
        XCTAssertEqual(HeatColor.bucket(for: 1), .softGreen)
        XCTAssertEqual(HeatColor.bucket(for: 2.999), .softGreen)
        XCTAssertEqual(HeatColor.bucket(for: 3), .strongGreen)
        XCTAssertEqual(HeatColor.bucket(for: 5.999), .strongGreen)
        XCTAssertEqual(HeatColor.bucket(for: 6), .brightGreen)
    }
}

