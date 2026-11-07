//
//  Effect.swift
//  RealTimePriceTracker
//
//  Created by Константин Клинов on 19/05/26.
//

import Foundation

/// Stable identity for asynchronous work owned by the store.
nonisolated struct EffectCancellationID: Hashable, Sendable {
    let rawValue: String

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

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
/// - Important: Every running effect has an identity. Starting another effect with
///   the same identity replaces the old task; explicit `.cancel` uses that same
///   identity to end work deterministically.
/// - Note: This intentionally small abstraction demonstrates effect ownership and
///   cancellation. Add dependencies, child feature scoping, and task priorities
///   here only when a feature actually needs them.
enum Effect<Action> {

    /// No side effect is performed.
    case none

    /// Executes a single asynchronous operation.
    ///
    /// The operation may return an optional `Action`,
    /// which will be dispatched back to the system if non-nil.
    case run(
        id: EffectCancellationID,
        operation: () async -> Action?
    )

    /// Starts a continuous asynchronous stream of actions.
    ///
    /// Each value emitted by the stream is dispatched as an `Action`.
    /// Useful for WebSockets, timers, and live data feeds.
    case stream(
        id: EffectCancellationID,
        operation: () -> AsyncStream<Action>
    )

    /// Starts multiple independent effects from one reducer transition.
    case merge([Effect<Action>])

    /// Cancels the task currently registered for this identity.
    case cancel(id: EffectCancellationID)
}

extension Effect where Action: Sendable {
    /// Lifts a child reducer effect into its parent action domain.
    ///
    /// The mapped stream owns a forwarding task and cancels it when its consumer
    /// terminates. This keeps child reducer composition explicit without teaching
    /// networking services about parent feature actions.
    func map<MappedAction: Sendable>(
        _ transform: @escaping @Sendable (Action) -> MappedAction
    ) -> Effect<MappedAction> {
        switch self {
        case .none:
            return .none

        case let .run(id, operation):
            return .run(id: id) {
                await operation().map(transform)
            }

        case let .stream(id, operation):
            return .stream(id: id) {
                AsyncStream { continuation in
                    let forwardingTask = Task {
                        for await action in operation() {
                            guard !Task.isCancelled else { break }
                            continuation.yield(transform(action))
                        }
                        continuation.finish()
                    }

                    continuation.onTermination = { _ in
                        forwardingTask.cancel()
                    }
                }
            }

        case .merge(let effects):
            return .merge(effects.map { $0.map(transform) })

        case .cancel(let id):
            return .cancel(id: id)
        }
    }
}
