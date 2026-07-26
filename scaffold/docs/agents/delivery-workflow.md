# Delivery workflow

How a feature travels from request to durable memory, and where each step leaves
evidence in the repository. This file is the home for the stage vocabulary; other
files reference these values, they do not redefine them.

Position of one feature is recorded as a `Stage:` line in
`specs/<NN>-<slug>/spec.md` — exactly one home, like the feature status
(see [`../memory.md`](../memory.md)). [`.cursor/skills/orient-in-project/`](../../.cursor/skills/orient-in-project/)
reads that line and corroborates it against repository evidence.

## Stages

| # | `Stage:` | Owner | Done when | Evidence lives in |
|---|----------|-------|-----------|-------------------|
| 1 | `request` | Human | The wanted outcome is written down, not just said | `specs/<NN>-<slug>/spec.md` Outcome |
| 2 | `research` | Research agent | Existing code and memory are inventoried; unknowns named | `research.md`, `spikes/<slug>/`, spec Known/Assumed/Unknown |
| 3 | `spec` | Spec agent | Outcome, design and Given/When/Then exist and agree | `spec.md`, `design.md`, `acceptance.md` |
| 4 | `approval` | Human | Meaning and architecture are approved | `decisions.md`; ADR under [`../adr/`](../adr/) when the decision is global |
| 5 | `plan` | Planner | Work is sliced into implementable tickets | `.scratch/<slug>/issues/NN-*.md` |
| 6 | `build` | Builder | The smallest slices are implemented on a worktree branch | Branch commits; a claimed ticket where a ticket queue exists |
| 7 | `checks` | Builder | The applicable commands from [`../../AGENTS.md`](../../AGENTS.md) pass locally | Command output in the session / PR body |
| 8 | `review` | Reviewer | An independent pass tried to find defects | Review in the shape of [`../../templates/review.md`](../../templates/review.md) |
| 9 | `rework` | Builder | Every blocking finding is fixed or explicitly deferred | Follow-up commits; review answered |
| 10 | `ci` | CI | The checks are repeated independently of the builder | GitHub Actions runs under [`../../.github/workflows/`](../../.github/workflows/) |
| 11 | `acceptance` | Human | Demo and evidence satisfy `acceptance.md` | Spec `Implemented in:` line; PR demo artifacts |
| 12 | `memory` | Agent | Facts and decisions that changed are written back | `CONTEXT.md`, ADR, `decisions.md`; `scripts/check-memory.sh` green |

Stages 7–9 form a loop: a review finding sends the feature back to `rework`, and
fixed code goes through `checks` again. The `Stage:` line records the stage
**currently in progress**, so moving it backwards is normal and expected.

## Stage and status

`Stage:` is the fine-grained position; `Status:` is the coarse one that
[`../../specs/README.md`](../../specs/README.md) and the tracker speak in. They must agree —
`scripts/check-memory.sh` enforces the mapping.

| `Stage:` | Allowed status |
|----------|----------------|
| `request`, `research`, `spec`, `approval` | `draft` |
| `plan`, `build`, `checks`, `review`, `rework`, `ci`, `acceptance` | `active` |
| `memory` | `active` while memory is being written, `implemented` once it is |

`memory` is also the resting state: `Stage: memory` with an implemented status
means finished, not work in progress. A spec migrated in as already-shipped
carries exactly that, because its history predates this workflow and only the
closing stage is verifiable.

Not every change is a feature. A tiny bugfix, and a change to the memory layer
itself, run without a spec and therefore without a stage — orientation reports
those from git evidence alone. The threshold for opening a spec is the one in
[`../../.cursor/skills/create-feature-spec/`](../../.cursor/skills/create-feature-spec/).

## Which skill performs which stage

Repo-authored skills ([`../../.cursor/skills/`](../../.cursor/skills/)) are the
entry point for a stage: they know the paths, the commands and the `Stage:` line.
Vendored skills (`../../.agents/skills/`) carry the craft.
How the two bind is [`vendored-skills.md`](vendored-skills.md).

| Stage | Entry point | Craft |
|-------|-------------|-------|
| `request` | Human | — |
| `research` | `../../.agents/skills/research/` | `../../.agents/skills/grilling/`, `../../.agents/skills/prototype/` for a timeboxed question |
| `spec` | [`../../.cursor/skills/create-feature-spec/`](../../.cursor/skills/create-feature-spec/) | `../../.agents/skills/to-spec/`, `../../.agents/skills/codebase-design/` for the seams |
| `approval` | Human | `../../.agents/skills/grill-with-docs/`, `../../.agents/skills/domain-modeling/` — ADR and glossary as it goes |
| `plan` | `../../.agents/skills/to-tickets/` | `../../.agents/skills/wayfinder/` when the effort outgrows one session; `../../.agents/skills/triage/` to label the queue |
| `build` | [`../../.cursor/skills/implement-feature/`](../../.cursor/skills/implement-feature/) | `../../.agents/skills/implement/`, `../../.agents/skills/tdd/`, `../../.agents/skills/codebase-design/` |
| `checks` | The commands in [`../../AGENTS.md`](../../AGENTS.md) | `../../.agents/skills/tdd/` |
| `review` | [`../../.cursor/skills/review-change/`](../../.cursor/skills/review-change/), [`../../.cursor/skills/review-architecture/`](../../.cursor/skills/review-architecture/) | `../../.agents/skills/code-review/` — Standards and Spec axes |
| `rework` | [`../../.cursor/skills/implement-feature/`](../../.cursor/skills/implement-feature/) | `../../.agents/skills/diagnosing-bugs/` |
| `ci` | GitHub Actions | — |
| `acceptance` | Human | — |
| `memory` | The skill that changed the fact | `../../.agents/skills/domain-modeling/` — glossary to `CONTEXT.md`, hard-to-reverse decision to an ADR |

Four vendored skills sit outside the chain:
`../../.agents/skills/resolving-merge-conflicts/` for
a conflicted merge, `../../.agents/skills/handoff/` when a session ends
mid-stage, `../../.agents/skills/improve-codebase-architecture/`
as a periodic scan whose recommendation enters the chain as a new `request`, and
`../../.agents/skills/writing-great-skills/` when editing a
skill under [`../../.cursor/skills/`](../../.cursor/skills/).

## Who moves the line

Every stage has one procedure responsible for writing the `Stage:` line when that
stage begins. A stage whose owner is a human or CI still needs an agent to record
the move.

| Stage written | By |
|---------------|-----|
| `request`, `research`, `spec`, `approval` | [`create-feature-spec`](../../.cursor/skills/create-feature-spec/) — it opens `spec.md`, so it starts the line and hands over for approval |
| `plan`, `build`, `checks`, `review`, `memory` | [`implement-feature`](../../.cursor/skills/implement-feature/) — it hands off with `review` |
| `rework`, `ci`, `acceptance` | [`review-change`](../../.cursor/skills/review-change/) — `rework` on a blocking finding, `ci` when clean, `acceptance` once CI is green |

## Moving a feature forward

1. Produce the evidence the stage asks for.
2. Edit the `Stage:` line in `specs/<NN>-<slug>/spec.md` in the **same commit** as
   that evidence, so git history carries the transition.
3. Update `Status:` when the mapping above requires it.
4. Run `./scripts/check-memory.sh` (add `--fix` to regenerate the specs table).

A `Stage:` line that no evidence supports is worse than no line at all —
orientation reports the mismatch instead of the claim.
