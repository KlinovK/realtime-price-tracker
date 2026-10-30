//
//  FavoritesRepository.swift
//  RealTimePriceTracker
//

import Foundation

nonisolated protocol FavoritesRepositoryProtocol: Sendable {
    func loadIDs() async -> Set<String>
    func saveIDs(_ ids: Set<String>) async
}

/// Read-once adapter for favorites written by versions predating SwiftData.
///
/// `AppReducer` imports these IDs into `FavoriteRecord` and clears the legacy key
/// after a successful transaction. It is never an ongoing application data source.
actor FavoritesRepository: FavoritesRepositoryProtocol {
    private let defaults: UserDefaults
    private let key: String

    init(
        defaults: UserDefaults = .standard,
        key: String = "favoriteCoinGeckoIDs"
    ) {
        self.defaults = defaults
        self.key = key
    }

    func loadIDs() async -> Set<String> {
        Set(defaults.stringArray(forKey: key) ?? [])
    }

    func saveIDs(_ ids: Set<String>) async {
        defaults.set(ids.sorted(), forKey: key)
    }
}
