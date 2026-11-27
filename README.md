# CoinInsight

CoinInsight is the approved direction for this native iOS cryptocurrency project. The checked-out baseline is still the **Realtime Price Tracker** app and is not production-ready. It currently shows Favorites and CoinGecko Top 100; the approved three-tab portfolio product is planned.

## Current capabilities

- CoinGecko Top 100 snapshots, Favorites and seven-day CoinGecko chart points are persisted in SwiftData and remain viewable offline.
- Binance WebSocket prices update explicitly mapped Bitcoin, Ethereum and Solana favorites. Current Spot eligibility is not verified.
- SwiftUI, Swift Charts, Swift 6 actors and async/await, URLSession, a custom reducer/effect store and XCTest form the current stack.

The baseline has no holding or portfolio financial model, no Portfolio or AI Analysis tab, no official TCA dependency, and no validated production migration. `RealTimePriceTrackerApp.swift` currently terminates if its three-model SwiftData container cannot initialize.

## Approved target

V1 targets Portfolio (default), Markets and a **static offline Demo Mode** AI Analysis tab, with shared Details. Portfolio will support manual holdings, honest USDT valuation and unrealized P&L, allocation, actual history, offline edits and recoverable storage failure. Markets will show only verified CoinGecko Top 100 assets with active Binance Spot USDT instruments. These features are **NOT STARTED**.

Read the [product requirements](docs/product.md) for behavior, [architecture](ARCHITECTURE.md) for technical contracts, [roadmap](docs/roadmap.md) for delivery, [engineering workflow](docs/ai-workflow.md) for process and [AGENTS.md](AGENTS.md) for agent instructions.

## Build and run

Prerequisites: compatible Xcode with Swift 6 and iOS 26.2 support, plus a suitable simulator or device. The checked-in project and shared scheme remain named `RealTimePriceTracker`; the repository, app target and Bundle Identifier have not been renamed. Open the project, choose the `RealTimePriceTracker` scheme and run:

```bash
open RealTimePriceTracker/RealTimePriceTracker.xcodeproj
```

The current sample setup uses keyless CoinGecko access. Production provider access, quotas, terms and territories remain unvalidated. Do not embed credentials in the app.

## Testing and CI

The baseline contains an XCTest unit-test target and a UI-test target without implemented UI automation. The checked-in [CI workflow](.github/workflows/ci.yml) uses Xcode 26.6 on macOS 26 with an iPhone 17 Pro simulator running iOS 26.5. Earlier CI results are historical evidence only. **No application tests or CI were run for this documentation task.**

To run the shared scheme in a matching local environment:

```bash
xcodebuild test \
  -project RealTimePriceTracker/RealTimePriceTracker.xcodeproj \
  -scheme RealTimePriceTracker \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath /private/tmp/rpt-stabilization-derived \
  -parallel-testing-enabled NO \
  -quiet \
  CODE_SIGNING_ALLOWED=NO
```

## Status and limits

PLAN-8 documentation implementation awaits separate review and authorized integration. M00–M27 are not started. Current icon bytes are not guaranteed offline; production mapping, provider access, financial migration/recovery, UI/device verification and release readiness are open. No App Store availability is claimed.

Existing [Top 100](docs/screenshots/top-assets.png) and [Favorites](docs/screenshots/favorites.png) screenshots depict the legacy app. The project is licensed under the [MIT License](LICENSE).
