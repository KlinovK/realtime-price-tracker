# CoinInsight engineering workflow

This document owns process, risk, quality and the approved reconstructed Definition of Done. [Product](product.md) owns behavior, [architecture](../ARCHITECTURE.md) technical invariants and [roadmap](roadmap.md) sequencing/gates. Approval PLAN-8-R1.5 prospectively adopted the reconstructed DoD and statuses; their original historical wording is unavailable.

## Roles

- **Owner:** product decisions, scope and restricted-action authorization, human integration/release decisions.
- **ChatGPT:** architecture and technical leadership, planning, critical review and engineering mentorship.
- **Codex:** scoped repository inspection and authorized implementation with actual evidence.
- **Independent reviewer:** separate critical verification when policy or task requires it. AI review is not a human GitHub approval.

## PLAN → BUILD → REVIEW & SHIP

1. **PLAN:** inspect baseline, branch/status, source and applicable decisions; define objective, authorized scope, risk, acceptance, constraints and verification. Resolve material contradictions through the owner rather than inventing decisions.
2. **BUILD:** use a worktree when needed to protect user changes or isolate risky work, make only scoped changes, and record source/test evidence. Keep network work outside atomic financial transactions.
3. **REVIEW & SHIP:** inspect complete diff and acceptance, run applicable deterministic checks, obtain required separate review, present actual results and limitations, integrate within the approved task's risk-based Git scope, and verify after merge when applicable. Unexecuted verification is never PASS.

Classify risk by the highest-risk affected behavior. Financial arithmetic, identity mapping, data integrity, destructive migration, persistence atomicity, concurrency/ordering, security/privacy and release operations are high risk. Medium-risk bounded behavior and high-risk changes require separate review; high-risk architecture choices need developer approval and targeted failure/race evidence. Low-risk documentation still needs authorized scope, traceable evidence and diff review.

## Engineering quality EQ-01–12

- **EQ-01:** EQ-01 Modern iOS First — App and packages. Build/test minimum iOS 26.2 and latest stable supported OS with released, pinned TCA; record Xcode/Swift versions, simulator and physical-device results.
- **EQ-02:** EQ-02 Maximum Strictness — Project-owned Swift. Enforce explicit warning policy, pinned lint/format, static analysis, boundaries and reviewed exceptions; record clean build/tool reports and exception list.
- **EQ-03:** EQ-03 High-assurance Testing — Domain, features, services, storage, network, UI, performance. Maintain deterministic fixtures/clocks, file-based migration, fault/race tests, selective advanced tests; retain reproducible artifacts.
- **EQ-04:** EQ-04 Risk-based Coverage — Project-owned executable code. Measure per module and overall; enforce approved thresholds progressively, document exclusions and critical-scenario evidence.
- **EQ-05:** EQ-05 High-assurance CI — L1–L5. Record build/test/lint/coverage/architecture/security/UI artifacts and human approvals at the appropriate level; verify post-merge.
- **EQ-06:** EQ-06 Performance-first — Startup, render, calculator, store, memory, energy, stream and chart. Instrument realistic device workloads and report distributions/regressions.
- **EQ-07:** EQ-07 Privacy-first Security — Local financial data, provider access, app package, CI. Threat model, file protection/backup and ATS checks, secret/dependency scan, privacy review; retain signed reports.
- **EQ-08:** EQ-08 Basic Accessibility — Primary flows and charts. Manual VoiceOver, Dynamic Type, Reduce Motion, appearance, color-independent status, basic Voice/Switch Control checks on device; record findings.
- **EQ-09:** EQ-09 English First — User-facing and accessibility strings, formatting, package resources. Audit String Catalog extraction and locale parsing/formatting; test English and a non-English numeric/date locale.
- **EQ-10:** EQ-10 Production Reliability — Foreground/background, unstable network, repeated mutations/charts, storage integrity. Execute bounded physical-device sessions and issue a reliability report.
- **EQ-11:** EQ-11 Controlled Release — Feature Complete → Stabilization → Release Candidate → TestFlight → App Store. Record approved gates, beta feedback, compliance review, and human release authorization.
- **EQ-12:** EQ-12 Definition of Done — Every task, feature, milestone and release. Use applicable acceptance, diff, tests, coverage, review, documentation, learning review, authorization, and post-merge evidence.

