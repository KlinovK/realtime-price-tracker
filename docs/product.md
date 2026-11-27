# CoinInsight product requirements

This document owns approved V1 behavior and acceptance. The approved replacement context was adopted through PLAN-8-R1.5; the original Master v1.0 was not recovered verbatim. Requirements below are targets, not claims about the present app. [Architecture](../ARCHITECTURE.md) owns technical contracts, [roadmap](roadmap.md) delivery, and [workflow](ai-workflow.md) process.

## Vision and scope

P0: a genuinely useful, production-quality native iOS crypto portfolio application. P1: senior iOS engineering development. P1: professional AI-assisted software engineering. The removed Python backend and separate AI Engineer education goals do not return. Users manually track holdings, inspect supported markets and actual history, and need honest offline valuation. V1 has Portfolio (default), Markets, shared Details, and a static AI Analysis Demo Mode tab. Favorites is replaced; no Watchlist.

V1 excludes a transaction ledger, trading/automation, exchange or wallet integration, authentication, cloud sync, mandatory backend, real LLM/AI Chat, personalized advice, realized P&L, fees, candles, technical indicators and monetization. Demo Mode App Store suitability is unresolved.

## Product and functional decisions

- **PD-01:** Cryptocurrency price tracker.
- **PD-02:** Simple manual holdings; no ledger/exchange account.
- **PD-03:** Portfolio replaces Favorites; no Watchlist.
- **PD-04:** USDT primary; USD never silently equivalent.
- **PD-05:** CoinGecko identity/rank; Binance REST/WS roles.
- **PD-06:** Adaptive Portfolio/visible-Details streaming; Markets REST.
- **PD-07:** Interactive asset/portfolio charts; actual history.
- **PD-08:** Local offline data, cache, calculations and recovery.
- **PD-09:** Mock-first analysis. Dynamic analysis interpretation is SUPERSEDED by FD-08/UX-08/SA-19; static Demo Mode remains.
- **PD-10:** Native Custom Fintech, Light/Dark, accessibility.
- **PD-11:** Production verification, TestFlight, App Store.
- **FD-01:** Replaces the open Favorites-conversion question with a clean, empty Portfolio. MIG-01 now requires safe schema migration and cache preservation, with no converted or pending holdings.
- **FD-02:** Resolves the partial-total question: show partial valuation, unvalued holdings, and explicit completeness; show unavailable when none qualify. Allocation uses the same eligible set.
- **FD-03:** Approves last trustworthy cached price offline, per-asset freshness, observation time, and stale labeling. Exact thresholds remain open.
- **FD-04:** Defines the first-release unrealized P&L measures and Decimal calculation invariants. Acquisition price is USDT; unknown cost is not zero.
- **FD-05:** Limits Markets and new holdings to verified, active Binance Spot USDT assets in CoinGecko Top 100; unsupported assets are omitted from Markets. The three proposed edge-case domain rules remain unapproved.
- **FD-08:** Replaces dynamic mock portfolio analysis with an offline static Demo Mode report. Portfolio financial calculations remain real.

FD-06/07 are not defined. PD-09's dynamic interpretation is superseded by FD-08 and static AI-02. The old POR-09 deferral is superseded by the approved nominal-USDT rule.

## Functional requirements and acceptance

The 33 finalized PLAN-2 IDs plus reconstructed DAT-05 and OFF-02 are approved through PLAN-8-R1.5. All 35 target behaviors are NOT STARTED; legacy market/Favorites behavior is not completion. Each requirement below has its approved observable acceptance and verification. Functional UX-01 differs from UI/UX decision UX-01.

### MKT-01

**Definition:** Markets lists only the supported subset of CoinGecko Top 100, ordered by CoinGecko market-cap rank. It may show fewer than 100 assets. An asset appears only with verified CoinGecko↔Binance identity and an active Spot USDT pair.

**Acceptance:** After a committed ranking refresh, every visible Markets row belongs to verified Top 100∩active Spot USDT, retains stable identity/rank, and cached rows survive offline launch

