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
| `skills/update-git-memory/` | Safe updater for existing projects (`/update-git-memory`) |
| `matt-skill-sets.txt` | `minimal` and `full` lists for `npx skills add` |

Inside `scaffold/`:

- `docs/memory.md` — layer map and one-home rules
- `docs/agents/delivery-workflow.md` — stages `request` … `memory`
- `docs/agents/vendored-skills.md` — how Matt skills bind to this layout
- `.cursor/skills/` — `ask-git-memory`, `update-git-memory`, `orient-in-project`, `create-feature-spec`, `implement-feature`, `review-change`, `review-architecture`
- `scripts/check-memory.sh` — enforceable consistency (status, stage, vendored bytes, ticket labels)
- `.github/workflows/memory.yml` — runs the checker on markdown PRs
- Templates for specs, ADRs, reviews, spikes

## Install into another project

### A. Agent skill (recommended)

1. Add this skill to the target project or your user skills:

```bash
npx skills@latest add friofry/git-memory -s setup-git-memory -a universal -y

# or copy from a clone:
# cp -R skills/setup-git-memory <target>/.cursor/skills/
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
| What should happen next? | `/ask-git-memory` |
| Where are we? | `/orient-in-project` |
| New feature | `/create-feature-spec` → human approval → `/to-tickets` → `/implement-feature` |
| Review | `/review-change` (drives vendored `/code-review`) |
| Refresh git-memory scaffold | Install/refresh the updater with `npx skills@latest add friofry/git-memory -s update-git-memory -a universal -y`, then run `/update-git-memory` |
| Refresh Matt skills | `npx skills@latest update && ./scripts/check-memory.sh --fix` |

`npx skills@latest update` refreshes skills installed through the CLI, but it
does not overwrite scaffold files already copied into a project. The
`/update-git-memory` skill compares the current upstream scaffold, adds missing
files, and asks before merging any existing file that differs.

Do **not** run Matt's `/setup-matt-pocock-skills` on a project that already has this seed — it would overwrite `docs/agents/issue-tracker.md`, `triage-labels.md`, and `domain.md`.

Do **not** edit files under `.agents/skills/`. Bindings and conflicts live in `docs/agents/vendored-skills.md`.

### How a human runs a feature

You say **what** and answer **yes/no**. The agent does **how** and writes
evidence into Git. Contracts and TDD live in files and commands, not in chat.

1. **Request** — state the outcome in one sentence. Agent: `/grill-with-docs` →
   `/create-feature-spec` (folder under `specs/` after setup).
2. **Approval** — you read `spec` / `design` / `acceptance` and approve meaning
   and architecture. Without this, work stays at `approval`.
3. **Build** — you say "plan and implement". Agent: `/to-tickets` →
   `/implement-feature` (drives `/tdd`) → checks from `AGENTS.md` →
   `/review-change`.
4. **Acceptance** — you check CI + demo against `acceptance.md`. Say "accept";
   the agent writes memory back and sets `implemented`.

Human-required gates: request, approval, acceptance (plus answers during grill).
Everything else is agent-driven by stage.

One prompt that starts it:

> New feature: <outcome>. Follow the delivery workflow: grill → spec → stop at
> approval. After I OK — tickets, TDD, checks, review. Do not move `Stage:`
> without evidence.

Full 12-stage table: [`scaffold/docs/agents/delivery-workflow.md`](scaffold/docs/agents/delivery-workflow.md).

### Versus vanilla Matt Pocock skills

Matt's skills are the craft. This repo adds a process that survives the end of
a chat session.

| | Vanilla Matt | This repo (after setup) |
|--|--|--|
| Spec | One `/to-spec` document | Four files under `specs/` + `Status:` / `Stage:` |
| "Where is the feature?" | Chat / tracker / memory | `Stage:` line in Git; `/orient-in-project` checks evidence |
| Tickets | `.scratch/` or GitHub Issues | Same local markdown + label vocabulary + `check-memory.sh` |
| TDD / review | `/tdd`, `/code-review` | Same craft; entry via `implement-feature` / `review-change` |
| Contracts | "Read CONTEXT / ADR" | Plus enforceable one-home checks |
| Setup | `/setup-matt-pocock-skills` | Adapters already in the seed — do not re-run Matt setup |
| Autonomy | You hold the process in your head | Twelve stages in Git; human gates are request / approval / acceptance |

## Layout of this repository

```
git-memory/
├── README.md
├── LICENSE
├── matt-skill-sets.txt
├── skills/
│   ├── setup-git-memory/     # the installer skill
│   └── update-git-memory/    # the safe updater skill
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

- **Upstream owns the craft** (grill, TDD, review axes). **The target repo owns placement** (`Stage:` line, paths, test commands). ADR-shaped write-up of that split is ADR 0016 in [`friofry/starcraft-benchmark`](https://github.com/friofry/starcraft-benchmark).
- Vendored skill bytes are pinned with `.agents/skills.sha256` after install so local edits fail the checker instead of vanishing on `npx skills update`.
- Empty product folders stay thin on purpose — see growth rule in `scaffold/docs/memory.md`.