Use Swift 6 strict concurrency; validate and pin released dependencies/tools. Prefer deterministic offline CI, injected clocks and controlled interleavings over sleeps. Test Domain, reducers, services, provider fixtures, file-backed persistence/migration, property/edge cases, UI/device behavior, fault injection and performance according to risk. Record build/lint/static-analysis, security/privacy, accessibility and locale evidence when applicable.

### Swift quality policy

Project-owned app, unit-test and UI-test targets use `SWIFT_TREAT_WARNINGS_AS_ERRORS = YES` in Debug and Release. This target-level setting does not impose a command-line override on third-party packages. Swift 6 language mode, complete strict concurrency and existing actor isolation remain in force. Do not suppress compiler diagnostics to pass a build; review any new warning and its cause. SwiftLint and SwiftFormat versions, hashes, rules and the shared local/CI command are in `scripts/swift-quality.sh`, `.swiftlint.yml` and `.swiftformat`. Lint rules focus on unsafe casts/tries, duplicate imports, identical operands, invalid lint directives and trailing whitespace. Formatting changes only trailing whitespace and consecutive blank lines. CI checks without rewriting source. Review rule/tool upgrades with local and CI evidence.

The existing `@unchecked Sendable` inventory is test-only. Each class has mutable state, so checked conformance is not currently available. Retain these exceptions while their stated lock discipline holds; review on every relevant edit or toolchain change. No `@preconcurrency`, `nonisolated(unsafe)` or SwiftLint/SwiftFormat diagnostic-suppression directives were found in project-owned Swift at M00-02.

| File / type | Mutable state and synchronization | Safety evidence, residual risk and disposition |
| --- | --- | --- |
| `LivePricesSyncServiceTests.swift` / `RecordingMarketsService` | Recorded calls are protected by `NSLock`. | Call capture is synchronized and exercised by streaming tests. Retain; future mutable fields must share the lock. |
| `OfflineFirstTestDoubles.swift` / `MockLivePricesSyncService` | Subscription history and `AsyncStream` continuation are protected by `NSLock`; event emission uses a continuation copied under the lock. | Existing live-price tests exercise cross-task delivery. Retain; preserve the lock when changing continuation ownership. |
| `OfflineFirstTestDoubles.swift` / `MockLegacyFavoritesRepository` | Favorite ID set is protected by `NSLock`. | Repository tests exercise load/save through the synchronized methods. Retain; keep all state access locked. |
| `StoreCancellationTests.swift` / `TerminationRecorder` | Counter is protected by `NSLock`. | Cancellation tests assert the recorded count. Retain; the synchronization contract is small and explicit. |
| `MarketsServiceTests.swift` / `ManualClock` | Current instant, sleepers and cancellation IDs are protected by `NSLock`; continuations are resumed outside the lock. | Deterministic clock/cancellation tests cover the intended interleavings. Retain; cancellation after a completed sleep can leave an unused ID in this test helper, so avoid long-lived reuse and review if expanded. |

### M00-03 analysis and architecture assessment

The canonical Debug `xcodebuild analyze` action was run with the shared scheme, generic iOS Simulator destination, `-onlyUsePackageVersionsFromResolvedFile`, and isolated derived data/result bundle. It succeeded in about 11 seconds of Xcode execution. The log showed Swift compilation of the app target and resolved packages, no distinct Clang analyzer action on project-owned source, and no actionable source finding. Its sole warning was that App Intents metadata extraction was skipped because the app does not depend on App Intents. The scheme's Analyze action builds the app; it does not analyze the unit/UI-test targets or execute tests. The result bundle contains no test results. Xcode Analyze is retained as an optional investigation command, not a routine CI gate: in this Swift-only baseline it adds no demonstrated diagnostic coverage beyond the existing warnings-as-errors build and lint checks. Reassess when C/Objective-C or other analyzer-eligible code appears.

The current project has one production app target, two test targets that depend on the app, and a locked `Algorithms` package product. No project-owned production file imports XCTest or test infrastructure. Existing target dependencies, Swift compiler diagnostics, pinned lint rules and package-resolution checks cover the present concrete boundaries. There is no local SPM feature graph yet. Do not enforce the proposed Domain/feature/service import direction against directories within the monolithic app. After M02 creates real modules, verify dependency direction, forbidden imports, cycles and test-only dependencies against the approved graph; first prove those checks reject an invalid fixture. No new architecture CI rule was justified at M00-03, so there is no new invalid-case fixture for this task.