**Verification:** fixture integration + offline UI. **Evidence:** ranking/mapping fixtures and UI result. **Milestones:** M05/M10. **Gates:** TG-06. **Checkpoints:** CP-02/03. **Implementation status:** NOT STARTED.

### MKT-02

**Definition:** Prices shown as USDT come from an eligible Binance USDT market. A missing price is unavailable; CoinGecko USD is never silently treated as USDT.

**Acceptance:** Every USDT price has Binance USDT provenance; unmapped or missing quotes show unavailable, never CoinGecko USD as USDT

**Verification:** currency/fixture tests + UI. **Evidence:** source/currency assertions and screenshot. **Milestones:** M05/M10. **Gates:** TG-06. **Checkpoints:** CP-03. **Implementation status:** NOT STARTED.

### MKT-03

**Definition:** Markets receives periodic Binance REST price updates. A failed refresh preserves the last trustworthy prices and marks affected assets stale or unavailable.

**Acceptance:** Periodic REST refresh commits before display; failure preserves last trustworthy quote and marks stale/unavailable per asset

**Verification:** clock-driven reducer + fault integration. **Evidence:** commit/error ordering log and assertions. **Milestones:** M06/M10. **Gates:** TG-07. **Checkpoints:** CP-03. **Implementation status:** NOT STARTED.

### MKT-04

**Definition:** Search filters supported assets already in Markets by understandable identity fields. Clearing search restores the ranked list; no unsupported asset appears through search.

**Acceptance:** Search by supported identity fields filters only loaded supported rows; clearing restores ranking and cannot reveal unsupported assets

**Verification:** reducer/UI search cases. **Evidence:** query/result assertions. **Milestones:** M10. **Gates:** QG-03. **Checkpoints:** CP-03. **Implementation status:** NOT STARTED.

### MKT-05

**Definition:** A manual refresh is available, shows progress, and does not erase cached rows on failure. It refreshes the target ranking/metadata and required REST prices under provider limits.

**Acceptance:** Manual refresh shows progress, deduplicates competing requests, retains cache on failure and respects provider cooldown

**Verification:** reducer/provider fault tests. **Evidence:** request counts, progress/error assertions. **Milestones:** M06/M10. **Gates:** TG-06. **Checkpoints:** CP-03. **Implementation status:** NOT STARTED.

### AST-01

**Definition:** Details show identified asset metadata, eligible USDT price, observation time, availability/freshness state, and applicable statistics with explicit units.

**Acceptance:** Details show matching identity, labeled USDT quote, observation time and available statistics; absent fields show unavailable

**Verification:** UI/fixture tests. **Evidence:** field/currency/state assertions. **Milestones:** M11. **Gates:** QG-03. **Checkpoints:** CP-03. **Implementation status:** NOT STARTED.

### AST-02

**Definition:** Active Details receive a required live WebSocket price; leaving Details or backgrounding removes its unnecessary subscription. A quote becomes live only after matching persistence commit.

**Acceptance:** Visible Details adds only needed foreground subscription; exit/background releases demand; live label follows committed matching quote

**Verification:** lifecycle/race tests. **Evidence:** subscription and commit-order assertions. **Milestones:** M07/M11. **Gates:** TG-07/08. **Checkpoints:** CP-03. **Implementation status:** NOT STARTED.

### AST-03

**Definition:** Details allow creating or editing a holding only for an eligible supported asset. Saving visibly succeeds only after the holding persists.

**Acceptance:** Eligible Details action opens correct add/edit flow; saved holding appears after commit/relaunch; failure retains draft

**Verification:** navigation + persistence UI. **Evidence:** saved/relaunch and failure assertions. **Milestones:** M11/M12/M16. **Gates:** TG-03. **Checkpoints:** CP-04. **Implementation status:** NOT STARTED.

### POR-01

