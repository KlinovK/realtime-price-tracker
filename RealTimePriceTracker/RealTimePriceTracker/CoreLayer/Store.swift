//
//  Store.swift
//  RealTimePriceTracker
//
//  Created by Константин Клинов on 19/05/26.
//

import Foundation
import Combine

/// A lightweight, custom implementation of a TCA-like state store.
///
/// The `Store` is responsible for:
/// - Holding application state (`State`)
/// - Processing user and system actions (`Action`)
/// - Running reducer logic to compute state changes
/// - Executing asynchronous side effects (`Effect`)
/// - Bridging state updates back to SwiftUI via `@Published`
///
/// This implementation is designed for:
/// - SwiftUI apps
/// - Realtime systems (e.g. WebSockets, crypto tickers)
/// - Swift Concurrency (async/await + Task-based effects)
///
/// ⚠️ Note:
/// All state mutations and action handling occur on the `MainActor`
/// to ensure UI consistency.
@MainActor
final class Store<R: ReducerProtocol>: ObservableObject {

    // MARK: - Published State

    /// The single source of truth for the application state.
    ///
    /// Any updates to this property will automatically trigger SwiftUI view updates.
    @Published
    private(set) var state: R.State

    // MARK: - Dependencies

    /// The reducer responsible for handling actions and producing new state + effects.
    private let reducer: R

    // MARK: - Task Management

    /// Keeps references to running asynchronous tasks created by effects.
    ///
    /// This prevents premature deallocation of background work such as:
    /// - WebSocket streams
    /// - network requests
    /// - long-running async operations
    private var tasks: [Task<Void, Never>] = []

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
    func send(_ action: R.Action) {

        Task {

            /// Local mutable copy passed into reducer for deterministic updates
            var currentState = self.state

            /// Run reducer logic (may modify state + return effect)
            let effect = await reducer.reduce(
                state: &currentState,
                action: action
            )

            /// Commit state update after reducer completes
            self.state = currentState

            /// Execute any side effects returned by reducer
            handle(effect)
        }
    }

    // MARK: - Effect Handling

    /// Handles side effects produced by the reducer.
    ///
    /// Effects can:
    /// - Do nothing (`.none`)
    /// - Run a single async operation (`.run`)
    /// - Produce a stream of actions (`.stream`)
    ///
    /// - Parameter effect: The effect to execute.
    private func handle(_ effect: Effect<R.Action>) {

        switch effect {

        case .none:
            return

        case .run(let operation):

            /// Executes a single asynchronous operation that may emit an action.
            let task = Task {

                if let action = await operation() {
                    await MainActor.run {
                        self.send(action)
                    }
                }
            }

            tasks.append(task)

        case .stream(let operation):

            /// Executes a continuous stream of actions (e.g. WebSocket updates).
            let task = Task {

                let stream = operation()

                for await action in stream {
                    await MainActor.run {
                        self.send(action)
                    }
                }
            }

            tasks.append(task)
        }
    }
}
