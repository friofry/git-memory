# Vendored skills

`../../.agents/skills/` holds skills copied from
[`mattpocock/skills`](https://github.com/mattpocock/skills); provenance for each
one is in `skills-lock.json`. This file is the binding
between what those skills assume and what this repo actually is.

The split of labour: **upstream owns the discipline** (how to grill, how to slice
tickets, how to run a red-green loop, how to review a diff), **this repo owns
placement, vocabulary and enforcement** (where a file lands, which words to use,
which command proves it). Which skill runs at which delivery stage is in
[`delivery-workflow.md`](delivery-workflow.md) — that table is the map; this file
is the adapter underneath it.

## Not vendored, on purpose

| Upstream skill | Why not |
|----------------|---------|
| `setup-matt-pocock-skills` | Its output *is* [`issue-tracker.md`](issue-tracker.md), [`triage-labels.md`](triage-labels.md) and [`domain.md`](domain.md). Running it would overwrite answers we already gave. |
| `ask-matt` | A router over Matt's set; [`delivery-workflow.md`](delivery-workflow.md) is ours. |
| `grill-me`, `teach`, `writing-beats`, `writing-fragments`, `writing-shape`, `obsidian-vault`, `edit-article` | No delivery stage in this repo. |
| Everything under upstream `skills/deprecated/` and `skills/in-progress/` | Upstream says so. |

## How they are invoked

Cursor discovers `.cursor/skills/` and `.agents/skills/` at session start, so a
freshly vendored skill is invisible to the session that added it.

Upstream marks its orchestrating skills `disable-model-invocation: true`, which
Cursor honours: the skill stays discoverable but is only pulled in when a human
types `/name`. Upstream's own
`../../.agents/skills/writing-great-skills/` names the
trade — a model-invoked skill spends context every turn, a user-invoked one spends
your memory of it existing. Keep the field. It is what stops `implement` from being picked
over this repo's [`implement-feature`](../../.cursor/skills/implement-feature/),
and `to-spec` over [`create-feature-spec`](../../.cursor/skills/create-feature-spec/).

| Reached for automatically | Slash-only (`disable-model-invocation`) |
|---------------------------|------------------------------------------|
| `research`, `tdd`, `code-review`, `diagnosing-bugs`, `prototype`, `codebase-design`, `domain-modeling`, `grilling`, `resolving-merge-conflicts` | `to-spec`, `to-tickets`, `implement`, `wayfinder`, `triage`, `handoff`, `grill-with-docs`, `improve-codebase-architecture`, `writing-great-skills` |

Slash invocation is not documented to resolve inside a Cloud Agent prompt. An
agent that needs a slash-only skill reads its `SKILL.md` by path and follows it —
every stage row in [`delivery-workflow.md`](delivery-workflow.md) links that path.

## Local edits: none

Vendored files stay byte-identical to upstream. A local edit breaks the CLI's
hash comparison, so the next `npx skills update` silently reverts it and we lose
the change without a diff. Repo-specific instruction belongs in this file or in
the three adapter docs below — never inside a vendored `SKILL.md`.

`computedHash` in `skills-lock.json` is the CLI's own value, computed in a way we
cannot reproduce locally, so the bytes are pinned a second way:
`../../.agents/skills.sha256` lists a sha256 for
every vendored file and `scripts/check-memory.sh` compares it. An edit to a
vendored skill therefore fails the check until someone regenerates the manifest,
which puts the change in the diff instead of leaving it silent. Do not hand-write
either file; add or update through the CLI, then regenerate.

```bash
# add (repeat -s per skill; -a universal is what lands in .agents/skills/)
npx skills@latest add mattpocock/skills -s research -s tdd -a universal -y

# refresh everything already vendored
npx skills@latest update

# record the new bytes
./scripts/check-memory.sh --fix
```

## What upstream assumes, and what this repo answers

| Upstream assumption | This repo |
|---------------------|-----------|
| "The issue tracker and triage label vocabulary should have been provided" | [`issue-tracker.md`](issue-tracker.md) and [`triage-labels.md`](triage-labels.md) |
| Publish a spec to the tracker | A folder under [`../../specs/`](../../specs/) — see the section mapping below |
| Publish tickets to the tracker | `.scratch/<slug>/issues/NN-*.md`, per [`issue-tracker.md`](issue-tracker.md) |
| Wayfinding map, child tickets, frontier | "Wayfinding operations" in [`issue-tracker.md`](issue-tracker.md) |
| Save research "where the repo already keeps such notes" | `specs/<NN>-<slug>/research.md`, or `spikes/` for a timeboxed question |
| A prototype is throwaway code | `spikes/` — never a module under `replays_service/`, `frontend/` or `replay-parser-api/` |
| Documented coding standards (`code-review` Standards axis) | [`../../rules/`](../../rules/), [`../architecture/boundaries.md`](../architecture/README.md), [`../../CONTEXT.md`](../../CONTEXT.md), [`../../AGENTS.md`](../../AGENTS.md) |
| The originating spec (`code-review` Spec axis) | `specs/<NN>-<slug>/acceptance.md`, then `spec.md` |
| "Run typechecking and the test suite" | The commands in [`../../AGENTS.md`](../../AGENTS.md); Python only inside `replay-parser-api/.venv` |
| Write an ADR / update the glossary | [`domain.md`](domain.md) and [`../../templates/adr.md`](../../templates/adr.md) |
| `implement`: "commit your work to the current branch" | Commit on a branch, open a PR, and move the `Stage:` line — see [`delivery-workflow.md`](delivery-workflow.md) |
| `handoff`: save to the OS temp directory | A Cloud Agent's temp directory dies with the VM; put the handoff in the PR description instead |
| `improve-codebase-architecture`: write the HTML report to the OS temp directory and open it | Same caveat — nothing lands in the repo, so summarise the Top recommendation in the PR or the chat. A recommendation you adopt becomes a `request`, not a silent refactor |
| `writing-great-skills`: how to write a skill | Applies to [`../../.cursor/skills/`](../../.cursor/skills/) only. A vendored skill is never edited — see "Local edits: none" |

## Where the two disagree

### 1. Spec shape

Upstream `to-spec` writes one document (Problem Statement, Solution, User
Stories, Implementation Decisions, Testing Decisions, Out of Scope) and labels it
`ready-for-agent`. This repo splits a feature across four files whose presence
`scripts/check-memory.sh` enforces, and tracks state with `Status:` / `Stage:`
lines rather than a label. Specs `005`–`007` still carry the upstream shape from
before that rule existed.

**Resolution:** [`create-feature-spec`](../../.cursor/skills/create-feature-spec/)
owns stage `spec`; `to-spec` is how to *think* about the content. Sections land
like this:

| `to-spec` section | Lands in |
|-------------------|----------|
| Problem Statement, Solution | `spec.md` — Outcome, User scenario |
| User Stories | `acceptance.md` as Given/When/Then; scope lines in `spec.md` |
| Implementation Decisions | `design.md`, with the reasoning in `decisions.md` (global ones become an ADR) |
| Testing Decisions (seams) | `design.md` and `acceptance.md` |
| Out of Scope | `spec.md` — Out of scope |
| Further Notes | `spec.md` — Known / Assumed / Unknown |

A spec gets no triage label. Its state is the `Status:` and `Stage:` lines.

### 2. Ticket state vocabulary

Upstream's local ticket template writes `**Status:** ready-for-agent` in bold;
older tickets here use a plain `Status:` line; `wayfinder` adds `claimed` /
`resolved`; `.scratch/replay-facts-tools/` uses `done`.

**Resolution:** both line forms are accepted, and the permitted values are the
table in [`triage-labels.md`](triage-labels.md) — now including the repo-local
additions. `scripts/check-memory.sh` rejects a value outside it, so the next
drift shows up as a failing check instead of a fourth vocabulary.

### 3. ADR shape

`domain-modeling/ADR-FORMAT.md` allows optional Status / Considered Options /
Consequences sections. [`../../templates/adr.md`](../../templates/adr.md) allows
a title and one dense paragraph, nothing else.

**Resolution:** the repo template wins; this is already stated in
[`domain.md`](domain.md). The vendored file stays as upstream wrote it.

### 4. Two skills for one stage

`implement` and `implement-feature`, `code-review` and `review-change`,
`to-spec` and `create-feature-spec` overlap.

**Resolution:** the repo-authored skill is the entry point for the stage, because
it knows the paths, the test commands and the `Stage:` line. It delegates the
craft to the vendored one. Upstream's `disable-model-invocation` on the
overlapping skills already enforces this by default.
