# git-memory

Portable **layered git memory** + **12-stage delivery workflow** + wiring for
[Matt Pocock's agent skills](https://github.com/mattpocock/skills).

Drop this into another repository so agents recover project state from Git
(not from chat), advance features through named stages, and use Matt's craft
skills without forking them.

Born in [`friofry/starcraft-benchmark`](https://github.com/friofry/starcraft-benchmark);
this repo is the domain-free extract.

## What you get

| Piece | Role |
|-------|------|
| `scaffold/` | Files copied into a target project |
| `skills/setup-git-memory/` | One-shot setup skill (`/setup-git-memory`) |
| `matt-skill-sets.txt` | `minimal` and `full` lists for `npx skills add` |

Inside `scaffold/`:

- `docs/memory.md` — layer map and one-home rules
- `docs/agents/delivery-workflow.md` — stages `request` … `memory`
- `docs/agents/vendored-skills.md` — how Matt skills bind to this layout
- `.cursor/skills/` — `orient-in-project`, `create-feature-spec`, `implement-feature`, `review-change`, `review-architecture`
- `scripts/check-memory.sh` — enforceable consistency (status, stage, vendored bytes, ticket labels)
- `.github/workflows/memory.yml` — runs the checker on markdown PRs
- Templates for specs, ADRs, reviews, spikes

## Install into another project

### A. Agent skill (recommended)

1. Add this skill to the target project or your user skills:

```bash
# from a clone of this repo — copy the skill
cp -R skills/setup-git-memory <target>/.cursor/skills/

# or install via skills.sh:
# npx skills@latest add friofry/git-memory -s setup-git-memory -a universal -y
```

2. In the target project, run **`/setup-git-memory`** (or attach the skill and ask it to run).
3. Answer scope (`full` / `minimal`), confirm merges, let it vendor Matt's skills and run `./scripts/check-memory.sh --fix`.

### B. Manual

```bash
git clone https://github.com/friofry/git-memory.git /tmp/git-memory
cd <your-project>

# copy seed (do not overwrite existing AGENTS.md / CONTEXT.md blindly)
rsync -a --ignore-existing /tmp/git-memory/scaffold/ ./

# vendor Matt skills (full set example)
npx skills@latest add mattpocock/skills \
  -s research -s grilling -s domain-modeling -s grill-with-docs \
  -s to-spec -s to-tickets -s wayfinder -s triage -s implement -s tdd \
  -s codebase-design -s prototype -s diagnosing-bugs -s code-review \
  -s resolving-merge-conflicts -s handoff \
  -s improve-codebase-architecture -s writing-great-skills \
  -a universal -y

chmod +x scripts/check-memory.sh
./scripts/check-memory.sh --fix
```

Then fill `docs/product/charter.md`, grow `CONTEXT.md`, and put real test commands into `AGENTS.md`.

## After setup

| Intent | Skill |
|--------|-------|
| Where are we? | `/orient-in-project` |
| New feature | `/create-feature-spec` → human approval → `/to-tickets` → `/implement-feature` |
| Review | `/review-change` (drives vendored `/code-review`) |
| Refresh Matt skills | `npx skills@latest update && ./scripts/check-memory.sh --fix` |

Do **not** run Matt's `/setup-matt-pocock-skills` on a project that already has this seed — it would overwrite `docs/agents/issue-tracker.md`, `triage-labels.md`, and `domain.md`.

Do **not** edit files under `.agents/skills/`. Bindings and conflicts live in `docs/agents/vendored-skills.md`.

## Layout of this repository

```
git-memory/
├── README.md
├── LICENSE
├── matt-skill-sets.txt
├── skills/
│   └── setup-git-memory/     # the installer skill
└── scaffold/                 # bytes copied into targets
    ├── AGENTS.md
    ├── CONTEXT.md
    ├── docs/
    ├── templates/
    ├── scripts/check-memory.sh
    ├── .cursor/skills/
    ├── specs/
    └── .github/workflows/memory.yml
```

## Design notes

- **Upstream owns the craft** (grill, TDD, review axes). **The target repo owns placement** (`Stage:` line, paths, test commands). ADR-shaped write-up of that split is in the originating project's `docs/adr/0014-…`.
- Vendored skill bytes are pinned with `.agents/skills.sha256` after install so local edits fail the checker instead of vanishing on `npx skills update`.
- Empty product folders stay thin on purpose — see growth rule in `scaffold/docs/memory.md`.