**Definition:** Portfolio replaces Favorites. On the new version’s first launch, the portfolio is empty; old Favorites are not converted, shown as pending holdings, or used to invent quantities. There is no migration assistant or separate Watchlist.

**Acceptance:** Cold launch defaults to empty Portfolio with no converted Favorites or Watchlist; relaunch preserves any later holdings

**Verification:** migration fixture + UI. **Evidence:** empty-state and relaunch assertions. **Milestones:** M04/M12/M16. **Gates:** TG-09 stage M04. **Checkpoints:** CP-04. **Implementation status:** NOT STARTED.

### POR-02

**Definition:** A user adds, edits and removes one manual holding per asset with positive quantity and optional USDT-denominated acquisition price for non-USDT assets. New non-USDT creation requires successful current online CoinGecko Top 100 membership, explicit identity mapping and active Binance Spot USDT verification; cached eligibility is insufficient. Existing holdings can be edited or removed offline and committed Portfolio data remains accessible offline. Native USDT can be created offline. Verify eligibility before the atomic write and revalidate evidence and mapping revision before commit; no network request runs inside the transaction. A successful mutation atomically persists its snapshot and is reported only after commit.

**Acceptance:** Offline new non-USDT creation fails without current verification; online verified creation commits holding+snapshot; offline existing edit/delete and native USDT create commit and survive relaunch

**Verification:** eligibility race + file-backed mutation tests. **Evidence:** verification/revision, atomicity and relaunch assertions. **Milestones:** M05/M06/M12. **Gates:** TG-03/06/09 stage M04. **Checkpoints:** CP-04. **Implementation status:** NOT STARTED.

### POR-03

**Definition:** Each holding shows current value where a trustworthy last known USDT price exists. Missing price never becomes zero; unvalued holdings stay visible. Price observation time and stale status are visible.

**Acceptance:** Missing quote leaves holding visible and value unavailable, not zero; trusted cached quote shows time and stale label

**Verification:** calculator + UI fixtures. **Evidence:** value/state/time assertions. **Milestones:** M03/M13. **Gates:** TG-04. **Checkpoints:** CP-04. **Implementation status:** NOT STARTED.

### POR-04

**Definition:** Portfolio shows a partial valuation when some holdings lack valid prices and identifies completeness separately from freshness. If none can be valued, valuation is unavailable. An empty portfolio has its own empty state.

**Acceptance:** Empty Portfolio value is zero; nonempty unvalued total unavailable; mixed coverage shows known subtotal and excluded holdings

**Verification:** calculator cases + UI. **Evidence:** empty/none/partial result assertions. **Milestones:** M03/M13. **Gates:** TG-04. **Checkpoints:** CP-04. **Implementation status:** NOT STARTED.

### POR-05

**Definition:** For eligible holdings, show acquisition cost, unrealized P&L in USDT, and unrealized P&L percentage. Unknown acquisition price is unavailable, never zero. A zero cost denominator yields unavailable percentage. Stale-price status propagates.

**Acceptance:** Known cost computes Decimal quantity×USDT acquisition price and P&L; unknown cost stays unavailable; zero denominator makes percentage unavailable

**Verification:** financial unit/property tests. **Evidence:** exact Decimal edge assertions. **Milestones:** M03/M13. **Gates:** TG-04. **Checkpoints:** CP-04. **Implementation status:** NOT STARTED.

### POR-06

**Definition:** Aggregate unrealized P&L includes only eligible holdings and is explicitly partial when inputs are missing. Aggregate percentage uses the corresponding aggregate acquisition cost, never a sum of holding percentages.

**Acceptance:** Aggregate P&L uses eligible holdings and matching aggregate cost; percentage is ratio of aggregates, never sum of returns

**Verification:** financial unit/property tests. **Evidence:** partial and denominator assertions. **Milestones:** M03/M13. **Gates:** TG-04. **Checkpoints:** CP-04. **Implementation status:** NOT STARTED.

### POR-07

