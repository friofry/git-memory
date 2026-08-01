# Project memory map

Memory is organized as layers with different roles and lifetimes. Each fact has one primary home; other files link, they do not copy.

```
what we build
    ↓
how the domain works
    ↓
which architecture decisions are locked
    ↓
what we chose to pursue now (active-context.md) + feature specs
    ↓
how the agent performs a recurring job
    ↓
how to verify the result
```

That stack is **project truth** — what this repository builds. **Method truth** —
how work is typed, addressed, gated and handed over — sits beside the stack in
`docs/method/` rather than inside it, and the two never mix (rule 4 below).

| Layer | Path | Lifetime | Home for |
|-------|------|----------|----------|
| Human entry | `README.md` | Stable | What the project is; how to start |
| Agent entry | `AGENTS.md` | Stable (short) | What to read; hard limits; when to escalate |
| Product | `docs/product/` | Rarely changes | Why the product exists |
| Domain glossary | `CONTEXT.md` | Grows with terms | Canonical vocabulary (grill / domain-modeling write here) |
| Domain model | `docs/domain/` | Occasional | Deeper invariants beyond one-line glossary entries |
| Architecture | `docs/architecture/` | Occasional | Boundaries, data flow, quality attributes |
| ADR | `docs/adr/` | Append-only | Hard-to-reverse decisions |
| Method | `docs/method/` | Stable, portable | How work is typed, addressed, gated and packaged — never what the product is |
| Human direction | `active-context.md` | Volatile (optional) | Chosen direction and active goal — not glossary |
| Delivery workflow | `docs/agents/delivery-workflow.md` | Stable | Stages a feature passes through, and the evidence each one leaves |
| Vendored-skill binding | `docs/agents/vendored-skills.md` | Occasional | What upstream skills assume, and what this repo answers |
| Specs | `specs/` | Per feature | Outcome, design, acceptance for a change |
| Tickets | `.scratch/` | Per feature | Implementation / research tickets |
| Rules | `rules/` | Stable | Short, checkable constraints |
| Skills | `.cursor/skills/` · `.agents/skills/` | Occasional | Repeatable procedures (repo-authored · vendored) |
| Templates | `templates/` | Stable | Empty forms |
| Spikes | `spikes/` | Per experiment | Questions and results — not production code |
| Verification | tests / CI / acceptance | Continuous | Executable truth |

## Node headers

A **node** is a spec, a ticket or a spike README — the three files that carry
work. Every node opens with a block of plain `Key: value` lines. The node file is
the home for its own header; the vocabulary each line draws on lives elsewhere and
is linked, never copied.

```
ID: F:007-auth-envelope
Type: feature
Status: active
Stage: build
Parent: none
Children: T:007/01, T:007/02
Refs: ADR:0012, TERM:event-envelope, M:gate-approval
```

| Line | Answers | Vocabulary home |
|------|---------|-----------------|
| `ID:` | Which node is this? | The path — see [`method/addressing.md`](method/addressing.md) |
| `Type:` | What kind of work is it? | [`method/work-types.md`](method/work-types.md) |
| `Status:` | How far along, coarsely? | This file (specs) · [`agents/triage-labels.md`](agents/triage-labels.md) (tickets) |
| `Stage:` | Where in the lifecycle? **Specs only.** | [`agents/delivery-workflow.md`](agents/delivery-workflow.md) |
| `Parent:` · `Children:` · `Blocked by:` | How do nodes connect? | [`method/addressing.md`](method/addressing.md) |
| `Refs:` | Which method or domain facts govern it? | [`method/README.md`](method/README.md) |

Three properties of that block are load-bearing:

- **Plain lines, no YAML front matter.** `sed -n 's/^Status: *//p'` is how the
  status is read; a front-matter block would break every extraction in
  `.git-memory-scripts/check-memory.sh`.
