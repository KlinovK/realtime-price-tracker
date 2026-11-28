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

The canonical toolchain is Xcode 27.2 (build 27B52), Apple Swift 6.4.2, and the iOS 27.2 build SDK. The app retains its iOS 26.2 minimum deployment target, Swift 6 language mode, and complete strict concurrency. Use the iPhone 18 Pro simulator on iOS 27.2 for the shared tests. The checked-in project and shared scheme remain named `RealTimePriceTracker`; the repository, app target and Bundle Identifier have not been renamed. Open the project, choose the `RealTimePriceTracker` scheme and run:

```bash
open RealTimePriceTracker/RealTimePriceTracker.xcodeproj
```

The current sample setup uses keyless CoinGecko access. Production provider access, quotas, terms and territories remain unvalidated. Do not embed credentials in the app.

## Testing and CI

Run `bash scripts/swift-quality.sh check` before building. The script downloads exact SwiftLint 0.65.1 and SwiftFormat 0.64.7 release binaries into a temporary directory, verifies their SHA-256 hashes and versions, then checks project-owned Swift without changing tracked files. It requires `curl`, `unzip`, and `shasum`; no global installation is needed. Run `bash scripts/swift-quality.sh format` to apply the narrowly configured whitespace rules, then run `check` again. CI runs the same check. Upgrade either tool only through a reviewed version, hash, configuration, local and CI verification change. The warning and concurrency-exception policy is in [the engineering workflow](docs/ai-workflow.md#swift-quality-policy).

The baseline contains an XCTest unit-test target and a UI-test target without implemented UI automation. The checked-in [CI workflow](.github/workflows/ci.yml) selects Xcode 27.2 on the `xcode-27` runner and tests on iPhone 18 Pro with iOS 27.2. Check the current PR and post-merge CI runs for applicable verification evidence.

Select the canonical Xcode for these commands without changing the system-wide selection. Keep the checked-in `Package.resolved` unchanged; `-onlyUsePackageVersionsFromResolvedFile` prevents automatic selection of different package versions. Use task-specific paths outside the checkout for derived data and result bundles:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -version
xcrun swift --version
xcodebuild -showsdks
xcodebuild build \
  -project RealTimePriceTracker/RealTimePriceTracker.xcodeproj \
  -scheme RealTimePriceTracker \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -onlyUsePackageVersionsFromResolvedFile \
  -derivedDataPath /private/tmp/coininsight-build-derived \
  -quiet \
  CODE_SIGNING_ALLOWED=NO
```

Set `DEVELOPER_DIR` to the installed Xcode 27.2 developer directory if it is elsewhere. Run the shared scheme with the same Xcode:

```bash
xcodebuild test \
  -project RealTimePriceTracker/RealTimePriceTracker.xcodeproj \
  -scheme RealTimePriceTracker \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.2' \
  -onlyUsePackageVersionsFromResolvedFile \
  -enableCodeCoverage YES \
  -derivedDataPath /private/tmp/coininsight-test-derived \
  -resultBundlePath /private/tmp/coininsight-tests.xcresult \
  -parallel-testing-enabled NO \
  -quiet \
  CODE_SIGNING_ALLOWED=NO
python3 scripts/coverage-report.py \
  --xcresult /private/tmp/coininsight-tests.xcresult \
  --json-out /private/tmp/coininsight-coverage.json \
  --markdown-out /private/tmp/coininsight-coverage.md
```

The coverage command reports production executable lines by file and current component. Its scope, measured baseline and threshold policy are in [the engineering workflow](docs/ai-workflow.md#coverage-measurement).

Upgrade the canonical Xcode, SDK, or simulator only through a reviewed change that verifies the new versions, preserves the deployment target and resolved dependencies, and passes local, PR, and post-merge tests.

## Status and limits

Foundational CoinInsight documentation is established under the owner-approved ED-01-R1 integration workflow. M00–M27 are not started. Current icon bytes are not guaranteed offline; production mapping, provider access, financial migration/recovery, UI/device verification and release readiness are open. No App Store availability is claimed.

Existing [Top 100](docs/screenshots/top-assets.png) and [Favorites](docs/screenshots/favorites.png) screenshots depict the legacy app. The project is licensed under the [MIT License](LICENSE).