**Definition:** Allocation chart uses exactly the holdings eligible for the displayed valuation set. Excluded holdings remain identifiable; allocation cannot imply a complete portfolio when valuation is partial.

**Acceptance:** Allocation denominator equals displayed valued set; excluded holdings remain identified and partial label persists

**Verification:** calculator + chart/UI tests. **Evidence:** slice sum and excluded-state assertions. **Milestones:** M03/M13. **Gates:** TG-04. **Checkpoints:** CP-04. **Implementation status:** NOT STARTED.

### POR-08

**Definition:** Market sync cannot delete or corrupt a saved holding when its asset leaves Top 100, its quote becomes unavailable, or a provider response fails. The app must preserve portfolio-owned data and present its changed market eligibility honestly.

**Acceptance:** Top 100 departure, delisting or provider failure never deletes saved holding; offline edit remains possible and eligibility state is honest

**Verification:** provider/storage fault tests. **Evidence:** holding identity and edit assertions. **Milestones:** M05/M12/M17. **Gates:** TG-06/09. **Checkpoints:** CP-04. **Implementation status:** NOT STARTED.

### POR-09

**Definition:** Native USDT is a V1 Portfolio-only asset valued nominally at 1 USDT per unit. It can be created, edited and removed offline, contributes to valuation and allocation, and has no acquisition-price input, unrealized P&L, market quote, synthetic market row or pair, market chart, statistics or WebSocket subscription. The old PLAN-2 instruction not to implement until approved is historical proposal status; PLAN-8-R1.5 approved this effective V1 behavior.

**Acceptance:** Offline USDT create/edit/delete survives relaunch; value and allocation use nominal 1:1; no acquisition/P&L field, market row/pair/chart/stats/quote or socket appears

**Verification:** domain + persistence + UI. **Evidence:** nominal/absence/subscription assertions. **Milestones:** M03/M12/M13. **Gates:** TG-04. **Checkpoints:** CP-04. **Implementation status:** NOT STARTED.

### CHT-01

**Definition:** Asset charts offer 1D, 7D, 1M, 1Y using actual Binance USDT historical prices. Each range has explicit time/USDT units, cached offline data, and a clear insufficient-data state.

**Acceptance:** Each 1D/7D/1M/1Y asset range uses actual eligible USDT observations and cached offline points; insufficient coverage is explicit

**Verification:** history fixture + chart UI. **Evidence:** range/time/currency/coverage assertions. **Milestones:** M08/M11. **Gates:** TG-06. **Checkpoints:** CP-03. **Implementation status:** NOT STARTED.

### CHT-02

**Definition:** Selecting an actual plotted point reveals its observed time and price. Selection is accessible without relying only on touch position.

**Acceptance:** Selecting a plotted observation reveals its actual time and price; equivalent information is accessible without touch-only interaction

**Verification:** chart UI/accessibility. **Evidence:** point/VoiceOver assertions. **Milestones:** M11. **Gates:** QG-03. **Checkpoints:** CP-03. **Implementation status:** NOT STARTED.

### CHT-03

**Definition:** Show price change for the selected period from actual eligible observations. If endpoints or coverage are insufficient, show unavailable instead of substituting a different period.

**Acceptance:** Period change uses eligible endpoints of selected range; insufficient endpoints show unavailable, never another period’s return

**Verification:** history calculation tests. **Evidence:** range and missing-endpoint assertions. **Milestones:** M08/M11. **Gates:** TG-06. **Checkpoints:** CP-03. **Implementation status:** NOT STARTED.

### CHT-04

**Definition:** Portfolio valuation history records actual portfolio snapshots and charts those records. No backfilled value is fabricated from today’s holdings. Snapshot completeness and stale-price information remain available for honest presentation.

**Acceptance:** Holding mutation snapshot is atomic; later cadence captures actual portfolio values only; chart never backfills today’s holdings

