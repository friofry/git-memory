---
name: orient-in-project
description: Recover an evidence-based map of project state, the delivery stage of the active feature, and the next action when starting or resuming a session.
---

# Orient in project

Recover where this project is from repository evidence, not from memory of the
conversation. Use when starting a session, switching branches, resuming
interrupted work, or when the current task is unclear.

## Role relative to `active-context.md`

| Artifact | Role |
|----------|------|
| `active-context.md` | Human-chosen direction and active goal — intent |
| This skill | Factual state recovered from repository evidence |

`active-context.md` is not `CONTEXT.md`, the canonical domain glossary, and neither
substitutes for the other — [`../../../docs/memory.md`](../../../docs/memory.md). A
root `context.md` is the pre-rename layout: report it with the fix,
`git mv context.md active-context.md`.

## Read order

Read in this order and stop at the first step after which you can name the stage,
the evidence for it, and the next action. Each step names what selects the files it
covers; anything no step selects is out of scope for orienting.

1. `AGENTS.md`
2. `active-context.md`, if present
3. `specs/README.md` — the generated stage and status of every feature
4. current branch name and recent commits
5. the active feature's `spec.md` header: `ID:`, `Type:`, `Status:`, `Stage:`
6. [`../../../docs/agents/delivery-workflow.md`](../../../docs/agents/delivery-workflow.md)
   — what that stage demands and what comes next
7. the unblocked tickets under `.scratch/<slug>/issues/` — their `Type:`,
   `Status:` and `Blocked by:` lines
8. the `CONTEXT.md` headings named by the `Refs:` lines of that spec and those
   tickets — those entries only, never the glossary end to end
9. the ADRs named by the same `Refs:` lines, plus the `docs/architecture/` boundary
   document covering the modules those tickets touch
10. the source files those tickets name
11. the verification commands `AGENTS.md` lists, and the output of the last run

Steps 8–11 are selected by a `Refs:` line, a ticket, or `AGENTS.md` — never by a
judgement about what looks relevant. If nothing names a file, you do not read it.
If the position is clear after step 6, stop there and list the steps you skipped.

## Determine the active task

Take the first of these that exists: an explicitly provided user task; the
specification named by `active-context.md`; the branch name; recent commits;
modified or untracked files; TODO or task files. If two of them point at different
work, report the conflict — do not silently pick one.

## Establish the stage in three steps

The twelve stages, their owners and the evidence each one leaves are defined once,
in [`../../../docs/agents/delivery-workflow.md`](../../../docs/agents/delivery-workflow.md).
Read them there. This skill does not restate the table; it establishes which row
the repository is actually on.

1. **Claim** — read the `Stage:` line of the active `specs/<NN>-<slug>/spec.md`.
   With no active spec, say so and report the stage as `request` or `unknown`.
2. **Corroborate** — check the evidence that stage demands, from the workflow
   table's "Evidence lives in" column: spec files, tickets, branch commits, review
   artifact, CI runs, memory updates. What blocks the next transition, and what
   evidence closes it, is in
   [`../../../docs/method/gates.md`](../../../docs/method/gates.md) — cite the
   `M:gate-*` address rather than restating it.
3. **Reconcile** — if the evidence contradicts the line, report both and mark the
   conflict. Never rewrite the line while orienting.

State it in the form section 3 of [`REPORT-SHAPE.md`](REPORT-SHAPE.md) fixes:
`N/12 <stage> — waiting on <owner>`, then the one line of evidence for it.

Loops are normal: `review` → `rework` → `checks` may repeat. Report the stage
**currently in progress**, not the furthest one ever reached. If the position
cannot be established from evidence, say `blocked` or `unknown` rather than
guessing a stage.

## Name every node by address

The report identifies work by address, not by prose description: `F:007-auth-envelope`,
`T:007/03`, `S:007/proto-a`. Give the resolved path alongside the address the first
time each one appears, so a reader can click through and a script can resolve it.
Forms and resolution rules are in
[`../../../docs/method/addressing.md`](../../../docs/method/addressing.md). If
several features are active, orient per feature and say which one this session is
about.

## Evidence labels

For each important conclusion, name the file, test, commit or repository
observation supporting it, and label it `Observed` (read directly this session),
`Inferred` (drawn from what was observed) or `Unknown` (not established, and it
affects the next decision).

Never present an inference as an observed fact. An `Inferred` stage that nobody
checked is the failure this skill exists to prevent: it reads exactly like a
verified one and sends the next agent to the wrong gate.

Labelled lines read like this, and every conclusion in the report is one of them:

```
Observed: specs/007-auth-envelope/spec.md carries Stage: build; three commits on
          claude/auth-envelope touch src/events/.
Inferred: T:007/04 is the frontier — it is the only unblocked, unclaimed ticket.
Unknown:  whether CI ran on the head commit. Nothing records a run, and it decides
          whether the next gate is M:gate-checks or M:gate-ci.
```

## Produce the report

Eleven sections, in fixed order, defined in
[`REPORT-SHAPE.md`](REPORT-SHAPE.md). Follow that file; do not improvise a
shorter shape because the project looks small. Omitting a section is allowed only
by writing the section heading and the reason it is empty.

## Stop conditions

- Do not implement the feature.
- Do not modify production code — not a refactor, not a rename, not a formatting
  fix you are certain of.
- Do not update specifications, or move a `Stage:` line — including one you have
  proved wrong. The mismatch is the finding.
- Do not create commits.
- Do not resolve an architectural conflict silently; report it under section 9.
- Do not assemble a packet here. When the report recommends a long turn, name
  [`../prepare-packet/SKILL.md`](../prepare-packet/SKILL.md) as its first step.

Stop after producing the orientation report.
