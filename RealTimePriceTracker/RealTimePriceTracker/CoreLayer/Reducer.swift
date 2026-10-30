//
//  Reducer.swift
//  RealTimePriceTracker
//
//  Created by Константин Клинов on 19/05/26.
//

import Foundation

/// A synchronous state-transition function in the custom TCA-inspired runtime.
///
/// Reducers must mutate state deterministically and return an ``Effect`` for every
/// asynchronous operation. Results from that operation re-enter the system as a
/// new action instead of mutating state from a task.
///
/// - Important: Reduction is isolated to `MainActor`, which makes state changes
///   safe for SwiftUI and straightforward to test.
@MainActor
protocol ReducerProtocol {

    associatedtype State: Equatable
    associatedtype Action

    func reduce(
        state: inout State,
        action: Action
    ) -> Effect<Action>
}
