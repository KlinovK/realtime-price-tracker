# CoinInsight architecture

This document owns technical contracts. [Product](docs/product.md) owns user behavior, [roadmap](docs/roadmap.md) milestones/gates, and [workflow](docs/ai-workflow.md) process. The approved target is not the current implementation.

## Current architecture

The baseline app composes SwiftData, a custom Store<AppReducer>, CoinGecko and Binance services in the app entry point. RootView presents Favorites and Top 100 tabs. AssetRecord, FavoriteRecord and PricePointRecord are queried by SwiftUI; reducers own transient control state. A ModelActor repository commits CoinGecko snapshots, favorite changes, chart replacements and coalesced favorite Binance quotes before success publication. Explicit pair mappings cover Bitcoin, Ethereum and Solana. Source: RealTimePriceTracker/RealTimePriceTracker/AppLayer, CoreLayer/Persistence, DomainLayer/BinancePairRegistry.swift and FeatureLayer. There is no holding/financial calculator, versioned financial schema, official TCA or local SPM graph. Store initialization currently traps on failure.

## Target architecture and SA decisions

Incrementally adopt a released, pinned official TCA version after SP-01 and prove balanced local SPM boundaries under SP-02. Candidate boundaries: Domain, DesignSystem, ApplicationServices, Networking, Persistence, MarketsFeature, AssetDetailsFeature, PortfolioFeature, AIAnalysisFeature and AppFeature. They are not final. Use a pure immutable Sendable Domain, one composition root, explicit infrastructure injection, feature dependencies, one-way imports and no service locator or cycles. Keep provider DTOs and SwiftData models out of feature state/actor crossings.

- **SA-01:** SA-01 TCA — Repository: custom Store/Reducer/Effect. Proposal: replace incrementally; keep existing behavior tests until official TCA TestStore equivalents cover them.
- **SA-02:** SA-02 SPM — Repository: primarily app/test Xcode targets. Proposal: balanced local targets with one-way imports; run a compile experiment before splitting files.
- **SA-03:** SA-03 DI — Repository: concrete services built at app entry and protocol-injected into reducers. Proposal: TCA Dependencies at effect edges; constructor injection inside services; one composition root.
- **SA-04:** SA-04 Domain — Repository: persisted Decimal fields, no complete Portfolio calculator. Proposal: validated values and pure calculation with explicit time/policy.
- **SA-05:** SA-05 Persistence separation — Repository: AssetRecord combines CoinGecko snapshot and Binance quote. Proposal: distinct records/ownership for identity, listing, pair, quote, stats, holding, historical prices, snapshots, sync metadata. No separately mutable derived totals.
- **SA-06:** SA-06 Reset/migration — Repository: existing unversioned model-container construction. Proposal: authorized one-time retirement of Favorites and recoverable cache, then versioned schema; never reset failed production financial data.
- **SA-07:** SA-07 Adapters — Repository: CoinGecko and Binance streaming clients exist. Proposal: capability-specific REST/WS adapters and internal DTOs, no implicit fallback.
- **SA-08:** SA-08 Mapping — Repository: explicit three-pair registry. Proposal: versioned mapping plus current exchangeInfo proof; fail closed for new crypto holding creation.
- **SA-09:** SA-09 Quote acceptance — Repository: generation checks and committed-quote evidence. Proposal: protected last accepted valid quote with REST revision capture; no cross-provider timestamp ordering or event ledger.
- **SA-10:** SA-10 Sync — Repository: feature timers/reconnect exist. Proposal: shared single-flight, deduplication, rate limiting, cooldown and lifecycle coordination.
- **SA-11:** SA-11 WS coordinator — Repository: stream is Favorites-oriented. Proposal: app-scoped union of foreground Portfolio and visible Details demands; no Markets-wide stream.
- **SA-12:** SA-12 History cache — Repository: one CoinGecko seven-day point cache. Proposal: Binance period-aware persistent cache, incremental fetch, deduplication, bounded recoverable retention.
- **SA-13:** SA-13 Calculation publication — Repository: no Portfolio calculator. Proposal: coherent committed input → one structured result; reject obsolete publications; reevaluate time-based freshness.
- **SA-14:** SA-14 Snapshots — Repository: no portfolio snapshots. Proposal: immutable quality-aware observations; holding change and corresponding snapshot in one successful write.
- **SA-15:** SA-15 Navigation — Repository: two tabs and separate SwiftUI navigation. Proposal: TCA-owned independent paths and actual visibility tracking for shared Details.
- **SA-16:** SA-16 Offline/recovery — Repository: cached markets/charts; no icon-byte cache or robust store-init recovery. Proposal: protected financial data, recoverable caches, explicit independent status dimensions.
- **SA-17:** SA-17 Concurrency — Repository: Swift 6 strict mode, actors, cancellation/generation tests. Proposal: explicit task/isolation contracts and deterministic reentrancy tests.
- **SA-18:** SA-18 Performance — Repository: quote batching exists. Proposal: granular observation, stable identity, bounded chart display, controlled live reordering; profile before optimization.
- **SA-19:** SA-19 Static AI — Repository: no AI feature. Proposal: independent local static feature with structured demo content; no provider protocol or async analysis infrastructure.
- **SA-20:** SA-20 Errors/observability — Repository: typed failures exist in some clients/reducers. Proposal: typed layer errors, contextual translation, privacy-safe OSLog/signposts/Instruments; no remote telemetry.

