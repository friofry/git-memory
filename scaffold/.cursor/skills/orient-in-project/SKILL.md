---
name: orient-in-project
description: Recover an evidence-based map of project state, the delivery stage of the active feature, and the next action when starting or resuming a session.
---

# Orient in project

Use this skill when starting a new session, switching branches,
resuming interrupted work, or when the current task context is unclear.

Do not modify production code.

## Role relative to `context.md`

| Artifact | Role |
|----------|------|
| `context.md` | Human-chosen direction and active goal (intent) |
| This skill | Recover factual state from repository evidence |

Do not confuse `context.md` with `CONTEXT.md` (canonical glossary). See `docs/memory.md`.

## Goal

Produce a compact and evidence-based map of:

- what project this is;
- what is being changed;
- where the change belongs architecturally;
- what state the work is currently in;
- what should happen next.

## Read order

Read only as much as necessary.

1. `AGENTS.md`
2. `context.md`, if present
3. `specs/README.md` — generated stage and status of every feature
4. current branch name and recent commits
5. active feature specification, including its `Stage:` line
6. `docs/agents/delivery-workflow.md` — what that stage demands and what comes next
7. relevant domain documentation
8. relevant architecture boundaries and ADRs
9. task-related source files
10. current tests and verification output

Do not read the whole repository unless necessary.

## Determine the active task

Look for evidence in this order:

1. explicitly provided user task;
2. active specification referenced by `context.md`;
3. current branch name;
4. recent commits;
5. modified or untracked files;
6. TODO or task files.

If these sources conflict, report the conflict.
Do not silently choose one interpretation.

## Produce this report

### 1. Project

One or two sentences describing the project and its main user outcome.

### 2. Current objective

Describe the concrete outcome currently being pursued.

Do not describe implementation details as the objective.

### 3. Current delivery stage

Report where the active feature sits in the delivery workflow
(`docs/agents/delivery-workflow.md`).

| # | Stage | Owner | Waiting on |
|---|-------|-------|------------|
| 1 | `request` | Human | The wanted outcome written down |
| 2 | `research` | Research agent | Inventory of code and memory |
| 3 | `spec` | Spec agent | Spec, design, acceptance |
| 4 | `approval` | Human | Approval of meaning and architecture |
| 5 | `plan` | Planner | Implementation plan / tickets |
| 6 | `build` | Builder | Implementation in a worktree |
| 7 | `checks` | Builder | Executable checks passing locally |
| 8 | `review` | Reviewer | An independent attempt to find defects |
| 9 | `rework` | Builder | Fixes for review findings |
| 10 | `ci` | CI | Independent repeat of the checks |
| 11 | `acceptance` | Human | Accepting demo and evidence |
| 12 | `memory` | Agent | Durable Git memory updated |

Do this in three steps:

1. **Claim** — read the `Stage:` line of the active `specs/<NN>-<slug>/spec.md`.
   With no active spec, say so and report the stage as `request` or `unknown`.
2. **Corroborate** — check the evidence that stage demands
   (`docs/agents/delivery-workflow.md`, column "Evidence lives in"): spec files,
   tickets, branch commits, review notes, CI runs, memory updates.
3. **Reconcile** — if the evidence contradicts the line, report both and mark the
   conflict; never rewrite the line while orienting.

State the stage as `N/12 <stage> — waiting on <owner>`, then the one-line
evidence for it. If several features are active, do this per feature and say
which one this session is about.

Loops are normal: `review` → `rework` → `checks` may repeat. Report the stage
currently in progress, not the furthest one ever reached.

If work is stuck or the position cannot be established from evidence, say
`blocked` or `unknown` instead of guessing a stage.

### 4. Architecture location

Show the relevant path through the system.

Example:

MCP client
→ MCP adapter
→ replay application service
→ parser core

List the affected module boundaries.

### 5. Active artifacts

List only relevant artifacts:

- feature spec;
- acceptance criteria;
- design;
- ADRs;
- domain docs;
- skills;
- tests;
- spikes.

For each artifact, state its role.

### 6. Observed state

Separate:

- completed;
- in progress;
- not started.

Base this on repository evidence, not assumptions.

### 7. Local changes

Summarize:

- modified files;
- untracked files;
- recent commits;
- failing checks.

Do not expose secrets or irrelevant generated files.

### 8. Known, assumed, unknown

Use three separate sections.

#### Known

Directly supported by code, tests, specifications, or repository state.

#### Assumed

Likely true but not directly confirmed.

#### Unknown

Important missing information that affects the next decision.

### 9. Risks and inconsistencies

Look for:

- spec and code disagreement;
- architecture-boundary violations;
- undocumented public contract changes;
- unclear source of truth;
- unbounded scope;
- stale context documents;
- failing or absent verification;
- unrelated work mixed into the branch.

### 10. Recommended next action

Recommend exactly one next action.

It should be small, concrete, and either finish the current delivery stage or
open the next one. Name the stage it belongs to and its owner — when the owner
is a human (`request`, `approval`, `acceptance`), the recommendation is what to
put in front of them, not work to start.

Examples:

- clarify one acceptance condition;
- create a timeboxed spike;
- review an architecture design;
- implement one vertical slice;
- run verification;
- perform independent review.

### 11. Human decisions required

List only decisions that should not be made autonomously, such as:

- public contract changes;
- schema migrations;
- security policy;
- module-boundary changes;
- significant new dependencies;
- destructive operations.

If none are required, state:

`No human decision is currently required.`

## Evidence rules

For each important conclusion, include the file, test, commit,
or repository observation supporting it.

Use these labels:

- `Observed`
- `Inferred`
- `Unknown`

Never present an inference as an observed fact.

## Stop conditions

Do not:

- implement the feature;
- refactor production code;
- update specifications;
- create commits;
- resolve architectural conflicts silently.

Stop after producing the orientation report.
