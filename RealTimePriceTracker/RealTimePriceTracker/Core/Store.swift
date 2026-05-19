//
//  Store.swift
//  RealTimePriceTracker
//
//  Created by Константин Клинов on 19/05/26.
//

import Foundation
import Combine

@MainActor
final class Store<R: ReducerProtocol>: ObservableObject {

    @Published
    private(set) var state: R.State

    private let reducer: R

    private var tasks: [Task<Void, Never>] = []

    init(
        initialState: R.State,
        reducer: R
    ) {
        self.state = initialState
        self.reducer = reducer
    }

    func send(_ action: R.Action) {
        Task {
            var currentState = self.state
            
            let effect = await reducer.reduce(state: &currentState, action: action)
            
            self.state = currentState
            
            handle(effect)
        }
    }

    private func handle(_ effect: Effect<R.Action>) {

        switch effect {

        case .none:
            break

        case .run(let operation):

            let task = Task {
                if let action = await operation() {
                    await MainActor.run {
                        self.send(action)
                    }
                }
            }

            tasks.append(task)

        case .stream(let operation):

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
