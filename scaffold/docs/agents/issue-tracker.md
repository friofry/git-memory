# Issue tracker: Local Markdown

Feature **specs** (outcome / design / acceptance) live under [`specs/`](../../specs/).  
Implementation **tickets** and wayfinding maps live under [`.scratch/`](../../.scratch/).

Local markdown is the day-to-day tracker for agent skills. A remote (GitHub Issues, Linear, …) may exist for humans; agents still read and write here unless this file is updated to say otherwise.

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
- Triage state on ticket files only: `Status:` or `**Status:**` line (see [`triage-labels.md`](triage-labels.md) for the permitted values)
- Comments append under `## Comments`

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
- **Child ticket**: `.scratch/<effort>/issues/NN-<slug>.md`, numbered from `01`, with the question in the body. A `Type:` line records the ticket type (`research`/`prototype`/`grilling`/`task`); a `Status:` line records `claimed`/`resolved`.
- **Blocking**: a `Blocked by: NN, NN` line near the top. A ticket is unblocked when every file it lists is `resolved`.
- **Frontier**: scan `.scratch/<effort>/issues/` for files that are open, unblocked, and unclaimed; first by number wins.
- **Claim**: set `Status: claimed` and save before any work.
- **Resolve**: append the answer under an `## Answer` heading, set `Status: resolved`, then append a context pointer (gist + link) to the map's Decisions-so-far in `map.md`.
