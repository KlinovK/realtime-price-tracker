//
//  Effect.swift
//  RealTimePriceTracker
//
//  Created by Константин Клинов on 19/05/26.
//

import Foundation

/// Represents a side effect produced by a reducer or feature.
///
/// `Effect` defines asynchronous or streaming work that can
/// emit actions back into the system.
///
/// This is commonly used in unidirectional data flow architectures
/// to model:
/// - Async operations (network calls, tasks)
/// - Continuous streams (WebSockets, timers, polling)
///
/// - Parameter Action: The action type emitted back into the system.
enum Effect<Action> {

    /// No side effect is performed.
    case none

    /// Executes a single asynchronous operation.
    ///
    /// The operation may return an optional `Action`,
    /// which will be dispatched back to the system if non-nil.
    case run(
        operation: () async -> Action?
    )

    /// Starts a continuous asynchronous stream of actions.
    ///
    /// Each value emitted by the stream is dispatched as an `Action`.
    /// Useful for WebSockets, timers, and live data feeds.
    case stream(
        operation: () -> AsyncStream<Action>
    )
}