## Financial domain

DM-01–10 and RD-01–05 are specified in [product](docs/product.md#financial-and-domain-decisions). Implement validated Decimal values and a pure calculator with explicit time/policy, coherent immutable input, and structured result with valuation, completeness, freshness and exclusion reasons. Matching eligible sets govern totals, allocation and P&L denominator. Do not round intermediate financial values unnecessarily; Double is only for chart rendering. Final Decimal bounds and rounding require evidence and owner approval.

## Persistence and transition

Target logical records separate asset identity, listing, pair, quote provenance, statistics, holding, historical prices, snapshot and synchronization metadata. SwiftData remains UI-facing truth; a ModelActor owns writes and coherent reads; cross-actor data are Sendable values. A holding mutation and its corresponding quality-aware snapshot commit together or neither commits. Roll back failure, report success only after commit, and distinguish cancellation before and after commit. No network suspension inside a financial transaction. M14 adds cadence/history without deferring M12 mutation snapshots.

M04 builds the versioned schema, transition mechanism, file-backed fixtures and recovery path. M05–M15 migrate working features incrementally; M16 verifies cutover readiness; M17 verifies post-transition recovery. Destructive legacy retirement needs separate explicit authorization. Never automatically reset the new financial store. Storage topology and transaction mechanism remain feasibility-dependent under SP-03–05/TG-03–05/TG-09.

## Providers and eligibility

CoinGecko owns rank/identity; Binance owns verified active Spot USDT instruments, quotes, statistics, history and needed foreground streams. Use versioned explicit CoinGecko-to-Binance mapping plus current exchangeInfo evidence; ticker similarity is insufficient. Verify online eligibility before new non-USDT creation and revalidate mapping evidence at write. Existing holdings survive Top 100 exit and delisting; a network failure is not delisting. Keyless-first provider feasibility includes technical, commercial, territorial, attribution, redistribution and operational checks. Provider access is not yet validated; failure reopens the owner decision without silently adding a backend or fallback.

## REST/WebSocket ordering and lifecycle

Use shared single-flight work, deduplication, bounded retry/cooldown and provider rate limits. Capture request/connection generations plus independent mapping and quote-observation revisions. DAT-05 requires a deterministic race: REST starts under mapping A; B commits during flight; no newer quote is accepted; A returns and is rejected solely for obsolete mapping evidence. The committed quote remains unchanged, with no accepted-update publication. Also reject REST after a newer accepted quote, obsolete WebSocket generations and failed commits while retaining the last trustworthy price. Do not assume universal exchange timestamp ordering or detection of every same-stream anomaly.

Foreground socket demand is the union of eligible Portfolio holdings and visible Details. Markets uses REST, nominal USDT has no socket, and background work is suspended. A quote appears live only after its matching persistence commit.

## Performance, reliability and privacy

Use stable identity, granular observation, bounded chart points and work, batched writes, persistent market history/image bytes, adaptive eviction only for recoverable caches, typed errors and privacy-safe OSLog/signposts. Protect financial records and last trustworthy prices. Profile launch, store, calculator, memory, energy, streaming and chart behavior on physical devices. All numeric budgets in [roadmap](docs/roadmap.md#provisional-parameters) are provisional.

## Supplementary AD-01–06 decisions

**AD-01.** Keyless-first provider access: validate endpoints, authentication, rate limits, commercial terms, territories, attribution, redistribution and operations. No embedded production secrets. Failure reopens access decision without automatically choosing a backend, other provider or smaller scope.

**AD-02.** One-time destructive legacy retirement only for unambiguously identified legacy data and only after separate authorization. Versioned new financial schema; never automatically reset the new financial store.

**AD-03.** Evidence-based eligibility: network failure is not delisting; missing metadata requires reverification; explicit eligibility/pair states; confirmed delisting requires evidence.

**AD-04.** Maximum verified coverage: evaluate all CoinGecko Top 100 assets and include every confidently mapped active Binance Spot USDT asset. No fixed minimum and no unsafe ticker-only identity match.

**AD-05.** Adaptive retention: recoverable market history may be evicted adaptively; last trustworthy prices and user financial data are protected; portfolio history has unlimited target retention. Generic cache eviction never deletes protected records.

**AD-06.** Controlled Decimal domain: bounds and rounding require technical validation and owner approval before they constrain production input. Candidates are not approved limits.
