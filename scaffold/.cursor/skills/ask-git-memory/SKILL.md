---
name: ask-git-memory
description: Route the current repository state to exactly one next delivery action. Use when you do not know what to do next in a git-memory project, or which skill owns the current stage.
disable-model-invocation: true
---

# Ask git memory

You do not need to remember the workflow. Ask the repository.

This is a router, not an implementation skill. Inspect enough evidence to identify
the current position, then recommend exactly one next action. Do not perform that
action unless the user separately asks you to continue.

## Establish the position

1. Read `AGENTS.md` and `active-context.md` when it exists.
2. Read `specs/README.md`, the current branch and local changes.
3. If there is an active feature, read its `spec.md` header — the `ID:`, `Type:`
   and `Stage:` lines — and corroborate the stage against the evidence required by
   [`../../../docs/agents/delivery-workflow.md`](../../../docs/agents/delivery-workflow.md).
4. If a ticket queue exists, read the `Type:`, `Status:` and `Blocked by:` lines of
   the unblocked tickets. The stage says which gate is next; the ticket type says
   which skill does the work.
5. If the task or active feature is still unclear, follow
   [`../orient-in-project/SKILL.md`](../orient-in-project/SKILL.md) and use its
   evidence-based report.

Never infer progress from chat alone. If the `Stage:` claim and repository evidence
disagree, route to resolving that mismatch before advancing. Name the node by address
in the answer — `F:007-auth-envelope`, or `T:007/03` when the recommendation is about
one ticket ([`../../../docs/method/addressing.md`](../../../docs/method/addressing.md)).

## Route on the stage

The stage definitions and transitions live only in
[`../../../docs/agents/delivery-workflow.md`](../../../docs/agents/delivery-workflow.md),
and what blocks each transition lives only in
[`../../../docs/method/gates.md`](../../../docs/method/gates.md). This table only
chooses the entry point.

| Current situation | Next action |
|-------------------|-------------|
| The wanted outcome is missing or ambiguous | Ask the human for one outcome sentence (`request`, `M:gate-request`) |
| A substantial outcome exists but has no feature folder | [`create-feature-spec`](../create-feature-spec/SKILL.md) |
| `request`, `research`, or `spec` is incomplete | [`create-feature-spec`](../create-feature-spec/SKILL.md) |
| `approval` has unresolved meaning or architecture questions | Put `spec.md`, `design.md`, `acceptance.md` and `decisions.md` in front of the human in the `M:approval-checklist` shape; use `/grill-with-docs` only for the unresolved questions |
| `approval` is recorded but no implementable tickets exist | `/to-tickets` (`plan`) |
| `build` or `checks` | Route on the ticket's `Type:` — see the next table |
| `review` | [`review-change`](../review-change/SKILL.md); add [`review-architecture`](../review-architecture/SKILL.md) for a cross-cutting or boundary-changing diff |
| `rework` | [`implement-feature`](../implement-feature/SKILL.md) on the blocking findings only, then repeat checks |
| `ci` | Inspect the independent CI result; do not substitute another local run |
| `acceptance` | Put the demo, CI evidence, and `acceptance.md` in front of the human |
| `memory` with active status | [`implement-feature`](../implement-feature/SKILL.md) to write back durable facts and decisions, run the memory check, and finish the status transition |
| `memory` with implemented status | The feature is finished; ask for the next outcome |

Human gates are `request`, `approval`, and `acceptance`. Recommend what to put in
front of the human at those gates, not autonomous work that skips the gate.

## Route on the type

`Stage:` and `Type:` answer different questions, and the stage alone will send you
to the wrong skill. A `Type: research` ticket at `Stage: build` is not
implementation work that happens to be early — it is a question, and it produces
prose. The eleven values are defined in
[`../../../docs/method/work-types.md`](../../../docs/method/work-types.md); this
table only says where each one routes when the feature is at `plan`, `build` or
`checks`.

