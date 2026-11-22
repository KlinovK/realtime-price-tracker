# Agent instructions

## Purpose and stack

Build a production-quality iOS market tracker while developing senior iOS engineering, a professional AI-assisted workflow, and Python / AI Engineer skills. Use Swift 6, SwiftUI, SwiftData, Swift Charts, URLSession, actors, async/await, and XCTest. Keep AI Chat Module at Medium / P2 priority; follow [the roadmap](docs/roadmap.md) for current sequencing.

## Architecture

- Follow [ARCHITECTURE.md](ARCHITECTURE.md). SwiftData is the UI-facing source of truth for market, favorite, and chart data; provider DTOs do not enter view state.
- Reducers own transient state and cancellable effects. Report network success only after the matching persistence commit succeeds.
- Preserve stable asset identity, offline data, and correct stale/live presentation. Treat concurrency, persistence, and realtime correctness changes as high risk.

## Working rules

- Inspect branch, status, and relevant files before editing. Preserve existing changes. Do not switch a shared checkout, overwrite unrelated work, or run destructive Git commands without prior authorization. Use a separate worktree only when isolation is needed and authorized.
- Keep changes within the approved scope. Do not add dependencies, architecture layers, or files without a concrete need.
- Never put API keys, credentials, tokens, or private data in source, documentation, prompts, logs, or commits. Use approved local configuration; report and rotate exposed secrets.
- For code changes, run relevant XCTest coverage and the shared scheme test command in [README.md](README.md#testing-and-ci) when feasible. Report the exact command, result, and any tests not run. CI is not a substitute for UI or device evidence when those behaviors change.
- Follow [the AI workflow](docs/ai-workflow.md) for planning, risk review, evidence, approval gates, and the Engineering Learning Review.

## Definition of Done

The approved scope is complete; architecture invariants hold; relevant validation is recorded; the diff has no unrelated changes; required independent review and developer approvals are complete; and material documentation is current. Do not commit, push, create a PR, merge, or release without prior authorization.
