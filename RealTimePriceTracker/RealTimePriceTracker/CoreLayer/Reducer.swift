//
//  Reducer.swift
//  RealTimePriceTracker
//
//  Created by Константин Клинов on 19/05/26.
//

import Foundation

protocol ReducerProtocol {

    associatedtype State
    associatedtype Action

    func reduce(
        state: inout State,
        action: Action
    ) async -> Effect<Action>
}
