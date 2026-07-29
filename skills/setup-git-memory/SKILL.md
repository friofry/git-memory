---
name: setup-git-memory
description: Install layered git memory, the 12-stage delivery workflow, repo-authored skills, and a Matt Pocock skill set into the current repository. Run once per project.
disable-model-invocation: true
---

# Setup git memory

Scaffold the portable memory system from this repository into the **current** project:

- Layered memory (`docs/memory.md`, specs, ADRs, `.scratch/`)
- 12-stage delivery workflow with a `Stage:` line per feature
- Repo-authored skills under `.cursor/skills/`
- Matt Pocock craft skills under `.agents/skills/` (via `npx skills`)
- `scripts/check-memory.sh` + optional CI workflow

This is a prompt-driven skill, not a silent dump. Explore, confirm, then write.

## Locate the seed

This skill ships with a `scaffold/` directory next to it (sibling of `skills/` at the repo root, or next to this skill folder). Resolve it once:

1. If `scaffold/docs/memory.md` exists relative to this skill's package root, use that.
2. Else if the user passed a path (clone of `git-memory`), use `<path>/scaffold/`.
3. Else clone: `git clone --depth 1 <git-memory-remote> /tmp/git-memory` and use `/tmp/git-memory/scaffold/`.

Never invent the seed files from memory — copy bytes from `scaffold/`.

## Process

### 1. Explore the target repo

Read what exists; do not assume:

- `git remote -v`, default branch
- `AGENTS.md` / `CLAUDE.md`
- `CONTEXT.md`, `docs/memory.md`, `docs/agents/`, `specs/`, `.scratch/`
- `.cursor/skills/`, `.agents/skills/`, `skills-lock.json`
- Existing test / CI commands (look in `package.json`, `Makefile`, `README`, workflows)

### 2. Ask (one section at a time; lead with the recommended answer)

**A — Scope.** Recommended: **full**.

- `full` — all repo skills + full Matt set (see `matt-skill-sets.txt`)
- `minimal` — orient / create-feature-spec / implement-feature / review-change + minimal Matt set

**B — Issue tracker.** Recommended: **local markdown** (already in the seed).

Only ask if exploration found a strong GitHub/Linear habit; otherwise write the local-markdown adapters from the seed.

**C — Merge policy for existing files.** Recommended: **keep local, fill gaps**.

- If `AGENTS.md` / `CONTEXT.md` / `docs/memory.md` already exist: do not overwrite; merge the "How work moves" / memory-map pointers into them.
- If they do not exist: copy from the seed.

**D — Matt install.** Recommended: **yes, now**.

If the environment cannot run `npx skills` (old Node, offline), copy instructions into the Done section and skip the install.

### 3. Confirm the plan

Show a short checklist: files to create, files to merge, Matt skills to install, CI workflow yes/no. Wait for approval.

### 4. Write

1. Copy missing paths from `scaffold/` into the target root (`docs/`, `templates/`, `scripts/check-memory.sh`, `.cursor/skills/`, `specs/README.md`, `.github/workflows/memory.yml`, `.gitignore` merge for `.scratch`, stubs under `docs/product|architecture|adr|domain|rules` as needed).
2. Ensure `AGENTS.md` has the memory-map and "How work moves" sections (create or merge).
3. Ensure `CONTEXT.md` exists (empty glossary stub is fine).
4. Fill the "Before finishing" command block in `AGENTS.md` from what exploration found.
5. Install Matt skills for the chosen set:

```bash
# build -s flags from matt-skill-sets.txt for minimal|full
npx skills@latest add mattpocock/skills -s <name> -s <name> ... -a universal -y
```

6. Run `chmod +x scripts/check-memory.sh` and `./scripts/check-memory.sh --fix`.
7. Commit on a branch if the user wants (ask); otherwise leave the working tree for them.

Do **not** run `/setup-matt-pocock-skills`. It would overwrite `docs/agents/issue-tracker.md`, `triage-labels.md`, and `domain.md`.

Do **not** edit files under `.agents/skills/` after install. Bindings go in `docs/agents/vendored-skills.md` (already in the seed).

### 5. Done

Tell the user:

- What was created / merged
- How to ask what happens next: `/ask-git-memory` or attach `.cursor/skills/ask-git-memory`
- How to resume work: `/orient-in-project` or attach `.cursor/skills/orient-in-project`
- How to start a feature: `/create-feature-spec` (or the skill path)
- How to refresh Matt skills later: `npx skills@latest update && ./scripts/check-memory.sh --fix`
- That product charter, glossary terms, architecture boundaries, and project hard constraints are still theirs to fill

If Matt install was skipped, paste the exact `npx skills add …` command for their chosen set.
