//
//  AssetHeatCellTests.swift
//  RealTimePriceTrackerTests
//
//  Created by Kanstantsin Klinau on 21/05/26.
//

import Foundation
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

    func testFormatPrice_usesAdaptiveFinancialPrecision() {
        let locale = Locale(identifier: "en_US")

        XCTAssertEqual(
            AssetHeatCellFormatting.formatPrice(0, locale: locale),
            "0.00"
        )
        XCTAssertEqual(
            AssetHeatCellFormatting.formatPrice(1.236, locale: locale),
            "1.24"
        )
        XCTAssertEqual(
            AssetHeatCellFormatting.formatPrice(0.123456, locale: locale),
            "0.1235"
        )
        XCTAssertEqual(
            AssetHeatCellFormatting.formatPrice(0.00001234, locale: locale),
            "0.00001234"
        )
        XCTAssertEqual(
            AssetHeatCellFormatting.formatPrice(12_345.6, locale: locale),
            "12,345.60"
        )
    }

    func testFormatChange_includesSignAndPercent() {
        let locale = Locale(identifier: "en_US")

        XCTAssertEqual(
            AssetHeatCellFormatting.formatChange(0, locale: locale),
            "+0.00%"
        )
        XCTAssertEqual(
            AssetHeatCellFormatting.formatChange(2, locale: locale),
            "+2.00%"
        )
        XCTAssertEqual(
            AssetHeatCellFormatting.formatChange(-2, locale: locale),
            "-2.00%"
        )
        XCTAssertEqual(
            AssetHeatCellFormatting.formatChange(-2.345, locale: locale),
            "-2.35%"
        )
    }

    func testShouldPulse_onlyForMeaningfulRelativePriceChanges() {
        XCTAssertFalse(
            AssetHeatCellFormatting.shouldPulse(from: 100, to: 100.05)
        )
        XCTAssertTrue(
            AssetHeatCellFormatting.shouldPulse(from: 100, to: 100.2)
        )
        XCTAssertTrue(
            AssetHeatCellFormatting.shouldPulse(from: 0, to: 1)
        )
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
