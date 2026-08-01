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
| 12 | `memory` | Agent | Facts and decisions that changed are written back | `CONTEXT.md`, ADR, `decisions.md`; `.git-memory-scripts/check-memory.sh` green |

Stages 7–9 form a loop: a review finding sends the feature back to `rework`, and
fixed code goes through `checks` again. The `Stage:` line records the stage
**currently in progress**, so moving it backwards is normal and expected.

## Gates on the transitions

The table above says what each stage is done when. A **gate** turns one of those
"done when" clauses into something that blocks the next stage and has a name you
can put in a `Refs:` line, a PR body or a prompt. Gates add no stages; they are the
enforcement projection of the table above.

| Transition | Gate | Address |
|------------|------|---------|
| `request` → `research` / `spec` | Request | [`M:gate-request`](../method/gates.md) |
| `approval` → `plan` | Approval | [`M:gate-approval`](../method/gates.md) |
| `checks` → `review` | Checks | [`M:gate-checks`](../method/gates.md) |
| `review` → `ci` | Review | [`M:gate-review`](../method/gates.md) |
| `ci` → `acceptance` | CI | [`M:gate-ci`](../method/gates.md) |
| `acceptance` → `memory` | Acceptance | [`M:gate-acceptance`](../method/gates.md) |
| `memory` → `Status: implemented` | Memory | [`M:gate-memory`](../method/gates.md) |

Who opens each gate, what evidence closes it, and the one failure mode it exists to
prevent are in [`../method/gates.md`](../method/gates.md). Do not restate the
evidence column here or in a skill — cite the address.

The remaining transitions (`research` → `spec`, `spec` → `approval`, `plan` →
`build`, `build` → `checks`, `review` → `rework`, `rework` → `checks`) carry no
gate. They move work inside one owner's hands, and the next gate downstream
re-examines the result anyway. A gate on every arrow would be ceremony that gets
skipped, and a gate people skip is worse than no gate: it makes the passed ones
look optional too.

## Stage and status

`Stage:` is the fine-grained position; `Status:` is the coarse one that
[`../../specs/README.md`](../../specs/README.md) and the tracker speak in. They must agree —
`.git-memory-scripts/check-memory.sh` enforces the mapping.

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

## The Type axis is not the stage

`Stage:` answers "where is this feature in its lifecycle?". `Type:` answers "what
kind of work is this node?". They are different questions about different things,
and the eleven `Type:` values are defined once, in
[`../method/work-types.md`](../method/work-types.md) — this file does not repeat
them.

Two consequences bind here:

- A ticket's type is independent of the feature's stage. While
  `specs/007-auth-envelope/spec.md` reads `Stage: build`, the queue underneath it
  can hold a `Type: research` ticket, a `Type: interface` ticket and a
  `Type: test` ticket at once.
- Four of the type values (`research`, `review`, `rework`, `memory`) are spelled
  exactly like stages. The collision is deliberate and harmless while the two
  questions stay apart: `Type: memory` is a ticket that writes facts back,
  `Stage: memory` is a feature at its closing stage. Never write "the feature is in
  the research type" or "the ticket's stage" — the first has no meaning and the
  second is the one-home rule breaking.

Only `feature`, `bug` and `architecture` are legal on a spec; a ticket may carry
any of the eleven; a spike is `research` or `prototype`. The legality table is in
[`../method/work-types.md`](../method/work-types.md) and `.git-memory-scripts/check-memory.sh`
enforces it.

## What the packet for this stage carries

Before a long agent turn, assemble a **packet**: the context envelope for one node
at one stage, built from six layers of which the stage's profile keeps only some.
The profile per stage is [`../method/packet-profiles.md`](../method/packet-profiles.md);
each row is addressable as `M:packet-<stage>`.

Read the profile as part of the stage. A `build` turn gets Route, Contract and
Slice and deliberately omits the glossary; a `review` turn adds Memory and Evidence
back because a reviewer without the architecture context reviews syntax. `request`
and `ci` have no profile — one is a human writing a sentence, the other is GitHub
Actions.

Assemble it with `./.git-memory-scripts/git-memory-packet.sh F:007-auth-envelope build`, or by
hand from that file's layer table when the script is not installed. Do not commit
the result: a packet is a projection, recomputed per turn — see
[`../memory.md`](../memory.md), "Projections".

## Which skill performs which stage

