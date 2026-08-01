---
name: setup-git-memory
description: Install layered git memory, the delivery workflow, the method layer, the tool scripts and a Matt Pocock skill set into the current repository. Run once per project.
disable-model-invocation: true
---

# Setup git memory

Scaffold the portable memory system from this repository into the **current**
project, then prove the tooling runs here before you report success.

What lands, in layers:

| Layer | Paths | Owns |
|-------|-------|------|
| Memory map | `docs/memory.md`, `CONTEXT.md`, `docs/adr/`, `specs/`, `.scratch/` | Where each fact lives, and the one-home rule |
| Delivery | `docs/agents/delivery-workflow.md` | The 12 stages and the `Stage:` line |
| Method | `docs/method/` + `docs/method/boilerplates/` | Types, addresses, gates, packet profiles, `M:` refs |
| Tools | `.git-memory-scripts/check-memory.sh`, `git-memory-resolve.sh`, `git-memory-graph.sh`, `git-memory-packet.sh`, `git-memory-progress.sh`, `.git-memory-scripts/lib/`, `.git-memory-scripts/test/` | Resolution, projection, enforcement |
| Skills | `.cursor/skills/` (repo-authored) · `.agents/skills/` (vendored Matt) | Repeatable procedures |
| GitHub | `.github/workflows/`, `.github/ISSUE_TEMPLATE/`, `pull_request_template.md`, `CODEOWNERS` | Intake and the checks that block a merge |

This is a prompt-driven skill, not a silent dump. Explore, ask, confirm, write,
prove. Detail is not restated here: once the seed is copied, `docs/memory.md`,
`docs/method/README.md` and `docs/agents/github-gates.md` are the homes for the
rules this skill only installs.

## Locate the seed

This skill ships with a `scaffold/` directory. Resolve it once:

1. If `scaffold/docs/memory.md` exists relative to this skill's package root, use that.
2. Else if the user passed a path (a clone of `git-memory`), use `<path>/scaffold/`.
3. Else clone: `git clone --depth 1 https://github.com/friofry/git-memory.git /tmp/git-memory`
   and use `/tmp/git-memory/scaffold/`.

Never invent the seed files from memory — copy bytes from `scaffold/`. A
hand-written `check-memory.sh` is the failure that ends this install: it passes,
it checks nothing, and nobody discovers that for a month.

## 1. Explore the target repo

Read what exists; do not assume:

- `git remote -v`, the default branch, whether branch protection is already on
- `AGENTS.md` / `CLAUDE.md`
- `CONTEXT.md`, `context.md`, `active-context.md`, `docs/memory.md`, `docs/agents/`,
  `docs/method/`, `specs/`, `.scratch/`
- `.cursor/skills/`, `.agents/skills/`, `skills-lock.json`
- `.github/workflows/`, `.github/CODEOWNERS`
- The real lint / typecheck / test commands (`package.json`, `Makefile`, `justfile`,
  `pyproject.toml`, existing workflows, `README.md`)

If `docs/memory.md` already exists, this project has git-memory. Stop and
recommend `/update-git-memory` instead.

## 2. Ask — one section at a time, recommended answer first

**A — Scope.** Recommended: **full**.

| Answer | Repo skills | Matt set |
|--------|-------------|----------|
| `full` | all of `.cursor/skills/` | the `full` list in `matt-skill-sets.txt` |
| `minimal` | `orient-in-project`, `prepare-packet`, `create-feature-spec`, `implement-feature`, `review-change` | the `minimal` list |

**B — Method layer (`docs/method/`).** Recommended: **yes**.

It is additive and portable: eleven work types, six address families, seven gates,
six packet profiles, and the boilerplates that stop process prose from being pasted
into `CONTEXT.md`. Decline it only if the user already runs a documented method they
do not intend to replace — and say plainly that without it, `Type:`, `Refs:` and
every `M:` address in the shipped skills resolve to nothing, so
`./.git-memory-scripts/check-memory.sh` will fail on the first node header written.

**C — GitHub intake layer (`.github/`).** Recommended: **yes**, separately.