- **`ID:` must equal the address the file's own path implies.** A mismatch means
  the file was copied rather than created, and a copied node points its `Parent:`
  and `Refs:` at another feature's work.
- **`Stage:` appears on a spec and nowhere else.** A ticket carrying a `Stage:`
  line is the one-home rule breaking in the place it costs the most.

A spec written before this header existed carries `Status:` and `Stage:` but no
`ID:`, `Type:` or `Parent:`. That is a warning under `.git-memory-scripts/check-memory.sh
--strict` and passes a default run, so an installed v1 repository stays green.

## `active-context.md` vs `CONTEXT.md`

| File | Role | Who writes it |
|------|------|----------------|
| `CONTEXT.md` | Canonical domain glossary | Grill / domain-modeling |
| `active-context.md` | Human-chosen direction and active goal | Human (agents read; do not invent) |

Orientation recovers **facts** from the repository (skill [`.cursor/skills/orient-in-project/`](../.cursor/skills/orient-in-project/)). `active-context.md` supplies **intent**. Do not treat either as a substitute for the other.

**Why the name.** On case-insensitive filesystems — the macOS and Windows defaults
— a root `context.md` and `CONTEXT.md` are the same path. One clobbers the other on
checkout, and the loser is whichever the tool happened to write second. The rename
is decided and done: the human-direction file is `active-context.md` at the repo
root, seeded from [`templates/active-context.md`](../templates/active-context.md).
`.git-memory-scripts/check-memory.sh` fails on a root `context.md` and prints the `git mv`
command to fix it:

```bash
git mv context.md active-context.md
```

## Projections

A **projection** is a view computed from the repository rather than stored in it:
an address, the work graph, a packet, the ticket frontier. Projections print to
stdout. Nothing generated by `.git-memory-scripts/git-memory-graph.sh` or
`.git-memory-scripts/git-memory-packet.sh` is committed, and a `build/` directory used to
redirect them is gitignored.

That is a deliberate design choice, not an omission. A committed graph is a second
copy of facts the node files already carry, and a second copy goes stale the first
time someone edits a `Refs:` line without rerunning the generator. Because the
projection is recomputed on every read, **there is no stale-generated-file check to
write and no staleness failure mode to recover from** — the only way for the graph
to be wrong is for the node headers to be wrong, which is what
`.git-memory-scripts/check-memory.sh` already checks.

The one generated thing that *is* committed is the specs table in
`specs/README.md`, because a reader browsing the repository on GitHub needs it
rendered. It lives between `<!-- BEGIN generated:… -->` markers and is rebuilt by
`./.git-memory-scripts/check-memory.sh --fix`; hand-editing it is what rule 3 below forbids.

## Growth rule

Start thin. Split a file only when it is too large or when two topics change at different rates. Do not invent empty folders ahead of real content.

## One-home rule

| Fact | Primary home |
|------|----------------|
| Why the product exists | `docs/product/charter.md` |
| What a term means | `CONTEXT.md` |
| Deep domain invariant | `docs/domain/<topic>.md` |
| Why we chose X over Y | `docs/adr/` |
| Human-chosen direction / active goal | `active-context.md` (optional; template at `templates/active-context.md`) |
| What this feature must do | `specs/.../spec.md` |
| Which node this is | Its path; the `ID:` line restates the address the path implies |
| What kind of work a node is | `Type:` line on the node file (vocabulary: `docs/method/work-types.md`) |
| How far a feature got | `specs/<NN>-<slug>/spec.md` `Status:` line |
| Which delivery stage a feature is in | `specs/<NN>-<slug>/spec.md` `Stage:` line |
| What the stages mean and demand | `docs/agents/delivery-workflow.md` |
| What blocks a stage transition | `docs/method/gates.md` (`M:gate-*`) |
| Which context layers an agent turn carries | `docs/method/packet-profiles.md` (`M:packet-*`) |
| How work is named, typed, addressed and handed over | `docs/method/` |
| How we know it is done | `specs/.../acceptance.md` |
| How to add a recurring change | `.cursor/skills/.../SKILL.md` |
| How a vendored skill binds to this repo | `docs/agents/vendored-skills.md` |
| How to rebuild session orientation | `.cursor/skills/orient-in-project/SKILL.md` |
| What architecture forbids | `rules/` |
| What a spike learned | `spikes/.../` then promote into ADR / domain / spec |