Sanitizer and mutation status is **feasibility only**. Xcode 27.2 exposes `-enableThreadSanitizer YES` and `-enableAddressSanitizer YES`; neither was run or made a gate here. Thread Sanitizer is limited to an iOS simulator for this app, targets runtime data races, and has substantial execution overhead; use focused concurrency/race tests after M02 and when relevant persistence or quote ordering work exists. Address Sanitizer can be tried on the existing test scheme for memory errors, but its value for this Swift-heavy baseline and CI cost remain unmeasured. Mutation testing has no pinned tool or established score method; assess it after executable Domain/reducer modules and meaningful coverage exist, without adopting the roadmap's provisional score as a gate. The `ManualClock` unused cancellation-ID case recorded above is deferred test-infrastructure debt, not a production defect; its lock discipline remains intact. QG-05 stays OPEN pending later architecture/static-analysis evidence and the separate coverage/sanitizer/mutation classifications.

### Coverage measurement

Run the shared scheme once with `-enableCodeCoverage YES` and a fresh `-resultBundlePath`, then run `python3 scripts/coverage-report.py --xcresult <bundle> --json-out <report.json> --markdown-out <report.md>` from the repository root. The [README](../README.md#testing-and-ci) gives the complete canonical command. CI uses the same extraction script on its existing test bundle and publishes both reports and the original Xcode result bundle. Python 3 is already present locally and on the runner; the script uses only the standard library and Xcode's `xccov`.

The numerator and denominator are `xccov` covered and executable line counts for `RealTimePriceTracker.app`; overall and current directory-component percentages are calculated from summed counts, never averaged file percentages. All reported project-owned production Swift files, including UI, remain in the denominator. The unit-test target, the third-party `Algorithms` package target, build products and generated artifacts are outside that production target. There are no additional coverage-percentage exclusions. Reports include each production file, current components, zero-covered files and zero-executable-line files; a zero-executable-line component is shown as N/A and cannot satisfy an active threshold. The script rejects invalid counts/ratios, missing target or file data, unexpected source paths and changes to the reviewed unreported-file inventory.

Local Xcode 27.2 / iPhone 18 Pro iOS 27.2 baseline on 2026-11-28: **77 passed, 0 failed, 0 skipped; 2,573 / 4,485 production executable lines covered (57.37%)**. The test target's 2,966 / 3,071 lines and `Algorithms` 0 / 0 are excluded. Current components are directory groupings within one app target, not SPM modules:

| Current component | Covered / executable | Line coverage |
| --- | ---: | ---: |
| AppLayer | 263 / 339 | 77.58% |
| CoreLayer/Networking | 816 / 878 | 92.94% |
| CoreLayer/Other | 181 / 188 | 96.28% |
| CoreLayer/Persistence | 481 / 554 | 86.82% |
| DesignSystem | 18 / 166 | 10.84% |
| DomainLayer | 37 / 50 | 74.00% |
| FeatureLayer/AssetDetailsFeature | 52 / 586 | 8.87% |
| FeatureLayer/MarketFeature | 572 / 1,057 | 54.12% |
| FeatureLayer/TopAssetsFeature | 153 / 667 | 22.94% |

The largest measured gaps are `AssetDetailsView.swift` (0/519), `TopAssetsView.swift` (0/336), `MarketsView.swift` (147/345), `TopAssetRow.swift` (0/117), `FavoriteAssetCell.swift` (0/111) and `GlassCard.swift` (0/107). These are coverage gaps, not exclusions. Ten project-owned source files have **no xccov file entry**: `AppLayer/AppAction.swift`, `CoreLayer/Networking/WebSocket/StreamConfiguration.swift`, `CoreLayer/Reducer.swift`, `DesignSystem/Themes/ThemeBackground.swift`, `DomainLayer/BinanceSocketResponse.swift`, `DomainLayer/BinanceTicker24h.swift`, `DomainLayer/BinanceTickerResponse.swift`, `FeatureLayer/AssetDetailsFeature/AssetDetailsAction.swift`, `FeatureLayer/MarketFeature/MarketsAction.swift` and `FeatureLayer/TopAssetsFeature/TopAssetsAction.swift`. They contain declarations or configuration with no reported executable lines in this result; the report does not claim they have zero source code or proven zero executable behavior. Their exact inventory is reviewed in the script and any change fails extraction until inspected. Reassess this inventory on source or toolchain changes.

The script accepts an optional JSON threshold file, for example `{"overall": 85, "components": {"CoreLayer/Networking": 90}}`, via `--thresholds`. It fails if a required component is absent or has zero executable lines, or if a measured count is below its floor; equality passes. Controlled disposable fixtures verify passing, equality, below-floor, missing and invalid data, zero-line behavior and line-count-weighted aggregation. **No percentage floor is active in CI yet.** Initially, CI should block only failed extraction, malformed or missing production coverage data and changed unreported-file inventory; report the measured percentages without blocking on them. The owner must approve any initial numerical floor after reviewing the baseline and expected coverage changes. Activate the approved target thresholds below progressively when the corresponding executable modules exist; reassess the current directory groupings at M02. QG-02 remains OPEN pending progressive approved threshold activation and regression evidence for the eventual modules.

### Coverage targets

- **Financial Domain, Financial Arithmetic, Portfolio Calculator:** 100% each
- **Persistence, Feature Reducers:** >=95% each
- **ApplicationServices, Networking, AppFeature:** >=90% each
- **AIAnalysisFeature:** >=85%
- **DesignSystem:** Selective meaningful coverage
- **Overall project-owned executable code:** >=85%

These thresholds activate progressively with executable modules and approved enforcement. Mutation score and numeric performance budgets are provisional; do not activate them from a planning value alone. CI levels: L1 local, L2 PR, L3 post-merge, L4 scheduled extended and L5 release. Historical CI results are not new test evidence.

## Definition of Done — DOD-01–17

The register below is the approved reconstructed replacement, not recovered original wording. Apply each row's scope, verification, evidence, pass/failure and justified N/A rule. DOD-01 and DOD-14 are never N/A.

| ID | Obligation | Applicability | Required verification | Required evidence | Pass condition | Failure handling | Justified N/A |
| --- | --- | --- | --- | --- | --- | --- | --- |
| DOD-01 | Authorized scope | Every task, including implementation, documentation, read-only audit, architecture analysis, feasibility work, review and repository inspection | Compare objective, permitted scope, constraints and restricted-action authorizations with actual work | Scope/authorization record and actual action list | Only authorized work within permitted scope; no unauthorized expansion | Stop, report deviation and obtain explicit authorization before restricted action | Never N/A |
| DOD-02 | Acceptance criteria | Every deliverable | Map output to explicit criteria | Acceptance matrix | All applicable criteria met | Mark partial and remediate | N/A only when task has no deliverable |
| DOD-03 | No unrelated changes | Every mutation task | Inspect changed-file list and diff | Diff/stat | Only approved scope changed | Revert own unrelated edit safely | N/A for no file changes |
| DOD-04 | Architecture compliance | Architecture-affecting work | Review dependency direction/invariants | Diagram/diff/review | Applicable invariants hold | Reopen design/review | N/A for unrelated prose |
| DOD-05 | Swift engineering quality | Swift changes | Build/lint/format and inspect diagnostics | Commands/logs | Applicable policies pass | Fix or record blocker | N/A without Swift changes |
| DOD-06 | Concurrency correctness | Concurrent behavior changes | Deterministic race/cancellation tests | Interleaving results | No stale publication/data race | Fix and retest | N/A without concurrency impact |
| DOD-07 | Applicable tests | Behavior changes | Run relevant tests and shared gate when feasible | Exact commands/results | Required executed tests pass | Report unrun/failure; fix | N/A for docs-only absent behavior risk |
| DOD-08 | Applicable coverage | Executable modules under active threshold | Generate module/overall report | Coverage artifact | Active approved threshold met | Fix gap or obtain exception | N/A before module/threshold activation |
| DOD-09 | Financial correctness | Financial logic/data changes | Invariant and edge/property tests | Exact-value cases | Invariants hold | Block integration | N/A outside financial scope |
| DOD-10 | Security and privacy | Data/network/release changes | Threat/privacy review and applicable checks | Review/check output | No unresolved material exposure | Block/restrict release | N/A only with reasoned no-impact |
| DOD-11 | Regression verification | Changed behavior | Run affected existing tests | Command/result mapping | No relevant regression | Fix and rerun affected suite | N/A if no affected behavior |
| DOD-12 | Documentation consistency | Material behavior/policy changes | Compare authoritative docs | Doc diff/links | Docs match implemented or approved state | Correct before merge | N/A if no material doc impact |
| DOD-13 | Diff and repository integrity | Every file task | Check status, scope, diff and worktree | Git output | Unrelated state preserved | Stop/repair own changes | N/A only if no repository access |
| DOD-14 | Inspectable evidence | Every task | Record commands, results and source links | Report/artifacts | Claims trace to observed evidence | Downgrade claim | N/A never |
| DOD-15 | Limitations and risks | Every task | List unverified and remaining risk | Risk section | No material uncertainty hidden | Mark partial/block | N/A only when explicitly none |
| DOD-16 | Independent review | High risk or explicitly required task | Obtain separate reviewer findings | Review record | Blocking findings resolved | Remain pending | N/A only when policy/task does not require |
| DOD-17 | Engineering Learning Review | Significant implementation | Teach 1–3 actual concepts with verified source/tests | Review section | Relevant and accurate | Complete before Done | N/A for docs-only or insignificant change |

## Workflow statuses

Status ladder: PLANNED means identified but not execution-ready. READY means scope, prerequisites, acceptance criteria and required authorization established. IN PROGRESS means authorized execution started. IMPLEMENTED means changes completed but applicable verification remains. VERIFIED means applicable verification executed successfully; unexecuted checks are not PASS. REVIEWED means required separate review completed without blocking findings. READY TO MERGE means applicable integration prerequisites are satisfied and the approved task permits the merge; a separate owner approval is needed only for actions outside that scope. DONE means, for integration tasks, authorized integration plus successful applicable post-merge verification; for tasks without integration, all task-specific acceptance, verification and review obligations completed. BLOCKED means a concrete unresolved dependency, defect or missing authorization prevents progress; record the blocker and required resolution. These statuses are distinct; no planning/read-only task is forced through a Git merge, and implementation integration obligations are not weakened. DOD-01 is mandatory and never N/A; other N/A decisions require recorded justification. Original DOD-01–17 wording remains unrecovered; PLAN-8-R1.5 approved these replacement definitions and all nine workflow statuses.

## Git and integration policy (ED-01-R1)

The owner-approved ED-01-R1 Simplified Solo Developer Workflow supersedes ED-01's mandatory PR, branch-protection and separate routine Git-authorization requirements. Protect the original checkout and user changes; use a worktree when isolation is needed. Within an approved implementation task, commits and pushes are authorized after applicable verification. Low-risk changes may go directly to `main`; medium-risk changes use a branch and PR when scope or complexity warrants; high-risk changes require independent review, a PR and successful applicable CI before merge. Codex may merge a compliant PR within the approved task without a separate routine merge approval. Applicable tests, CI, architecture, security, privacy and acceptance checks remain mandatory. AI review is not human GitHub approval.

Branch protection and GitHub rulesets are optional, not integration prerequisites. QG-01 verifies the risk-based workflow and its evidence. External reports and multi-stage SHA-256 checks are used when risk or evidence needs justify them. Codex may remove its own temporary branch after verified integration when safe. Force pushes, history rewriting, bypassing failed checks and loss of user changes remain prohibited. Destructive data operations, security-policy changes, repository administration and App Store publication require explicit authorization. Financial correctness, concurrency safety, architecture, testing, security, privacy and engineering quality requirements remain unchanged. Explicit human authorization is still required where a task or release gate specifically calls for it.

## Engineering Learning Review

For significant implementation work, teach one to three actual concepts grounded in changed source and tests, with a short explanation and a developer exercise. Focus on senior iOS engineering, Swift/concurrency, architecture/testing and professional AI-assisted engineering. Keep this distinct from verification evidence. Do not restore the removed Python backend or separate AI Engineer education goals.

## Codex task protocol

A task brief identifies ID, effort, objective, authorized scope, risk, baseline, relevant decisions, exclusions, acceptance, verification commands, Git constraints, required evidence and stop conditions. Check whether approval already exists before asking again. Do not promote proposed parameters or untested mechanisms to approved production rules.

## Reporting protocol

Report baseline, authorized scope, actual changes, exact verification commands and results, acceptance matrix, remaining risks/limitations, repository integrity, correct workflow status and final verdict at a level suited to risk. Distinguish task-supplied approval from independently observed evidence and historical test results from newly executed tests. Do not fabricate pass results or independent sign-off.