**Verification:** file-backed snapshot + chart tests. **Evidence:** mutation/cadence/history assertions. **Milestones:** M04/M12/M14. **Gates:** TG-03/09 stage M04. **Checkpoints:** CP-05. **Implementation status:** NOT STARTED.

### AI-01

**Definition:** A dedicated AI Analysis tab displays a static demonstration report, works offline, uses the approved Custom Fintech presentation, and is visibly labeled Demo Mode. Demonstration figures are not presented as the user’s portfolio or personalized advice.

**Acceptance:** AI tab renders clearly labeled static Demo Mode offline, with illustrative figures never styled as user holdings or advice

**Verification:** offline UI/accessibility. **Evidence:** content and no-request assertions. **Milestones:** M15. **Gates:** QG-04. **Checkpoints:** CP-05. **Implementation status:** NOT STARTED.

### AI-02

**Definition:** V1 AI Analysis is a local static illustrative Demo Mode, plainly labeled and usable offline with no actual portfolio input, market analysis, network request, LLM, personalized investment advice or artificial loading. It has a feature boundary only; no provider protocol, async analysis infrastructure or future LLM commitment is required. App Store suitability remains unresolved.

**Acceptance:** Static feature starts without network, actual inputs, provider protocol, async analysis or artificial loading; no real LLM integration

**Verification:** feature isolation test/review. **Evidence:** dependency graph and no-request assertions. **Milestones:** M15. **Gates:** QG-04. **Checkpoints:** CP-05. **Implementation status:** NOT STARTED.

### DAT-01

**Definition:** SwiftData remains the UI-facing source of truth. Sync writes are atomic for their intended unit; success is reported after commit; failures preserve trustworthy cache. Extend this rule to holdings, quotes, and snapshots.

**Acceptance:** UI reads committed SwiftData state; failed write leaves prior cache; success publication follows matching commit

**Verification:** file-backed integration/fault. **Evidence:** transaction and UI-state assertions. **Milestones:** M04/M06. **Gates:** TG-05. **Checkpoints:** CP-04. **Implementation status:** NOT STARTED.

### DAT-02

**Definition:** Explicit CoinGecko↔Binance identity, current exchangeInfo Spot/trading/USDT eligibility, and mapping coverage determine which assets enter Markets or can be newly added. Ticker similarity alone never authorizes a match.

**Acceptance:** Unverified ticker match or inactive/missing Spot USDT pair never authorizes new asset; current mapped Top 100 asset can be selected

**Verification:** provider fixtures + mapping tests. **Evidence:** exchangeInfo/rank/evidence assertions. **Milestones:** M05/M12. **Gates:** TG-06. **Checkpoints:** CP-02/04. **Implementation status:** NOT STARTED.

### DAT-03

**Definition:** Track quote provider, USDT currency, observation time, and freshness per asset/pair. One pair’s update cannot mark another live. Cached stale price may be used offline only with a stale label and time.

**Acceptance:** Each quote records provider/currency/time/freshness; one pair update cannot mark another live; stale cached quote retains time

**Verification:** repository + UI race tests. **Evidence:** per-pair state/provenance assertions. **Milestones:** M06/M07. **Gates:** TG-07. **Checkpoints:** CP-04. **Implementation status:** NOT STARTED.

### DAT-04

**Definition:** Provider limits and failures use controlled retries and recovery; no retry loop overwhelms a provider. A failed refresh does not destroy cache or imply fresh data.

**Acceptance:** 429/provider failure observes bounded retry/cooldown; failed refresh preserves cache and never reports fresh success

**Verification:** clock-controlled provider tests. **Evidence:** request-count/cooldown/cache assertions. **Milestones:** M05/M06. **Gates:** TG-06. **Checkpoints:** CP-02. **Implementation status:** NOT STARTED.

### OFF-01

**Definition:** Portfolio editing and local calculations work offline; previously cached market data, charts, and asset images remain available. Missing cache has an explicit unavailable state. Connectivity restoration triggers appropriate refresh. No cloud sync.

