# AI engineering workflow

Use this workflow for changes to [Realtime Price Tracker](../README.md). Keep the plan and evidence proportional to risk. [AGENTS.md](../AGENTS.md) contains permanent agent rules; [ARCHITECTURE.md](../ARCHITECTURE.md) owns technical invariants; [roadmap.md](roadmap.md) owns priorities.

## PLAN

1. Inspect the branch, status, relevant source, tests, architecture, and roadmap. Identify existing developer changes before editing.
2. Define the desired behavior, scope, acceptance criteria, likely files, risks, and validation. State assumptions and unresolved decisions.
3. Classify the highest risk touched by the change:

   | Risk | Planning and review |
   | --- | --- |
   | **Low**: docs, isolated copy, or presentation with no behavioral impact | Combine planning and implementation; review the diff and run relevant checks. |
   | **Medium**: bounded feature or behavior change | Write a short implementation plan and require independent review. |
   | **High**: Swift concurrency or actor reentrancy, SwiftData persistence or database migration, realtime market data correctness, security or credentials, release behavior | Get explicit developer approval of the architecture before implementation; require independent review and targeted failure-path tests. |

Developer approval is needed for a high-risk architecture decision and for any material change in agreed scope. Reading files, inspecting diffs, and running safe local tests need no approval.

## BUILD

1. Implement only the agreed scope. Preserve the architecture invariants and pre-existing work. Add tests that verify behavior and failure paths, especially cache preservation, cancellation, stale/live state, and identity mapping when relevant.
2. Record implementation evidence: changed source and test references, decisions, important invariants, commands and outcomes, and any behavior that could not be verified. Use actual results, not predictions.
3. Before editing in a shared checkout, confirm its branch and status. Never reset, clean, restore, overwrite, or switch it to make room for a task. Use a separate worktree only when needed and authorized; confirm its base, branch, path, and status. Keep generated build output outside tracked files.

## REVIEW & SHIP

1. Compare the complete diff with the acceptance criteria and approved scope. Check correctness, failure and cancellation paths, Swift 6 isolation, persistence boundaries, data identity, security, user-visible states, tests, and documentation as applicable.
2. For medium and high risk, obtain review from someone other than the implementer (another developer or an independent reviewer). Give them the plan, diff, evidence, and known risks. Record findings and their resolution; unresolved material findings block shipping. High-risk review must examine the architecture decision and targeted failure-path results.
3. Report each test command, environment, pass/fail/skip result, and reason for anything not run. The shared scheme command is in [README.md](../README.md#testing-and-ci); CI uses [.github/workflows/ci.yml](../.github/workflows/ci.yml). Include simulator or device evidence for changed UI behavior when relevant.
4. Present the final diff, evidence, remaining risks, and Engineering Learning Review to the developer. Obtain prior authorization before committing, pushing, creating a PR, merging, releasing, or performing destructive Git operations. An earlier explicit authorization for the specific action remains valid.

### Definition of Done

- Acceptance criteria and approved scope are met, with no unrelated file changes.
- Architecture invariants and security expectations hold; relevant tests pass or limitations are clearly reported.
- Required independent review is complete and material findings are resolved.
- Implementation evidence and relevant documentation are complete.
- Required developer approvals are recorded before the gated action.

## Engineering Learning Review

After meaningful implementation, teach **1–3** concepts drawn from the changed source. For each, cite the actual source and relevant test, explain the idea in a few sentences, and give a small exercise for the developer to write without an AI-provided solution. Keep this section separate from implementation and test evidence. Check prior learning reviews and the topic index below; repeat a topic only when the new feature adds a distinct lesson. Add one compact index row after each feature review.

| Feature or review link | Concepts covered |
| --- | --- |
