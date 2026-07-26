---
name: implement-feature
description: Implement an active specs/ feature from acceptance scenarios with scoped diffs, tests, and memory updates.
---

# Implement feature

Use when a `specs/<NN>-<slug>/` folder exists and tickets are ready for agent work.

## Inputs

- Path to `specs/<NN>-<slug>/`
- Optional `.scratch/<slug>/issues/NN-*.md` ticket

## Procedure

1. Read `spec.md`, `acceptance.md`, `design.md`, `decisions.md`.
2. Read `CONTEXT.md`, relevant ADRs, `docs/architecture/boundaries.md`.
3. Confirm the spec is past `approval`. If no ticket queue exists yet, publish one with `.agents/skills/to-tickets/` under `Stage: plan`; then set `Stage: build` when work starts (`docs/agents/delivery-workflow.md`).
4. Claim the ticket (`**Status:** claimed`) if using `.scratch` issues.
5. Implement the smallest slice that advances an acceptance scenario; `.agents/skills/implement/` is the craft, this skill is the repo wiring.
6. Add/adjust tests for that scenario first when behaviour is crisp — run the red-green loop from `.agents/skills/tdd/` (preferred for domain/parser). Reach for `.agents/skills/diagnosing-bugs/` when a slice or a review finding turns into a real bug.
7. Keep diff scoped to the design's affected modules.
8. Run the applicable test commands from `AGENTS.md`; that is the `checks` stage — set `Stage: checks` while running them.
9. Append implementation choices to `decisions.md` (promote to ADR if global).
10. Resolve ticket with `## Answer` / `Status: resolved` when done.
11. Hand off with `Stage: review`; a returning finding moves it to `rework`, not straight back to `build`.
12. After the human accepts, set `Stage: memory`, write the facts and decisions back, and only then set the status to implemented.

## Stop and escalate when

- Acceptance scenarios conflict with an ADR
- Design requires new infrastructure / dependency
- Unknowns in the spec block correctness

## Output

- Scoped commits / PR
- Green targeted tests
- Updated `decisions.md` / ticket Answer
