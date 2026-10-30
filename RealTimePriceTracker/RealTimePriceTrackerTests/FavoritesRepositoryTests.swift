import Foundation
import XCTest
@testable import RealTimePriceTracker

final class FavoritesRepositoryTests: XCTestCase {
    func test_repositoryPersistsStableCoinGeckoIDs() async throws {
        let suiteName = "FavoritesRepositoryTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let repository = FavoritesRepository(
            defaults: defaults,
            key: "favorites"
        )

        await repository.saveIDs(["ethereum", "bitcoin"])
        let restoredIDs = await repository.loadIDs()

        XCTAssertEqual(restoredIDs, ["bitcoin", "ethereum"])
        UserDefaults(suiteName: suiteName)?
            .removePersistentDomain(forName: suiteName)
    }
}