## Skills have two homes

Cursor discovers skills from `.cursor/skills/` and `.agents/skills/`, never from a bare top-level `skills/`. The split by origin keeps ownership unambiguous:

| Home | Origin | Who edits it |
|------|--------|--------------|
| `.cursor/skills/` | Written for this repo | Us — normal reviewed changes |
| `.agents/skills/` | Vendored from upstream | `npx skills add` / `npx skills update` |

Provenance for every vendored skill (upstream repo, path, content hash) lives in `skills-lock.json` at the root. Both directories are committed, because Cloud Agents only see the repository and never the machine's `~/.agents/skills`.

Vendored copies carry **no local edits**: an edit breaks hash-based update detection and the next `npx skills update` reverts it without a diff. `.agents/skills.sha256` pins the vendored bytes so `.git-memory-scripts/check-memory.sh` fails on an edit rather than letting it pass unnoticed. Repo-specific instruction for a vendored skill lives in [`docs/agents/vendored-skills.md`](agents/vendored-skills.md).

## Keeping layers consistent

Four rules prevent two layers from drifting apart. `.git-memory-scripts/check-memory.sh` enforces what is mechanically checkable.

### 1. A copy must cite its home

`AGENTS.md` and `rules/` deliberately restate constraints in short, enforceable form. That is allowed — but every restatement ends with a pointer to the home (`— ADR 0001`, `— see CONTEXT.md`). Changing a fact then means grepping for the pointer, not remembering where copies live.

### 2. Links point down the stack, never up

Stable layers must not reference volatile ones: `CONTEXT.md`, `docs/domain/`, and `docs/adr/` do not link to `specs/` or `.scratch/`. The reverse is expected — a spec cites the ADR it obeys.

### 3. Volatile state is never duplicated

Status, delivery stage, ownership, and progress live in one file only. Overviews that repeat them (the `specs/README.md` table) are generated between `<!-- BEGIN generated:… -->` markers, not hand-edited.

Ownership is the case people get wrong: no file carries an `Owner:` line. Who acts
next is derived from the stage, and the stage table in
[`agents/delivery-workflow.md`](agents/delivery-workflow.md) is its only home.

### 4. Project truth and method truth do not mix

> **Project truth** lives in the project layers: `CONTEXT.md`, `docs/domain/`,
> `docs/architecture/`, `docs/adr/`, `specs/`.
> **Method truth** lives in [`method/`](method/).
> Project artifacts reference method artifacts by `M:` address instead of copying
> the prose.

Project truth answers "what is this product and what are we building next"; it
changes once per feature and is worthless in any other repository. Method truth
answers "how does work get named, typed, gated and handed over"; it changes when
you decide to work differently, and ships intact into the next repository this
scaffold lands in.

The failure this rule prevents is a glossary that has quietly become a process
manual. A review-severity rubric or a ticket skeleton pasted into `CONTEXT.md` is
skipped by the people who came for the vocabulary and lost to the people who needed
the process. Put it under `docs/method/`, give it an `M:` address, and cite the
address from the `Refs:` line of the nodes that obey it — see
[`method/README.md`](method/README.md).

### `.scratch/` holds tickets, never intent

A global gitignore on some machines matches `.scratch`, so the repo `.gitignore` re-includes it explicitly — otherwise part of the tracker is versioned and part silently is not. Even so, requirements and decisions belong in `specs/` or `docs/`; `.scratch/` holds implementation tickets and wayfinding only.