**Acceptance:** Offline relaunch shows committed holdings, cached markets/charts/icons where present, explicit misses where absent; offline edit persists; reconnect refreshes without overwrite

**Verification:** offline file-backed + device UI. **Evidence:** relaunch/cache/mutation/reconnect assertions. **Milestones:** M10/M12/M17. **Gates:** TG-09 stage M17. **Checkpoints:** CP-05. **Implementation status:** NOT STARTED.

### LIF-01

**Definition:** Markets use periodic REST; Portfolio and active Details use required WebSocket subscriptions. Background suspends sockets; foreground restores only needed subscriptions. Obsolete actions cannot update current state.

**Acceptance:** Only foreground Portfolio/visible Details demand sockets; Markets refreshes via REST; stale generation after lifecycle transition cannot publish

**Verification:** lifecycle/reducer tests. **Evidence:** subscription/generation assertions. **Milestones:** M06/M07/M16. **Gates:** TG-08. **Checkpoints:** CP-05. **Implementation status:** NOT STARTED.

### STA-01

**Definition:** Markets, Details, Portfolio, charts, and AI tab have appropriate loading, empty, stale, unavailable, and error states. A failed operation never appears successful; retry is offered where useful. Empty portfolio and unavailable valuation are distinct.

**Acceptance:** Each screen exposes applicable loading/empty/stale/unavailable/error states; failed action does not show success and offers useful retry

**Verification:** state table UI tests. **Evidence:** screen state and retry assertions. **Milestones:** M09/M10/M13/M15. **Gates:** QG-03. **Checkpoints:** CP-05. **Implementation status:** NOT STARTED.

### UX-01

**Definition:** Native navigation, reusable Custom Fintech design, Light/Dark Mode, accessibility, and responsive performance cover primary flows. VoiceOver, Dynamic Type, contrast, chart alternatives, and physical devices require verification.

**Acceptance:** Navigation, Light/Dark, Dynamic Type, VoiceOver, contrast and chart alternatives are usable on target device matrix

**Verification:** UI/accessibility/device checks. **Evidence:** device/screenshots/audit record. **Milestones:** M09/M19. **Gates:** QG-03. **Checkpoints:** CP-05. **Implementation status:** NOT STARTED.

### MIG-01

**Definition:** Introduce Portfolio through a safe SwiftData schema migration. Start with no holdings, do not convert Favorites, preserve compatible market/cache records, and do not reset the whole store. Upgrade failure must be detectable and recoverable without silently discarding user data.

**Acceptance:** Legacy fixture upgrade yields empty holdings, preserves compatible cache and detects/recoverably reports failure without whole-store reset; final retirement separately authorized

**Verification:** file-backed migration/fault. **Evidence:** upgrade/relaunch/rollback report. **Milestones:** M04/M16/M17. **Gates:** TG-09 staged. **Checkpoints:** CP-05. **Implementation status:** NOT STARTED.

### REL-01

**Definition:** Automated tests, CI gates, performance checks, security/privacy review, physical-device checks, TestFlight, and App Store readiness have recorded pass/fail evidence before release.

**Acceptance:** Release candidate has recorded applicable CI, coverage, performance, privacy/security, physical device and TestFlight evidence with unresolved blockers tracked

**Verification:** release evidence review. **Evidence:** gate artifacts and release checklist. **Milestones:** M18/M22/M25. **Gates:** TG-10/QG-04. **Checkpoints:** CP-05. **Implementation status:** NOT STARTED.

### DAT-05

**Definition:** Persist quote provenance; independently protect asset mapping revision and quote observation revision, reject results from obsolete mapping evidence or REST/WS generations, preserve the last trustworthy committed quote and publish accepted updates only after commit.

**Acceptance:** Committed quote records provider/currency/time, generation and mapping revision; REST captures quote observation revision and relevant asset mapping revision at request start. If mapping changes A→B while request A is in flight and no newer quote was accepted, reject the returned A result solely because mapping evidence is obsolete: do not alter committed quote or publish accepted-update success. Also reject obsolete REST after a newer accepted quote and obsolete WebSocket generations; failed commit preserves last trustworthy price and publishes no success.

