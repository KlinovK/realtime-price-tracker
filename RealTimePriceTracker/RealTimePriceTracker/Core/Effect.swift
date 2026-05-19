//
//  Effect.swift
//  RealTimePriceTracker
//
//  Created by Константин Клинов on 19/05/26.
//

import Foundation

enum Effect<Action> {

    case none

    case run(
        operation: () async -> Action?
    )

    case stream(
        operation: () -> AsyncStream<Action>
    )
}
