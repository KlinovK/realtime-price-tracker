//
//  Store.swift
//  RealTimePriceTracker
//
//  Created by Константин Клинов on 19/05/26.
//

import Foundation
import Observation

/// A lightweight, custom implementation of a TCA-like state store.
///
/// The `Store` is responsible for:
/// - Holding application state (`State`)
/// - Processing user and system actions (`Action`)
/// - Running reducer logic to compute state changes
/// - Executing asynchronous side effects (`Effect`)
/// - Bridging state updates back to SwiftUI via Swift Observation
///
/// This implementation is designed for:
/// - SwiftUI apps
/// - Realtime systems (e.g. WebSockets, crypto tickers)
/// - Swift Concurrency (async/await + Task-based effects)
///
/// - Important: All state mutations and action handling occur on `MainActor` to
///   keep the observable state consistent with SwiftUI.
/// - Warning: Effect tasks are created by this main-actor store. Dependencies that
///   perform CPU-heavy parsing or long-running loops should provide their own actor
///   isolation instead of doing that work in the store's execution context.
@MainActor
@Observable
final class Store<R: ReducerProtocol> {

    // MARK: - Published State

    /// The single source of truth for the application state.
    ///
    /// Any updates to this property will automatically trigger SwiftUI view updates.
    private(set) var state: R.State

    // MARK: - Dependencies

    /// The reducer responsible for handling actions and producing new state + effects.
    @ObservationIgnored
    private let reducer: R

    // MARK: - Task Management

    private struct ManagedTask {
        let token: UUID
        let task: Task<Void, Never>
    }

    /// One task per effect identity. Starting another task with the same ID
    /// cancels and replaces the previous task.
    @ObservationIgnored
    private var tasks: [EffectCancellationID: ManagedTask] = [:]

    // MARK: - Initialization

    /// Creates a new `Store` with an initial state and reducer.
    ///
    /// - Parameters:
    ///   - initialState: The starting state of the application.
    ///   - reducer: The reducer that handles state transitions and effects.
    init(
        initialState: R.State,
        reducer: R
    ) {
        self.state = initialState
        self.reducer = reducer
    }

    // MARK: - Action Dispatching

    /// Sends an action into the store for processing.
    ///
    /// The flow is:
    /// 1. Capture current state
    /// 2. Pass state + action into reducer
    /// 3. Receive updated state + effect
    /// 4. Apply new state
    /// 5. Execute side effects (if any)
    ///
    /// - Parameter action: The action to process.
    /// - Important: Reduction always finishes before an effect starts. This keeps
    ///   the state transition synchronous even when the effect immediately emits.
    func send(_ action: R.Action) {
        /// Local mutable copy passed into reducer for deterministic updates.
        var currentState = state

        /// Reducers run synchronously. Asynchronous work is represented by
        /// the returned effect and feeds results back through new actions.
        let effect = reducer.reduce(
            state: &currentState,
            action: action
        )

        /// Publish only meaningful state changes.
        if state != currentState {
            state = currentState
        }

        /// Execute any side effects returned by reducer.
        handle(effect)
    }

    // MARK: - Effect Handling

    /// Handles side effects produced by the reducer.
    ///
    /// Effects can:
    /// - Do nothing (`.none`)
    /// - Run a single async operation (`.run`)
    /// - Produce a stream of actions (`.stream`)
    /// - Merge independent effects (`.merge`)
    /// - Cancel identified work (`.cancel`)
    ///
    /// - Parameter effect: The effect to execute.
    private func handle(_ effect: Effect<R.Action>) {

        switch effect {

        case .none:
            return

        case let .run(id, operation):

            cancelTask(id: id)
            let token = UUID()

            /// Executes a single asynchronous operation that may emit an action.
            let task = Task { [weak self] in
                defer { self?.finishTask(id: id, token: token) }

                if let action = await operation() {
                    guard !Task.isCancelled else { return }
                    self?.send(action)
                }
            }

            tasks[id] = ManagedTask(token: token, task: task)

        case let .stream(id, operation):

            cancelTask(id: id)
            let token = UUID()

            /// Executes a continuous stream of actions (e.g. WebSocket updates).
            let task = Task { [weak self] in
                defer { self?.finishTask(id: id, token: token) }

                let stream = operation()

                for await action in stream {
                    guard !Task.isCancelled else { break }
                    self?.send(action)
                }
            }

            tasks[id] = ManagedTask(token: token, task: task)

        case .merge(let effects):
            for effect in effects {
                handle(effect)
            }

        case let .cancel(id):
            cancelTask(id: id)
        }
    }

    private func cancelTask(id: EffectCancellationID) {
        tasks.removeValue(forKey: id)?.task.cancel()
    }

    private func finishTask(id: EffectCancellationID, token: UUID) {
        guard tasks[id]?.token == token else { return }
        tasks.removeValue(forKey: id)
    }
}
