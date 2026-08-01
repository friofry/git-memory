# Issue tracker: Local Markdown

Feature **specs** (outcome / design / acceptance) live under [`specs/`](../../specs/).  
Implementation **tickets** and wayfinding maps live under [`.scratch/`](../../.scratch/).

Local markdown is the day-to-day tracker for agent skills. A remote (GitHub Issues, Linear, …) may exist for humans; agents still read and write here unless this file is updated to say otherwise. Why the writable truth stays local is at the end of this file.

## Specs (`specs/`)

- One feature per directory: `specs/<NN>-<feature-slug>/`
- Required files while `draft` / `active`: `spec.md`, `design.md`, `acceptance.md`, `decisions.md`
- A spec migrated in as `implemented` may carry `spec.md` alone
- Optional: `research.md` for long inventories
- Feature status lives **only** on `spec.md`: `draft` | `active` | `implemented`
- Delivery stage lives **only** on `spec.md` too: `Stage:` line, vocabulary in [`delivery-workflow.md`](delivery-workflow.md)
- Create via skill [`.cursor/skills/create-feature-spec/`](../../.cursor/skills/create-feature-spec/) and [`templates/feature-spec.md`](../../templates/feature-spec.md)

## Tickets (`.scratch/`)

Nothing durable may live only here — feature intent belongs in `specs/`. A global gitignore matches `.scratch`, so the repo `.gitignore` re-includes it; do not rely on force-add.

- One feature per directory: `.scratch/<feature-slug>/`, created only when there are tickets
- `spec.md` here is a **pointer** to `specs/<NN>-<slug>/` and carries no feature status
- Implementation issues: `.scratch/<feature-slug>/issues/<NN>-<slug>.md`, numbered from `01`
- **Numbers are unique within a feature.** Two files starting `03-` in one `issues/` folder make the address `T:007/03` ambiguous, and the resolver has no way to pick. `.git-memory-scripts/check-memory.sh` fails on a duplicate number rather than resolving to whichever file `ls` returned first
- Triage state on ticket files only: `Status:` or `**Status:**` line (see [`triage-labels.md`](triage-labels.md) for the permitted values)
- Comments append under `## Comments`

### The ticket header

Every ticket opens with plain `Key: value` lines — no YAML, so the existing
`Status:` extraction keeps working. The field list and the rules behind it are in
[`../memory.md`](../memory.md), "Node headers":

```
ID: T:007/03
Type: interface
Status: ready-for-agent
Parent: F:007-auth-envelope
Blocked by: T:007/01
Refs: M:ticket-interface, TERM:event-envelope
```

- `ID:` is the address this file's own path implies —
  `.scratch/auth-envelope/issues/03-envelope-schema.md` is `T:007/03`, where `007`
  is the number of `specs/007-auth-envelope/`. Address forms and the resolution
  rules are in [`../method/addressing.md`](../method/addressing.md)
- `Type:` is required, from the eleven values in
  [`../method/work-types.md`](../method/work-types.md)
- **No `Stage:` line on a ticket.** The stage belongs to the feature, in
  `specs/<NN>-<slug>/spec.md`, and a second copy on a ticket is the drift the
  one-home rule exists to stop
- `Blocked by:` lists addresses, not filenames. A ticket is unblocked when every
  address it names is `resolved` or `done`
- `Refs:` is where method boilerplate is cited instead of pasted — see
  [`../method/README.md`](../method/README.md)

## Spikes (`spikes/`)

A spike is a timeboxed question with throwaway code, never a module that ships.

- One question per directory: `spikes/<feature-slug>/<name>/`, with a `README.md`
  from [`templates/spike.md`](../../templates/spike.md)
- The README carries a node header: `ID:`, `Type:`, `Parent:`, and `Refs:` when it
  obeys a method ref. It carries **no `Status:` and no `Stage:` line** — a spike is
  done when its answer is written down
- Address form: `S:007/proto-a` resolves to `spikes/auth-envelope/proto-a/`
- `Type:` is `research` or `prototype` and nothing else
- What a spike learned is promoted into an ADR, `docs/domain/` or the spec; the
  spike directory is the primary source, not the home

## When a skill says "publish to the issue tracker"

Prefer creating/updating the canonical files under `specs/` for feature intent.  
Create ticket files under `.scratch/<feature-slug>/issues/` for implementable slices.

A vendored skill that wants to publish a **spec** (`/to-spec`) produces one
document in upstream's shape. Its sections map onto this repo's four files —
the mapping table is in [`vendored-skills.md`](vendored-skills.md), which is also
where every other upstream assumption is answered.

## When a skill says "fetch the relevant ticket"

Read the path the user passed. If they pass a feature slug, open `specs/*-<slug>/` first, then `.scratch/<slug>/issues/`.

## Wayfinding operations

Used by `/wayfinder`. The **map** is a file with one **child** file per ticket.

- **Map**: `.scratch/<effort>/map.md` — the Notes / Decisions-so-far / Fog body.
- **Child ticket**: `.scratch/<effort>/issues/NN-<slug>.md`, numbered from `01`, with the question in the body. The `Type:` line takes one of the eleven values in [`../method/work-types.md`](../method/work-types.md) — rewrite upstream's `grilling` to `research` and `task` to `implementation` as the ticket arrives; a `Status:` line records `claimed`/`resolved`.
- **Blocking**: a `Blocked by:` line near the top, listing addresses (`T:007/01`). A ticket is unblocked when every ticket it names is `resolved` or `done`.
- **Frontier**: scan `.scratch/<effort>/issues/` for files that are open, unblocked, and unclaimed; first by number wins.
- **Claim**: set `Status: claimed` and save before any work.
- **Resolve**: append the answer under an `## Answer` heading, set `Status: resolved`, then append a context pointer (gist + link) to the map's Decisions-so-far in `map.md`.

## Why not GitHub Issues as a second writable truth

GitHub Issues are the **human intake and visibility layer**: the issue forms under
`.github/ISSUE_TEMPLATE/` are where a request arrives, and the issue is where
someone who does not have the repository checked out can see that it exists. They
are not a second place where an agent writes state.

Two writable stores mean reconciling labels, status, ordering and history across
both, forever, in both directions. That work is unbounded and has no correct
answer: when the ticket file says `done` and the issue says `ready-for-agent`, no
rule tells you which one lost the race, and the loser is silently believed. Local
markdown also gives what an API cannot — the ticket moves in the same commit as
the code it describes, so `git log` carries the decision and a branch carries its
own ticket state.

The two meet at the **pull request**. The PR body names the node address, the
stage, the blocker and the memory delta, and its closing keyword shuts the intake
issue. One direction, one moment, no reconciliation loop — the handoff shape is in
[`../method/README.md`](../method/README.md) under the `M:handoff-*` family.

Escalate instead of improvising if a project genuinely needs issue state written
from an agent: that is a change to this file and an ADR, not a habit one skill
starts.