Two workflows (`memory.yml` path-filtered and advisory, `delivery.yml` unfiltered
and requirable), four issue forms, the PR template, and `CODEOWNERS`. Everything in
it ships **inert** — it blocks nothing until a human turns on branch protection.
Decline it on a repository that is not on GitHub, or where someone else owns CI;
take it everywhere else, because `M:gate-ci` has no other enforcement.

Ask separately whether to overwrite an existing `.github/workflows/*.yml`. Default:
no. Add the new files beside the old ones and list the collisions.

**D — Issue tracker.** Recommended: **local markdown** (already in the seed).

Ask only if exploration found a strong GitHub Issues or Linear habit. The answer
does not change what is written: `specs/` and `.scratch/` stay the writable truth,
issues stay intake. The reasoning is in `docs/agents/issue-tracker.md`.

**E — Merge policy for existing files.** Recommended: **keep local, fill gaps**.

- `AGENTS.md`, `CONTEXT.md`, `README.md` already exist: never overwrite. Merge in the
  memory-map pointers and the "How work moves" section.
- They do not exist: copy from the seed.

**F — Matt install.** Recommended: **yes, now**.

If the environment cannot run `npx skills` (old Node, no network), skip it and paste
the exact command into the Done report.

## 3. Confirm the plan

Show one checklist before writing anything: files to create, files to merge, the
`.github/` decision, the Matt skills to install, and the commands you will run to
prove it. Wait for approval. Do not start writing while a question is open.

## 4. Write

1. Copy the missing paths from `scaffold/` into the target root: `docs/`,
   `templates/`, `.git-memory-scripts/`, `.cursor/skills/`, `specs/README.md`, `.scratch/README.md`,
   `rules/README.md`, and `.github/` if the user took it in step 2C.
2. Merge `.gitignore`: the `.scratch/` re-include lines and `build/`. `build/` is
   where the graph and packet projections get redirected, and a committed projection
   is a second copy of facts the node headers already carry.
3. Ensure `AGENTS.md` carries the memory map, "How work moves", and the
   "Before finishing" command block. Fill that block from what exploration found in
   step 1 — it is the only home for this project's commands.
4. Ensure `CONTEXT.md` exists. An empty glossary stub is correct; inventing terms is
   not.
5. **Human direction is `active-context.md` at the repo root**, seeded from
   `templates/active-context.md`. Never create a root `context.md`: on macOS and
   Windows it is the same path as `CONTEXT.md`, one silently clobbers the other on
   checkout, and `./.git-memory-scripts/check-memory.sh` fails on it by design. If exploration
   found a root `context.md`, run `git mv context.md active-context.md` and say so.
6. Install the Matt skills for the chosen set:

   ```bash
   # one -s per name, read from matt-skill-sets.txt for minimal|full
   npx skills@latest add mattpocock/skills -s <name> -s <name> ... -a universal -y
   ```

7. Link the Claude Code skills directory, unless nobody here uses Claude Code:

   ```bash
   mkdir -p .claude && ln -sfn ../.cursor/skills .claude/skills
   ```

   A link and not a copy: Claude Code reads `.claude/skills/`, every other
   harness reads `.cursor/skills/`, and two directories holding the same nine
   skills drift the first time one side is edited. `CLAUDE.md` arrives with the
   seed and is a pointer to `AGENTS.md` carrying no commands of its own.

   Some seed channels cannot carry a symbolic link — the Claude Web archive
   strips it on purpose, because zip stores what a link points at. If the link is
   absent after copying, this command is what creates it. Where the filesystem
   refuses links at all (Windows without Developer Mode), copy `.cursor/skills`
   to `.claude/skills` instead and say so in the report:
   `./.git-memory-scripts/check-memory.sh` accepts a copy and tells the owner when the two
   sides stop matching.

8. Make the tool layer executable and record the vendored bytes:

   ```bash
   chmod +x .git-memory-scripts/*.sh .git-memory-scripts/test/*.sh
   ./.git-memory-scripts/check-memory.sh --fix
   ```

