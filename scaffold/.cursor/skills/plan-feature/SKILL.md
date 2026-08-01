---
name: plan-feature
description: Cut an approved feature into implementable tickets against its acceptance scenarios, order them by dependency, and open Stage plan. Use after the approval gate closes and before any code is written.
---

# Plan feature

Turn one approved spec into a queue of tickets a build turn can pick up without
re-reading the whole feature. Runs at `Stage: plan`, between `M:gate-approval`
closing and the first `Stage: build` turn.

The unit of a ticket is **one acceptance scenario's worth of behaviour**, not one
file and not one afternoon. A ticket that cannot name the scenario it moves is
either a chore that belongs in the build turn, or a second feature wearing a
ticket's clothes.

## Inputs

- An approved `specs/<NN>-<slug>/` — `Stage: approval` recorded closed by a human.
- `acceptance.md`, which is the list this plan is cut against.
- `design.md` for the seams; a ticket that crosses three seams is usually two.

Refuse to run when `Stage:` is anything earlier than `plan`. Planning an
unapproved spec produces a queue that a human then has to reject ticket by
ticket — `M:gate-approval` in
[`../../../docs/method/gates.md`](../../../docs/method/gates.md).

## 1. Read the acceptance scenarios first

Open `acceptance.md` before `design.md`. The scenarios are the contract; the
design is one way of meeting it. Planning from the design first produces tickets
shaped like the implementation you already imagined, and they stop matching the
moment the design changes.

List the scenarios by name. Every one of them must be reachable by at least one
ticket when you are done, and that is the completeness test in step 5.

## 2. Choose a type per ticket

The eleven work types are in
[`../../../docs/method/work-types.md`](../../../docs/method/work-types.md); five
have a ticket boilerplate and those five cover almost every plan:

| Type | Boilerplate | Cut one when |
|------|-------------|--------------|
| `implementation` | `M:ticket-implementation` | A scenario needs behaviour that does not exist |
| `interface` | `M:ticket-interface` | A seam, schema or public signature has to be agreed before two tickets can proceed |
| `research` | `M:ticket-research` | A blocking Unknown survived the spec |
| `prototype` | `M:ticket-prototype` | A design question needs throwaway code to answer |
| `review` | `M:ticket-review` | A slice needs a second pair of eyes beyond the review gate |

`Type:` answers "what kind of work", never "how far along" — that is `Status:`,
and never "where in the lifecycle" — that is `Stage:`, which lives on `spec.md`
and on no ticket.

## 3. Write each ticket

One file per ticket under `.scratch/<slug>/issues/NN-<short-slug>.md`, numbered
uniquely within the feature. Two files starting `03-` make `T:007/03` ambiguous
everywhere at once, and `./scripts/check-memory.sh` fails on it.

```
# Sign the envelope

ID: T:007/03
Type: implementation
Status: ready-for-agent
Parent: F:007-auth-envelope
Blocked by: T:007/02
Refs: M:ticket-implementation, ADR:0012
```

Then the body in the boilerplate's shape. Cite the boilerplate by address in
`Refs:`; do not paste it — it has one home under
[`../../../docs/method/boilerplates/`](../../../docs/method/boilerplates/) and a
pasted copy is the one that goes stale.

`Status:` on a ticket is the triage vocabulary, not the feature vocabulary:
[`../../../docs/agents/triage-labels.md`](../../../docs/agents/triage-labels.md).

## 4. Order by dependency, not by priority

`Blocked by:` carries the real edges. Write the edge you actually have —
"T:007/03 cannot start until the envelope schema in T:007/02 is agreed" — and
leave the line off entirely when there is no edge. An invented ordering
serialises work that could have run in parallel.

Two rules the checker enforces:

- Every address in `Blocked by:` must resolve. A typo is a ticket blocked
  forever by nothing.
- The graph must be acyclic. Two tickets that block each other are one ticket, or
  a missing `interface` ticket between them.

```bash
./scripts/git-memory-graph.sh --format md      # the queue, blockers spelled out
./scripts/check-memory.sh                      # resolution and cycles
```

## 5. Prove the plan covers the contract

Walk `acceptance.md` scenario by scenario and name the ticket that moves it. A
scenario with no ticket is the plan's real defect and the reason this step is not
optional — it is invisible in every per-ticket review, because each ticket looks
fine on its own.

Record the mapping in the plan handoff, not in a new file: a scenario-to-ticket
table with a second home drifts the first time a ticket is renumbered.

A scenario no ticket reaches means one of three things, and they need different
answers:

- The plan is incomplete → cut the missing ticket.
- The scenario is untestable as written → back to the spec, and say so.
- The scenario is out of scope → it should not have passed approval; escalate
  rather than quietly dropping it.

## 6. Open the build stage

Set `Stage: build` on `spec.md` when every scenario is covered and the queue has
at least one ticket with no unresolved `Blocked by:`. A plan whose every ticket
is blocked has a cycle or a missing entry point.

```bash
./scripts/git-memory-packet.sh F:007-auth-envelope build
```

Hand over in the `M:handoff-pr` shape if the session ends here.

## Output

- `.scratch/<slug>/issues/NN-*.md`, one per ticket, each with a full node header.
- `Stage: build` on `spec.md`, and the frontier reachable from
  `./scripts/git-memory-graph.sh`.
- `./scripts/check-memory.sh` green, `--strict` green on the new tickets.
- A scenario-to-ticket mapping in the handoff.

## Stop and escalate when

- The acceptance scenarios cannot be cut into tickets without inventing
  behaviour nobody approved. The spec is underspecified; that is a spec problem
  and going back is cheaper than planning around it.
- Every candidate ticket depends on one unresolved Unknown. Cut the `research` or
  `prototype` ticket alone, timebox it, and plan the rest after it lands.
- The feature needs more than about a dozen tickets. That is usually two
  features; splitting now costs one renumbering, splitting later costs a
  rewrite of every `Parent:` line.
- A ticket would cross a boundary an ADR fixes. Name the ADR by address and stop
  — see [`../review-architecture/SKILL.md`](../review-architecture/SKILL.md).
