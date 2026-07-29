---
name: ask-git-memory
description: Ask what should happen next in a git-memory project. Route the current repository state to one delivery action or skill.
disable-model-invocation: true
---

# Ask git memory

You do not need to remember the workflow. Ask the repository.

This is a router, not an implementation skill. Inspect enough evidence to identify
the current position, then recommend exactly one next action. Do not perform that
action unless the user separately asks you to continue.

## Establish the position

1. Read `AGENTS.md` and `context.md` when it exists.
2. Read `specs/README.md`, the current branch and local changes.
3. If there is an active feature, read its `spec.md` `Stage:` line and corroborate
   it against the evidence required by `docs/agents/delivery-workflow.md`.
4. If the task or active feature is still unclear, follow
   `.cursor/skills/orient-in-project/SKILL.md` and use its evidence-based report.

Never infer progress from chat alone. If the `Stage:` claim and repository
evidence disagree, route to resolving that mismatch before advancing.

## Main route: request to memory

The stage definitions and transitions live only in
`docs/agents/delivery-workflow.md`; this table only chooses the entry point.

| Current situation | Next action |
|-------------------|-------------|
| The wanted outcome is missing or ambiguous | Ask the human for one outcome sentence (`request`) |
| A substantial outcome exists but has no feature folder | `/create-feature-spec` |
| `request`, `research`, or `spec` is incomplete | `/create-feature-spec` |
| `approval` has unresolved meaning or architecture questions | Put `spec.md`, `design.md`, and `acceptance.md` in front of the human; use `/grill-with-docs` only for the unresolved questions |
| `approval` is recorded but no implementable tickets exist | `/to-tickets` (`plan`) |
| `build` or `checks` | `/implement-feature` |
| `review` | `/review-change`; add `/review-architecture` for a cross-cutting or boundary-changing diff |
| `rework` | `/implement-feature` on the blocking findings, then repeat checks |
| `ci` | Inspect the independent CI result; do not substitute another local run |
| `acceptance` | Put the demo, CI evidence, and `acceptance.md` in front of the human |
| `memory` with active status | `/implement-feature` to write back durable facts and decisions, run the memory check, and finish the status transition |
| `memory` with implemented status | The feature is finished; ask for the next outcome |

Human gates are `request`, `approval`, and `acceptance`. Recommend what to put in
front of the human at those gates, not autonomous work that skips the gate.

## On-ramps and exceptions

- **Current state is unclear** → `/orient-in-project`.
- **A tiny bugfix or memory-layer-only change has no spec** → use git evidence and
  the applicable checks directly; do not invent a feature stage.
- **A difficult defect lacks a reliable reproduction** → `/diagnosing-bugs`;
  return to `/implement-feature` once there is a tight failing loop.
- **A blocking question needs a runnable answer** → `/prototype` in `spikes/`,
  then feed the learned answer back into the active spec.
- **The effort is too foggy to fit into one specification session** →
  `/wayfinder`; when the map clears, return through `/create-feature-spec` and
  `/to-tickets`, not directly to implementation.
- **The session is ending mid-stage** → `/handoff`.
- **A merge is conflicted** → `/resolving-merge-conflicts`.
- **There is no feature request, only a desire to improve maintainability** →
  `/improve-codebase-architecture`; any adopted recommendation starts as a new
  `request`.

Vendored Matt skills provide craft. Prefer the repo-authored entry point whenever
one exists because it knows this repository's paths, stages, checks, and memory
rules.

## Answer shape

Return only:

1. **Position** — stage and status, or `no staged feature`.
2. **Evidence** — the decisive file, git observation, or check result.
3. **Next** — exactly one action, with its owner (`human`, `agent`, or `CI`) and
   the skill path or command to use.
4. **Blocker** — one blocker if present; otherwise `none`.

Do not update `Stage:`, edit files, run the routed skill, commit, or open a pull
request while answering.

## Precondition

Run `/setup-git-memory` once in a repository before using this router.
