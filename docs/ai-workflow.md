# CoinInsight engineering workflow

This document owns process, risk, quality and the approved reconstructed Definition of Done. [Product](product.md) owns behavior, [architecture](../ARCHITECTURE.md) technical invariants and [roadmap](roadmap.md) sequencing/gates. Approval PLAN-8-R1.5 prospectively adopted the reconstructed DoD and statuses; their original historical wording is unavailable.

## Roles

- **Owner:** product decisions, scope and restricted-action authorization, human integration/release decisions.
- **ChatGPT:** architecture and technical leadership, planning, critical review and engineering mentorship.
- **Codex:** scoped repository inspection and authorized implementation with actual evidence.
- **Independent reviewer:** separate critical verification when policy or task requires it. AI review is not a human GitHub approval.

## PLAN → BUILD → REVIEW & SHIP

1. **PLAN:** inspect baseline, branch/status, source and applicable decisions; define objective, authorized scope, risk, acceptance, constraints and verification. Resolve material contradictions through the owner rather than inventing decisions.
2. **BUILD:** use an authorized isolated worktree when needed, preserve original user changes, make only scoped changes, and record source/test evidence. Keep network work outside atomic financial transactions.
3. **REVIEW & SHIP:** inspect complete diff and acceptance, run applicable deterministic checks, obtain required separate review, present actual results and limitations, seek human authorization before restricted Git/integration/release actions, and verify after merge when applicable. Unexecuted verification is never PASS.

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

Status ladder: PLANNED means identified but not execution-ready. READY means scope, prerequisites, acceptance criteria and required authorization established. IN PROGRESS means authorized execution started. IMPLEMENTED means changes completed but applicable verification remains. VERIFIED means applicable verification executed successfully; unexecuted checks are not PASS. REVIEWED means required separate review completed without blocking findings. READY TO MERGE means applicable integration prerequisites satisfied and awaiting explicit human merge authorization. DONE means, for integration tasks, authorized integration plus successful applicable post-merge verification; for tasks without integration, all task-specific acceptance, verification and review obligations completed. BLOCKED means a concrete unresolved dependency, defect or missing authorization prevents progress; record the blocker and required resolution. These statuses are distinct; no planning/read-only task is forced through a Git merge, and implementation integration obligations are not weakened. DOD-01 is mandatory and never N/A; other N/A decisions require recorded justification. Original DOD-01–17 wording remains unrecovered; PLAN-8-R1.5 approved these replacement definitions and all nine workflow statuses.

## Git and integration policy (ED-01)

Protect the original checkout and user changes; use an authorized isolated worktree for scoped implementation. The approved target requires PR integration, required green CI, protection from unauthorized direct/force push and main deletion, human merge authorization, risk-based independent AI review and applicable post-merge verification. A second human reviewer is not automatically required; AI review is not human GitHub approval. Actual GitHub protection configuration is unverified and administration needs separate authorization. Never autonomously merge, push to main, clean/reset user work, rename the repository or release.

## Engineering Learning Review

For significant implementation work, teach one to three actual concepts grounded in changed source and tests, with a short explanation and a developer exercise. Focus on senior iOS engineering, Swift/concurrency, architecture/testing and professional AI-assisted engineering. Keep this distinct from verification evidence. Do not restore the removed Python backend or separate AI Engineer education goals.

## Codex task protocol

A task brief identifies ID, effort, objective, authorized scope, risk, baseline, relevant decisions, exclusions, acceptance, verification commands, Git constraints, required evidence and stop conditions. Check whether approval already exists before asking again. Do not promote proposed parameters or untested mechanisms to approved production rules.

## Reporting protocol

Report baseline, authorized scope, actual changes, exact verification commands and results, acceptance matrix, remaining risks/limitations, repository integrity, correct workflow status and final verdict. Distinguish task-supplied approval from independently observed evidence and historical test results from newly executed tests. Do not fabricate pass results or independent sign-off.
