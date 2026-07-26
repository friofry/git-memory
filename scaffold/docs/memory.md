# Project memory map

Memory is organized as layers with different roles and lifetimes. Each fact has one primary home; other files link, they do not copy.

```
what we build
    ↓
how the domain works
    ↓
which architecture decisions are locked
    ↓
what we chose to pursue now (context.md) + feature specs
    ↓
how the agent performs a recurring job
    ↓
how to verify the result
```

| Layer | Path | Lifetime | Home for |
|-------|------|----------|----------|
| Human entry | `README.md` | Stable | What the project is; how to start |
| Agent entry | `AGENTS.md` | Stable (short) | What to read; hard limits; when to escalate |
| Product | `docs/product/` | Rarely changes | Why the product exists |
| Domain glossary | `CONTEXT.md` | Grows with terms | Canonical vocabulary (grill / domain-modeling write here) |
| Domain model | `docs/domain/` | Occasional | Deeper invariants beyond one-line glossary entries |
| Architecture | `docs/architecture/` | Occasional | Boundaries, data flow, quality attributes |
| ADR | `docs/adr/` | Append-only | Hard-to-reverse decisions |
| Human direction | `context.md` | Volatile (optional) | Chosen direction and active goal — not glossary |
| Delivery workflow | `docs/agents/delivery-workflow.md` | Stable | Stages a feature passes through, and the evidence each one leaves |
| Vendored-skill binding | `docs/agents/vendored-skills.md` | Occasional | What upstream skills assume, and what this repo answers |
| Specs | `specs/` | Per feature | Outcome, design, acceptance for a change |
| Tickets | `.scratch/` | Per feature | Implementation / research tickets |
| Rules | `rules/` | Stable | Short, checkable constraints |
| Skills | `.cursor/skills/` · `.agents/skills/` | Occasional | Repeatable procedures (repo-authored · vendored) |
| Templates | `templates/` | Stable | Empty forms |
| Spikes | `spikes/` | Per experiment | Questions and results — not production code |
| Verification | tests / CI / acceptance | Continuous | Executable truth |

### `context.md` vs `CONTEXT.md`

| File | Role | Who writes it |
|------|------|----------------|
| `CONTEXT.md` | Canonical domain glossary | Grill / domain-modeling |
| `context.md` | Human-chosen direction and active goal | Human (agents read; do not invent) |

Orientation recovers **facts** from the repository (skill [`.cursor/skills/orient-in-project/`](../.cursor/skills/orient-in-project/)). `context.md` supplies **intent**. Do not treat either as a substitute for the other.

**Case collision:** on case-insensitive filesystems (macOS/Windows defaults) `context.md` and `CONTEXT.md` cannot coexist at the repo root. Until a naming decision is made, do not commit a root `context.md`; copy [`templates/context.md`](../templates/context.md) only on case-sensitive volumes or keep direction in chat / the active spec. Candidate rename if the file must be shared with Cloud Agents: `active-context.md`.

## Growth rule

Start thin. Split a file only when it is too large or when two topics change at different rates. Do not invent empty folders ahead of real content.

## One-home rule

| Fact | Primary home |
|------|----------------|
| Why the product exists | `docs/product/charter.md` |
| What a term means | `CONTEXT.md` |
| Deep domain invariant | `docs/domain/<topic>.md` |
| Why we chose X over Y | `docs/adr/` |
| Human-chosen direction / active goal | `context.md` (optional; template at `templates/context.md`) |
| What this feature must do | `specs/.../spec.md` |
| How far a feature got | `specs/<NN>-<slug>/spec.md` `Status:` line |
| Which delivery stage a feature is in | `specs/<NN>-<slug>/spec.md` `Stage:` line |
| What the stages mean and demand | `docs/agents/delivery-workflow.md` |
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

Vendored copies carry **no local edits**: an edit breaks hash-based update detection and the next `npx skills update` reverts it without a diff. `.agents/skills.sha256` pins the vendored bytes so `scripts/check-memory.sh` fails on an edit rather than letting it pass unnoticed. Repo-specific instruction for a vendored skill lives in [`docs/agents/vendored-skills.md`](agents/vendored-skills.md).

## Keeping layers consistent

Three rules prevent two layers from drifting apart. `scripts/check-memory.sh` enforces what is mechanically checkable.

### 1. A copy must cite its home

`AGENTS.md` and `rules/` deliberately restate constraints in short, enforceable form. That is allowed — but every restatement ends with a pointer to the home (`— ADR 0001`, `— see CONTEXT.md`). Changing a fact then means grepping for the pointer, not remembering where copies live.

### 2. Links point down the stack, never up

Stable layers must not reference volatile ones: `CONTEXT.md`, `docs/domain/`, and `docs/adr/` do not link to `specs/` or `.scratch/`. The reverse is expected — a spec cites the ADR it obeys.

### 3. Volatile state is never duplicated

Status, delivery stage, ownership, and progress live in one file only. Overviews that repeat them (the `specs/README.md` table) are generated between `<!-- BEGIN generated:… -->` markers, not hand-edited.

### `.scratch/` holds tickets, never intent

A global gitignore on some machines matches `.scratch`, so the repo `.gitignore` re-includes it explicitly — otherwise part of the tracker is versioned and part silently is not. Even so, requirements and decisions belong in `specs/` or `docs/`; `.scratch/` holds implementation tickets and wayfinding only.
