import Foundation
import XCTest
@testable import RealTimePriceTracker

private nonisolated struct CancellationState: Equatable {}

private enum CancellationAction {
    case start
    case stop
}

private final class TerminationRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    var count: Int {
        lock.withLock { value }
    }

    func record() {
        lock.withLock { value += 1 }
    }
}

@MainActor
private final class CancellationStreamFactory {
    let recorder: TerminationRecorder
    private(set) var createdCount = 0

    init(recorder: TerminationRecorder) {
        self.recorder = recorder
    }

    func makeStream() -> AsyncStream<CancellationAction> {
        createdCount += 1

        return AsyncStream { [recorder] continuation in
            continuation.onTermination = { _ in
                recorder.record()
            }
        }
    }
}

@MainActor
private struct CancellationReducer: ReducerProtocol {
    static let effectID = EffectCancellationID("test.stream")

    let factory: CancellationStreamFactory

    func reduce(
        state: inout CancellationState,
        action: CancellationAction
    ) -> Effect<CancellationAction> {
        switch action {
        case .start:
            return .stream(id: Self.effectID) { [factory] in
                factory.makeStream()
            }

        case .stop:
            return .cancel(id: Self.effectID)
        }
    }
}

@MainActor
final class StoreCancellationTests: XCTestCase {
    func test_sameIDReplacesExistingTask_andCancelStopsReplacement() async {
        let recorder = TerminationRecorder()
        let factory = CancellationStreamFactory(recorder: recorder)
        let store = Store(
            initialState: CancellationState(),
            reducer: CancellationReducer(factory: factory)
        )

        store.send(.start)
        await wait(until: { factory.createdCount == 1 })

        store.send(.start)
        await wait(until: {
            factory.createdCount == 2 && recorder.count == 1
        })

        store.send(.stop)
        await wait(until: { recorder.count == 2 })

        XCTAssertEqual(factory.createdCount, 2)
        XCTAssertEqual(recorder.count, 2)
    }

    private func wait(
        until condition: () -> Bool,
        attempts: Int = 100
    ) async {
        for _ in 0..<attempts {
            if condition() { return }
            await Task.yield()
        }
    }
}