## 5. Prove the tooling in this environment

The scripts are `bash` and portable by policy, but the environment is the thing you
cannot read off a file. Run the harness once, here, before reporting success:

```bash
./.git-memory-scripts/test/run-tests.sh
```

It builds throwaway fixture repositories under `mktemp -d`, exercises the resolver,
the graph, the packet assembler and every check, and prints `ok` / `not ok` lines
with a final count. It writes nothing into the project and finishes in under
30 seconds.

Then confirm the three tools answer on this repository, not only on fixtures:

```bash
./.git-memory-scripts/git-memory-resolve.sh M:gate-approval   # prints docs/method/gates.md#...
./.git-memory-scripts/git-memory-graph.sh --format md         # prints; nothing is written
./.git-memory-scripts/check-memory.sh                         # must exit 0
```

If `run-tests.sh` reports a failure, **stop and report the failing line verbatim**.
Do not edit the harness, do not skip the check, and do not report the install as
complete. A tool layer that does not run here is a set of commands the project's
documentation now promises and cannot deliver.

`./.git-memory-scripts/check-memory.sh --strict` is a report, not a gate, on a repository whose
specs predate this install. Run it once, show the warnings, and leave them.

## 6. Report

Tell the user, in this order:

- What was created, what was merged, what was left alone
- The `run-tests.sh` result and the `check-memory.sh` exit status
- How to route work: `/ask-git-memory` (what next), `/orient-in-project` (where are
  we), `/prepare-packet` (before a long turn), `/create-feature-spec` (start a
  feature)
- That Cursor discovers skills at session start, so a new session is needed before a
  freshly installed skill can be invoked
- How to refresh later: `npx skills@latest add friofry/git-memory -s update-git-memory
  -a universal -y`, then `/update-git-memory`; and
  `npx skills@latest update && ./.git-memory-scripts/check-memory.sh --fix` for the Matt skills

Then list **what is still theirs to fill**. Nothing below can be inferred from the
repository, and every item is a control that reads as though it works until someone
tests it:

| Still empty | Why it matters |
|-------------|----------------|
| `docs/product/charter.md` | Why the product exists; every spec's Outcome is judged against it |
| `CONTEXT.md` | The glossary. Grill and domain-modeling write here; agents obey `_Avoid_` |
| `docs/architecture/`, `rules/` | Boundaries and checkable constraints — the Standards axis of every review |
| `AGENTS.md` "Before finishing" | The project's real commands. A skill that hard-codes one drifts the day the toolchain moves |
| `.github/workflows/delivery.yml` | The same commands again. It ships with placeholder steps that only print a warning: a required check that runs nothing is a green tick with no evidence behind it |
| `.github/CODEOWNERS` | Replace `@your-org/memory-owners` with a real team that has write access, or GitHub ignores the rule and tells nobody |
| `.github/ISSUE_TEMPLATE/config.yml` | Replace `OWNER/REPO`; a contact link needs an absolute URL |
| Branch protection | Require `delivery.yml`'s jobs, strict, plus code-owner review. Until then the whole `.github/` layer is a suggestion — see `docs/agents/github-gates.md` |

## Never

- **Never run `/setup-matt-pocock-skills`.** Its output *is* the seed's
  `docs/agents/issue-tracker.md`, `triage-labels.md` and `domain.md`. Running it
  overwrites answers this install already gave.
- **Never edit a file under `.agents/skills/`.** The bytes are pinned in
  `.agents/skills.sha256`; an edit fails the checker and the next
  `npx skills update` reverts it without a diff. Repo-specific instruction goes in
  `docs/agents/vendored-skills.md`.
- **Never overwrite `CONTEXT.md`, a spec, an ADR, a domain doc, `rules/`, or the
  commands in `AGENTS.md`.** Those are project-owned. The seed supplies forms, not
  content.
- **Never make `memory.yml` a required check.** It is path-filtered, and a skipped
  job reports success, so it would pass on exactly the changes it never inspected.
- **Never commit unless the user asked.** Leave the working tree; offer a branch.
