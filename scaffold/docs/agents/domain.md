# Domain Docs

How engineering skills should consume this repo's domain documentation.

## Before exploring, read these

- **[`CONTEXT.md`](../../CONTEXT.md)** at the repo root — canonical glossary (grill / domain-modeling write here)
- **[`docs/domain/`](../domain/)** — deeper invariants
- **[`docs/adr/`](../adr/)** — ADRs that touch the area
- **[`docs/architecture/`](../architecture/)** — module boundaries and data flow (when present)
- Layer map: **[`docs/memory.md`](../memory.md)**

If a file does not exist, **proceed silently**. Don't flag absence; don't suggest creating docs upfront unless the task is documentation. The `/domain-modeling` skill (via `/grill-with-docs`) updates `CONTEXT.md` / ADRs lazily when terms or decisions resolve.

## File structure

```
/
├── CONTEXT.md                 # glossary (canonical)
├── context.md                 # optional human direction / active goal (not glossary)
├── docs/
│   ├── memory.md              # layer map
│   ├── product/
│   ├── domain/
│   ├── architecture/
│   ├── adr/
│   └── agents/
├── specs/
├── .cursor/skills/            # repo-authored skills
├── .agents/skills/            # vendored skills (skills-lock.json)
├── rules/
├── templates/
├── spikes/
└── .scratch/                  # tickets / wayfinding
```

`context.md` is intent; orientation from repository evidence uses `.cursor/skills/orient-in-project/`. Root `context.md` collides with `CONTEXT.md` on case-insensitive filesystems — see `docs/memory.md`.

## Use the glossary's vocabulary

When output names a domain concept (issue title, refactor proposal, hypothesis, test name), use the term as defined in `CONTEXT.md`. Don't drift to synonyms the glossary explicitly avoids.

If the concept is missing, either you are inventing language (reconsider) or there is a real gap (note for `/domain-modeling`).

## Flag ADR conflicts

If output contradicts an existing ADR, surface it explicitly rather than silently overriding. Superseding an accepted ADR needs human approval first — see `AGENTS.md`.

## Writing rules for `/domain-modeling`

The skill is vendored and knows nothing about this repo's layered memory (nor do the other skills under `.agents/skills/` — see [`vendored-skills.md`](vendored-skills.md) for the full binding). When it writes, these apply:

- **ADRs** are `docs/adr/NNNN-slug.md`, numbered one above the highest existing file, and are a title plus one dense paragraph — no Status / Context / Decision sections. See [`templates/adr.md`](../../templates/adr.md).
- **`CONTEXT.md` stays a glossary.** Invariants that need more than a line go to `docs/domain/<topic>.md`; the glossary links there rather than absorbing them.
- **Never markdown-link from `CONTEXT.md`, `docs/domain/` or `docs/adr/` into `specs/` or `.scratch/`.** Stable layers may name a spec in prose or backticks, but a link down into a volatile layer fails `scripts/check-memory.sh`. See [`docs/memory.md`](../memory.md) rule 2.
- **Run `./scripts/check-memory.sh`** after a session that touched any memory file.