**Verification:** deterministic controlled interleaving of mapping A request, mapping B commit and A response without sleeps, plus REST/WS ordering and file-backed commit-failure tests. **Evidence:** independent mapping-revision and quote-revision assertions, unchanged committed quote, no accepted-update publication, generation/commit-order results. **Milestones:** M06/M07. **Gates:** TG-07. **Checkpoints:** CP-04. **Implementation status:** NOT STARTED.

### OFF-02

**Definition:** Expose recoverable local-storage failures and explicit recovery states while protecting committed financial data; never automatically reset the new financial store.

**Acceptance:** Injected store initialization or mutation failure shows recoverable error; prior committed holdings/snapshots survive failure/relaunch; retry can recover; no silent destructive action or automatic new-store reset

**Verification:** file-backed failure injection + recovery UI. **Evidence:** before/after store identity and recovery assertions. **Milestones:** M04/M17. **Gates:** TG-09 staged. **Checkpoints:** CP-05. **Implementation status:** NOT STARTED.

## Financial and domain decisions

Decimal is financial truth; Double is only a visualization boundary. USD and USDT are never silently equivalent. Missing prices and unknown costs are unavailable, never zero. Cached last trustworthy prices retain observation time and stale labels.

- **DM-01:** A holding survives departure from CoinGecko Top 100. If its verified Spot USDT pair remains active, continue REST and WebSocket tracking. It remains editable, deletable, and eligible for calculations, but is absent from Markets and cannot be newly added from outside the supported list.
- **DM-02:** A confirmed delisted holding survives with its last trustworthy price. That historical price may support valuation, allocation, and P&L, with an explicit historical/delisted label; it is never Live. Editing and deletion remain available. Temporary provider failure is not delisting.
- **DM-03:** USDT is a special portfolio asset valued nominally at Decimal(1) USDT per USDT. It has no artificial trading pair or network price request. It contributes to value and allocation, but not P&L or expected P&L coverage.
- **DM-04:** One fixed freshness threshold applies to REST and WebSocket quotes, evaluated per asset. Live additionally requires a relevant active WebSocket subscription. Stored facts, time, pair eligibility, and subscription state determine presentation. Exact threshold is deferred.
- **DM-05:** One holding per asset; strictly positive Decimal quantity; optional non-negative Decimal average acquisition price in USDT. Unknown cost is distinct from zero. Deletion closes a holding; adding an existing asset opens edit. Quantity edits do not recalculate average acquisition price.
- **DM-06:** Decimal calculations remain separate from locale-aware adaptive formatting. Intermediate values are not prematurely rounded, and meaningful non-zero values must not be displayed as zero. Numeric bounds and rounding thresholds are deferred.
- **DM-07:** Pure, deterministic calculations consume a consistent input snapshot and return values, completeness, freshness, and exclusion reasons. Matching eligible sets are used for total, allocation, aggregate P&L, and its cost denominator.
- **DM-08:** Actual valuation snapshots are captured after consistent data is available on launch, on deduplicated foreground return, after successful holding changes, and periodically while active. No per-quote or per-tab capture; no fabricated closed-app observations or recalculation of old snapshots.
- **DM-09:** Portfolio history preserves complete and partial observations, freshness, and delisted input status. It distinguishes unavailable and empty states and does not imply investment performance.
- **DM-10:** Asset line charts use Binance USDT historical observations for 1D, 7D, 1M, and 1Y, with period-based resolution, interaction, offline cache, and truthful full-period change. The suggested candle intervals and completed-close input remain candidates, subject to provider-contract verification.

**RD-01.** Strict online eligibility: new non-USDT holdings require current online CoinGecko Top 100 membership, explicit identity mapping and active Binance Spot USDT pair. Cached eligibility is insufficient. Existing holdings may be edited or removed offline; native USDT may be created offline. Verify before the atomic transaction and revalidate mapping revision/evidence before commit; no network request inside the transaction.