Repo-authored skills ([`../../.cursor/skills/`](../../.cursor/skills/)) are the
entry point for a stage: they know the paths, the commands and the `Stage:` line.
Vendored skills (`../../.agents/skills/`) carry the craft.
How the two bind is [`vendored-skills.md`](vendored-skills.md).

Start any long turn with [`prepare-packet`](../../.cursor/skills/prepare-packet/),
whatever the stage: it prints the packet the stage's profile calls for, so the turn
begins from assembled evidence instead of from whatever the session happened to
remember.

| Stage | Entry point | Craft |
|-------|-------------|-------|
| *(any stage, before a long turn)* | [`../../.cursor/skills/prepare-packet/`](../../.cursor/skills/prepare-packet/) — prints this stage's packet | — |
| `request` | Human | — |
| `research` | `../../.agents/skills/research/` | `../../.agents/skills/grilling/`, `../../.agents/skills/prototype/` for a timeboxed question; `../../.agents/skills/wayfinder/` when the shape of the work is still fog |
| `spec` | [`../../.cursor/skills/create-feature-spec/`](../../.cursor/skills/create-feature-spec/) | `../../.agents/skills/grill-with-docs/` to interrogate the outcome and write the ADR and glossary entries as it goes; `../../.agents/skills/codebase-design/` for the seams |
| `approval` | Human | `../../.agents/skills/grill-with-docs/`, `../../.agents/skills/domain-modeling/` — ADR and glossary as it goes |
| `plan` | [`../../.cursor/skills/plan-feature/`](../../.cursor/skills/plan-feature/) | `../../.agents/skills/wayfinder/` when the effort outgrows one session |
| `build` | [`../../.cursor/skills/implement-feature/`](../../.cursor/skills/implement-feature/) | `../../.agents/skills/tdd/`, `../../.agents/skills/codebase-design/` |
| `checks` | The commands in [`../../AGENTS.md`](../../AGENTS.md) | `../../.agents/skills/tdd/` |
| `review` | [`../../.cursor/skills/review-change/`](../../.cursor/skills/review-change/), [`../../.cursor/skills/review-architecture/`](../../.cursor/skills/review-architecture/) | `../../.agents/skills/code-review/` — Standards and Spec axes |
| `rework` | [`../../.cursor/skills/implement-feature/`](../../.cursor/skills/implement-feature/) | `../../.agents/skills/diagnosing-bugs/` |
| `ci` | GitHub Actions | — |
| `acceptance` | Human | — |
| `memory` | The skill that changed the fact | `../../.agents/skills/domain-modeling/` — glossary to `CONTEXT.md`, hard-to-reverse decision to an ADR |

Four vendored skills sit outside the chain:
`../../.agents/skills/resolving-merge-conflicts/` for
a conflicted merge, `M:handoff-pr` when a session ends
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

## How a human runs a feature

You say **what** and answer **yes/no**. The agent does **how** and writes
evidence into Git. Contracts and TDD live in files and commands, not in chat.

1. **Request** — state the outcome in one sentence. Agent: `/grill-with-docs` →
   `/create-feature-spec` (folder under [`../../specs/`](../../specs/)).
2. **Approval** — you read `spec` / `design` / `acceptance` and approve meaning
   and architecture. Without this, work stays at `approval`.
3. **Build** — you say "plan and implement". Agent: `/to-tickets` →
   `/implement-feature` (drives `/tdd`) → checks from [`../../AGENTS.md`](../../AGENTS.md) →
   `/review-change`.
4. **Acceptance** — you check CI + demo against `acceptance.md`. Say "accept";
   the agent writes memory back and sets `implemented`.

Human-required gates: request, approval, acceptance (plus answers during grill).
Everything else is agent-driven by stage.

One prompt that starts it:

> New feature: <outcome>. Follow the delivery workflow: grill → spec → stop at
> approval. After I OK — tickets, TDD, checks, review. Do not move `Stage:`
> without evidence.

The full 12-stage table is in [Stages](#stages) above.

## Moving a feature forward

1. Produce the evidence the stage asks for.
2. Edit the `Stage:` line in `specs/<NN>-<slug>/spec.md` in the **same commit** as
   that evidence, so git history carries the transition.
3. Update `Status:` when the mapping above requires it.
4. Run `./.git-memory-scripts/check-memory.sh` (add `--fix` to regenerate the specs table).

A `Stage:` line that no evidence supports is worse than no line at all —
orientation reports the mismatch instead of the claim.
