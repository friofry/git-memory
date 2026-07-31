# Agent instructions

Short entry for AI agents. Details live in the linked layers — do not treat this file as the domain encyclopedia.

## Memory map

Read [`docs/memory.md`](docs/memory.md) once if you are new to the repo layout.

## Starting or resuming

Use [`.cursor/skills/orient-in-project/`](.cursor/skills/orient-in-project/) to rebuild an evidence-based map of project state and next action. Human-chosen direction (when set) lives in `active-context.md` — distinct from the glossary [`CONTEXT.md`](CONTEXT.md).

Before a long turn, run [`.cursor/skills/prepare-packet/`](.cursor/skills/prepare-packet/): it assembles the context envelope this stage calls for, so the turn starts from evidence rather than recall.

When the state is known but the next procedure is not, use
[`.cursor/skills/ask-git-memory/`](.cursor/skills/ask-git-memory/) to route the
evidence to one delivery action without advancing the stage.

## How work moves

Features travel through the stages in [`docs/agents/delivery-workflow.md`](docs/agents/delivery-workflow.md) — request → research → spec → human approval → plan → build → checks → review → rework → CI → human acceptance → memory write-back. The current stage of one feature is the `Stage:` line in `specs/<NN>-<slug>/spec.md`; move it in the same commit as the evidence for that stage.

## Before changes

Read, in order, as relevant to the task:

1. `active-context.md` — the direction a human chose (when set; not the glossary)
2. [`docs/product/charter.md`](docs/product/charter.md) — product intent (when present)
3. [`CONTEXT.md`](CONTEXT.md) — canonical glossary (use these terms; respect `_Avoid_`)
4. [`docs/architecture/`](docs/architecture/) — module boundaries (when present)
5. ADR(s) under [`docs/adr/`](docs/adr/) that touch the area
6. The active feature under [`specs/`](specs/) (and tickets under [`.scratch/`](.scratch/) if linked)
7. [`docs/method/`](docs/method/) — how work is typed, addressed, gated and packaged, when you are creating a node or moving a stage

## Hard constraints

- Use glossary terms from `CONTEXT.md`; do not invent synonyms marked `_Avoid_`.
- Prefer scoped diffs; do not change unrelated files.
- <!-- Project-specific constraints go here. Cite their home (ADR / rules / domain doc). -->

## Before finishing

Run what applies for this repo (fill in after setup):

```bash
# ./scripts/check-memory.sh
# <project test commands>
```

Update memory when facts or decisions changed (`CONTEXT.md`, ADR, active `specs/.../decisions.md`), then run:

```bash
./scripts/check-memory.sh
```

## Needs human approval

Stop and escalate before:

- changing a public schema or persisted data shape
- data migrations / durability behavior
- new infrastructure or third-party dependencies
- changing module boundaries or dependency direction
- weakening or deleting tests only to make CI green
- contradicting an existing ADR (surface the conflict explicitly)

## Local tracker & skills

- Feature specs: [`specs/`](specs/) — see [`docs/agents/issue-tracker.md`](docs/agents/issue-tracker.md)
- Delivery stages: [`docs/agents/delivery-workflow.md`](docs/agents/delivery-workflow.md)
- Tickets / wayfinding: [`.scratch/`](.scratch/)
- Triage `Status:` labels: [`docs/agents/triage-labels.md`](docs/agents/triage-labels.md)
- Domain consumption rules: [`docs/agents/domain.md`](docs/agents/domain.md)
- Repeatable procedures: [`.cursor/skills/`](.cursor/skills/) (repo-authored) · `.agents/skills/` (vendored; the directory appears on first `npx skills add` — see [`docs/agents/vendored-skills.md`](docs/agents/vendored-skills.md))
- Checkable constraints: [`rules/`](rules/)