| Ticket `Type:` | Route | Because |
|----------------|-------|---------|
| `implementation`, `feature`, `bug`, `test` | [`implement-feature`](../implement-feature/SKILL.md) | The contract is fixed; the open question is whether the code matches it |
| `research` | Vendored `research`; the deliverable is the ticket's `## Answer`, then a pointer into `decisions.md` | A research ticket that grows a working branch has no spike home and gets merged because it exists |
| `prototype` | `/prototype` under `spikes/<slug>/<name>/`, thrown away afterwards | The code answers a question; keeping it makes the answer a dependency |
| `interface` | Fix the contract first, using `M:ticket-interface` and the deep-module vocabulary from `.agents/skills/codebase-design/` | Every ticket that names this seam in `Blocked by:` stays unclaimed until this one resolves |
| `architecture` | [`review-architecture`](../review-architecture/SKILL.md) on the design, and an ADR under `docs/adr/` before code | A seam that moves without an ADR is a decision nobody can find later |
| `review` | [`review-change`](../review-change/SKILL.md) | Reviewing and fixing in one pass produces a review record of defects that were never independently found |
| `rework` | [`implement-feature`](../implement-feature/SKILL.md), scoped to the quoted blocking finding | Fixing the non-blocking half grows the diff past the version that was reviewed |
| `memory` | Write to `CONTEXT.md`, an ADR, or `decisions.md`; change no behaviour | A behaviour change inside a memory ticket lands after the review gate |

A spec carries only `feature`, `bug` or `architecture`. If the request is a
`bug`, do not route it through the full spec chain by reflex — a defect with a
reliable reproduction and no design question runs from a ticket, and the threshold
for opening a spec is in
[`../create-feature-spec/SKILL.md`](../create-feature-spec/SKILL.md).

## Recommend a packet before a long turn

Any routed action that will read more than a couple of files starts with
[`prepare-packet`](../prepare-packet/SKILL.md) — "Next: `/prepare-packet T:007/03
build`, then [`implement-feature`](../implement-feature/SKILL.md) on that packet."
The profile per stage is in
[`../../../docs/method/packet-profiles.md`](../../../docs/method/packet-profiles.md).

The router itself assembles no packet: it reads a handful of header lines and stops.
A router that loads the whole feature has already spent the context the routed turn
needs.

## On-ramps and exceptions

- **Current state is unclear** → [`orient-in-project`](../orient-in-project/SKILL.md).
- **A tiny bugfix or memory-layer-only change has no spec** → use git evidence and
  the applicable checks directly; do not invent a feature stage.
- **A difficult defect lacks a reliable reproduction** → `/diagnosing-bugs`;
  return to [`implement-feature`](../implement-feature/SKILL.md) once there is a
  tight failing loop.
- **A blocking question needs a runnable answer** → `/prototype` in `spikes/`,
  recorded as a `Type: prototype` node, then feed the answer back into the spec.
- **The effort is too foggy to fit into one specification session** →
  `/wayfinder`; rewrite its `Type: grilling` and `Type: task` lines to `research`
  and `implementation` on arrival, then return through
  [`create-feature-spec`](../create-feature-spec/SKILL.md) and `/to-tickets`, not
  directly to implementation.
- **The session is ending mid-stage** → `/handoff`.
- **A merge is conflicted** → `/resolving-merge-conflicts`.
- **There is no feature request, only a desire to improve maintainability** →
  `/improve-codebase-architecture`; any adopted recommendation starts as a new
  `request`.

Vendored Matt skills provide craft. Prefer the repo-authored entry point whenever
one exists because it knows this repository's paths, stages, checks, and memory
rules — [`../../../docs/agents/vendored-skills.md`](../../../docs/agents/vendored-skills.md).

## Answer shape

Return only:

1. **Position** — node address, stage and status, or `no staged feature`.
2. **Evidence** — the decisive file, git observation, or check result.
3. **Next** — exactly one action, with its owner (`human`, `agent`, or `CI`) and
   the skill path or command to use.
4. **Blocker** — one blocker if present; otherwise `none`.

## Stop conditions

- **Do not update `Stage:`.** Routing is a reading operation. The stage moves in
  the same commit as the evidence for it, written by the skill that produced the
  evidence — see "Who moves the line" in
  [`../../../docs/agents/delivery-workflow.md`](../../../docs/agents/delivery-workflow.md).
- **Do not edit files, run the routed skill, commit, or open a pull request** while
  answering.
- **Do not recommend two actions.** If two look equally next, the position is not
  established; say so and route to
  [`orient-in-project`](../orient-in-project/SKILL.md) instead.
- **Do not route past a human gate.** At `request`, `approval` and `acceptance` the
  recommendation is what to put in front of a person.

## Precondition

Run `/setup-git-memory` once in a repository before using this router.
