//
//  RealTimePriceTrackerApp.swift
//  RealTimePriceTracker
//
//  Created by Kanstantin Klinau on 19/05/26.
//

import SwiftUI
/// The main entry point for the Real Time Price Tracker application.
///
/// `RealTimePriceTrackerApp` is responsible for:
/// - Launching the application
/// - Creating the primary app window
/// - Injecting the root view into the SwiftUI scene hierarchy
///
/// SwiftUI automatically initializes this type when the app starts.
@main
struct RealTimePriceTrackerApp: App {

    // MARK: - Body

    /// Defines the main scene displayed by the application.
    ///
    /// `WindowGroup` manages one or more app windows depending on the
    /// platform capabilities (iPhone, iPad, macOS).
    var body: some Scene {
        WindowGroup {
            makeRootView()
        }
    }

    // MARK: - View Builders

    /// Creates the application's root view.
    ///
    /// Extracting the root view creation into a dedicated method improves:
    /// - Readability
    /// - Maintainability
    /// - Future dependency injection support
    ///
    /// - Returns: The root view displayed when the app launches.
    @ViewBuilder
    func makeRootView() -> some View {
        RootView()
    }
}