**RD-02.** P&L completeness: expected set is all non-USDT holdings; eligible set has trustworthy valuation prices and known acquisition cost. Empty expected set is Not Applicable; nonempty with empty eligible set is Unavailable; strict subset is Partial; equal nonempty sets are Complete. Aggregate percentage uses matching eligible acquisition cost, never summed individual returns; zero denominator makes percentage unavailable while absolute P&L may remain.

**RD-03.** Accepted market and historical prices are positive; invalid observations preserve last trustworthy prices. Empty portfolio value is zero. Nonempty portfolio without valued holdings has unavailable valuation; partial valuation is the known subtotal.

**RD-04.** Acquisition cost is quantity multiplied by known acquisition price and does not depend on a current quote. Unknown acquisition price is not zero.

**RD-05.** Native USDT is Portfolio-only, nominal 1:1, contributes to value and allocation, and has no market row, pair, chart, statistics, live subscription, acquisition-price input or unrealized P&L.

Native USDT is Portfolio-only at nominal 1:1; it contributes to value and allocation but never acquisition cost or unrealized P&L. Aggregate P&L uses eligible holdings and matching acquisition cost; a zero denominator makes percentage unavailable. Actual snapshots cannot fabricate closed-app observations or backfill today's holdings. Final Decimal bounds remain separately gated.

## Offline and eligibility

New non-USDT holdings require current online Top 100, explicit mapping and active Binance Spot USDT verification before atomic persistence, with evidence/revision revalidation before commit. Cached eligibility is insufficient. Existing holdings can be edited or removed offline; native USDT can be created offline. Committed portfolio data survives offline launch. Retain holdings after Top 100 exit or confirmed delisting; network failure is not delisting. Storage failures must show recovery states and protect committed data. Never automatically reset the new financial store.

## User experience decisions

- **UX-01:** Modern, data-first Fintech interface — Financial meaning and status lead visual hierarchy; no trading-terminal density.
- **UX-02:** Portfolio → Markets → AI Analysis; Portfolio cold-launch default — Three tab contexts, shared Details, modal holding forms, preserved foreground context.
- **UX-03:** Supported ranked Markets with search, refresh, four sorts — Actual CoinGecko rank remains visible even when sort order changes; list may have fewer than 100 assets.
- **UX-04:** Shared Asset Details with six sections — Separate CoinGecko USD global statistics from Binance USDT exchange statistics; support existing departed/delisted holdings.
- **UX-05:** Portfolio dashboard, calculations, charts, and CRUD — All financial sections consume one consistent domain result.
- **UX-06:** Asset Selection and Holding Form flows — Drafts remain separate from committed data; success follows persistence; USDT has a quantity-only form.
- **UX-07:** Three accessible interactive chart types — Actual observations and quality metadata control presentation; no fabricated points or misleading line continuity.
- **UX-08:** Static offline Demo Mode report — No actual holdings, current market claims, LLM, backend, or refresh.
- **UX-09:** Resilient offline-first states — Connectivity, availability, sync, freshness, completeness, and storage health remain distinct.
- **UX-10:** Semantic SwiftUI design system — System appearance by default; restrained reusable components without financial logic. Indigo and the spacing scale remain visual proposals.

Portfolio launches first. Independent tab navigation, shared Details, holding forms, allocation, actual history and distinct loading, empty, stale, partial, unavailable and error states are required. Accessibility includes VoiceOver, Dynamic Type, Reduce Motion, contrast and chart alternatives with device checks. User-facing strings are English-first with locale-aware numeric/date checks.

## Static AI Analysis

AI-01/02 and FD-08 define a plainly labeled local illustrative Demo Mode. It uses no actual portfolio or market analysis, network request, LLM, personalized recommendation, artificial loading, AI Chat, provider protocol or async analysis infrastructure. App Store suitability remains open.
