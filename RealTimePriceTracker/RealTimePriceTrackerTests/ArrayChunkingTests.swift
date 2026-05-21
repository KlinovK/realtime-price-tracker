//
//  ArrayChunkingTests.swift
//  RealTimePriceTrackerTests
//
//  Created by Kanstantsin Klinau on 20/05/26.
//

import XCTest
@testable import RealTimePriceTracker

final class ArrayChunkingTests: XCTestCase {

    // MARK: - Basic behavior

    func testChunkingEvenSplit() {
        let array = [1, 2, 3, 4]
        let result = array.chunked(into: 2)

        XCTAssertEqual(result, [[1, 2], [3, 4]])
    }

    func testChunkingUnevenSplit() {
        let array = [1, 2, 3, 4, 5]
        let result = array.chunked(into: 2)

        XCTAssertEqual(result, [[1, 2], [3, 4], [5]])
    }

    // MARK: - Edge cases

    func testChunkSizeOne() {
        let array = [1, 2, 3]
        let result = array.chunked(into: 1)

        XCTAssertEqual(result, [[1], [2], [3]])
    }

    func testChunkSizeEqualToArray() {
        let array = [1, 2, 3]
        let result = array.chunked(into: 3)

        XCTAssertEqual(result, [[1, 2, 3]])
    }

    func testChunkSizeLargerThanArray() {
        let array = [1, 2, 3]
        let result = array.chunked(into: 10)

        XCTAssertEqual(result, [[1, 2, 3]])
    }
}
