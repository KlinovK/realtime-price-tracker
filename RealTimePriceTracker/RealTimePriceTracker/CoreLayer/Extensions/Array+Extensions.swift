//
//  Array+Extensions.swift
//  RealTimePriceTracker
//
//  Created by Константин Клинов on 19/05/26.
//

import Foundation
import Algorithms

extension Array {

    // MARK: - Chunking

    /// Splits the array into smaller arrays of a fixed maximum size.
    ///
    /// Example:
    /// ```swift
    /// let numbers = [1, 2, 3, 4, 5]
    /// let chunks = numbers.chunked(into: 2)
    ///
    /// // [[1, 2], [3, 4], [5]]
    /// ```
    ///
    /// - Parameter size:
    ///   The maximum number of elements per chunk.
    ///
    /// - Returns:
    ///   A two-dimensional array containing chunked elements.
    func chunked(into size: Int) -> [[Element]] {

        guard size > 0 else { return [] }

        return chunks(ofCount: size).map(Array.init)

    }
}
