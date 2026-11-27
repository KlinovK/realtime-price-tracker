# Agent instructions for CoinInsight

## Identity and context

CoinInsight is the approved target for `KlinovK/realtime-price-tracker`. P0 is a useful production-quality native iOS financial app; P1 goals are senior iOS engineering and professional AI-assisted software engineering. Foundational documentation is established; M00–M27 are not started. The current app is a legacy Favorites/Top 100 tracker.

Before substantive implementation, read the relevant parts of [README](README.md), [product requirements](docs/product.md), [architecture](ARCHITECTURE.md), [roadmap](docs/roadmap.md) and [engineering workflow](docs/ai-workflow.md). Product owns behavior; architecture technical invariants; roadmap sequencing/gates; workflow process/DoD; README current setup. Report material contradictions instead of inventing a decision. Provisional numbers and mechanisms are not approved production limits.

## Mandatory engineering rules

- Work only within authorized scope. Inspect branch, status, baseline and user changes before editing; preserve the original checkout and use a worktree when needed to protect changes or isolate risky work.
- Use Decimal for financial truth, distinguish USD from USDT, never fabricate prices or treat missing values as zero. Preserve stable asset identity and explicit online eligibility for new non-USDT holdings; existing holdings remain editable offline.
- Keep SwiftData as UI-facing truth. Financial holding mutation and snapshot are atomic; publish success only after matching commit. Never automatically reset the new financial store.
- Respect Swift 6 actor ownership and cancellation. Verify concurrency and ordering deterministically, including independent mapping and quote revisions. Do not claim unrun tests passed.
- V1 AI Analysis is static offline Demo Mode; no real LLM, portfolio analysis, personalized advice or AI Chat. Keep excluded features out of scope.
- Follow applicable acceptance, architecture and [DoD](docs/ai-workflow.md#definition-of-done--dod-0117) rules. Record actual evidence, limitations, required independent review and correct workflow status.

## Git and stop conditions

ED-01-R1 supersedes the former mandatory protection and separate routine Git-approval policy. Within an approved task, commit and push after applicable verification; low-risk work may go directly to `main`, medium-risk work uses a branch/PR when justified, and high-risk work requires independent review, a PR and successful applicable CI before merge. A compliant PR may be merged within the approved task without another routine approval. Branch protection is optional. Never force push, rewrite history, bypass failed checks or lose user changes. Destructive data work, security-policy changes, repository administration and App Store publication need explicit authorization. AI review is not human GitHub approval. Stop and report a missing authorization, baseline mismatch, material contradiction, unexpected user change, unresolved high-risk correctness defect or missing required feasibility evidence.
