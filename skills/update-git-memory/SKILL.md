---
name: update-git-memory
description: Update an existing git-memory installation from upstream, including the v1 to v2 migration, without silently overwriting project-owned memory or local skill edits.
disable-model-invocation: true
---

# Update git memory

Bring an existing git-memory project up to date. This is an explicit,
confirmation-driven update, not a blind scaffold overwrite.

## Preconditions

- Run from the root of a project that already contains `docs/memory.md` and
  `.git-memory-scripts/check-memory.sh`.
- Use `https://github.com/friofry/git-memory.git` unless the user explicitly
  supplies another git-memory remote or local clone.
- Do not run Matt's `/setup-matt-pocock-skills`.

If the preconditions do not hold, stop and recommend `/setup-git-memory`.

## v1 to v2 migration

A v1 install has the memory map, the 12 stages, the repo-authored skills and
`check-memory.sh`. v2 adds the method layer, addressing, packets, gates, three new
scripts and the GitHub layer. The migration is additive with **one** rename.

Detect v1: `docs/method/` is absent, or `.git-memory-scripts/git-memory-resolve.sh` is.

### New — safe to add whole, nothing in the target can conflict

| Path | What it is |
|------|------------|
| `.git-memory-scripts/lib/git-memory-lib.sh` | **Copy this first.** The only node-header reader. Every script sources it and exits 2 when it is missing, so a migration that takes `check-memory.sh` without it leaves a repository where nothing runs |
| `docs/method/` and `docs/method/boilerplates/` | Method truth: work types, addressing, gates, packet profiles, ticket and review skeletons |
| `.git-memory-scripts/git-memory-resolve.sh` | The only address parser in the system |
| `.git-memory-scripts/git-memory-graph.sh` | The work graph, printed to stdout |
| `.git-memory-scripts/git-memory-packet.sh` | The per-stage context envelope, printed to stdout |
| `.git-memory-scripts/git-memory-progress.sh` | The twelve stages as a checklist filled from evidence, and `--cheatsheet` |
| `.git-memory-scripts/test/run-tests.sh` | Fixture-based harness for every script above |
| `.cursor/skills/prepare-packet/` | Assembles the packet before a long turn |
| `.cursor/skills/plan-feature/` | Cuts an approved feature into tickets against its acceptance scenarios. Replaces upstream `/to-tickets` as the `plan` entry point |
| `CLAUDE.md` and `.claude/skills` | Claude Code support. `CLAUDE.md` is a pointer to `AGENTS.md` and carries no commands of its own; `.claude/skills` is a **symbolic link** to `.cursor/skills`, not a copy. Create it with `ln -sfn ../.cursor/skills .claude/skills`, and skip both if the project has no Claude Code users |
| `docs/agents/github-gates.md` | Which GitHub mechanism enforces which gate |
| `.github/workflows/delivery.yml` | The unfiltered workflow you make a required check |
| `.github/ISSUE_TEMPLATE/`, `.github/pull_request_template.md`, `.github/CODEOWNERS` | Intake and handoff forms |
| `templates/ticket.md`, `templates/active-context.md` | Node forms carrying the new header |

### Renamed — exactly one

Root `context.md` becomes `active-context.md`. On case-insensitive filesystems a
root `context.md` and `CONTEXT.md` are the same path, so one silently clobbers the
other on checkout and the loser is whichever tool wrote second.

```bash
git mv context.md active-context.md
```

Do this with `git mv` so history follows, then grep the repository for `context.md`
references and fix them in the same change. `check-memory.sh` fails on a root
`context.md` and prints this command; a v1 project that never created the file needs
nothing.

### Changed in place — review each, never bulk-copy

| Path | What changed |
|------|--------------|
| `.git-memory-scripts/check-memory.sh` | New checks, and a `--strict` flag. Take the upstream file whole unless the target edited it |
| `docs/memory.md` | Node headers, the method layer, projections, the `active-context.md` rule |
| `docs/agents/delivery-workflow.md` | Gate rows on the transitions; the Type-is-not-Stage section |
| `docs/agents/vendored-skills.md` | The `/wayfinder` type mapping and the packet binding |
| `AGENTS.md` | A `docs/method/` reading step and a `prepare-packet` pointer. Merge the sections; keep the project's commands untouched |
| `.gitignore` | `build/`, where projections are redirected |
| `.github/workflows/memory.yml` | Unchanged in intent; keeps its path filter, which is why it cannot be the required check |

### What the user decides, not you

1. **Whether to backfill node headers.** A v1 spec carries `Status:` and `Stage:` but
   no `ID:`, `Type:` or `Parent:`. A default `check-memory.sh` run stays green on it;
   only `--strict` reports it. Backfilling edits project-owned files, so propose it
   as separate work and let them say when. Do not add a `Type:` line by guessing what
   a feature was for.
2. **Whether to take the GitHub layer.** It ships inert. Nothing blocks until branch
   protection requires `delivery.yml`'s jobs — see `docs/agents/github-gates.md`.
3. **Who fills `delivery.yml` and `CODEOWNERS`.** Both ship with placeholders. A
   required check running a placeholder step is a green tick with no evidence behind
   it, and a reviewer trusts it.
4. **Whether the Matt skills are refreshed in the same update.** Usually a separate
   change; a vendored-byte refresh and a scaffold merge in one diff are hard to
   review.
5. **Whether to remove the six skills v2 no longer vendors.** `to-spec`,
   `to-tickets`, `implement`, `triage`, `handoff` and the frontier half of
   `wayfinder` were entry points for stages this scaffold now drives itself
   (`matt-skill-sets.txt`, "Not vendored, because this repository owns the
   stage"). **Leaving them installed breaks nothing** — they keep working, and
   `check-memory.sh` does not care. The cost is two skills claiming one stage,
   which is how an agent picks the wrong one.
   Removing them is safe only once `plan-feature` is in place, because
   `/to-tickets` is the v1 `plan` entry point. Propose it as a follow-up, never
   fold it into the same diff as the scaffold merge, and do not remove a skill
   the project has a local reason to keep.

State the migration as a plan in step 3 and get each of these four answered before
writing.

## 1. Fetch the current seed

Prefer a local clone supplied by the user. Otherwise clone the current default
branch into a fresh temporary directory:

```bash
tmp_dir="$(mktemp -d)"
git clone --depth 1 https://github.com/friofry/git-memory.git "$tmp_dir/git-memory"
seed="$tmp_dir/git-memory/scaffold"
```

Do not clone over an existing directory. Remove the temporary directory when
the update is complete.

## 2. Inventory before writing

Compare the target with the fetched `scaffold/` and report:

- missing upstream files, which are safe to add;
- existing files identical to upstream;
- existing files that differ, which may contain project-owned changes;
- target-only files, which must be left alone.

Pay particular attention to:

- `.cursor/skills/`;
- `docs/agents/`, `docs/memory.md`, and `AGENTS.md`;
- `docs/method/` — absent on a v1 install, and the largest single addition;
- `templates/`;
- `.git-memory-scripts/`, every `git-memory-*.sh`, `.git-memory-scripts/lib/` and `.git-memory-scripts/test/`;
- `.github/workflows/`, `.github/ISSUE_TEMPLATE/`, `.github/CODEOWNERS`.

Never treat `CONTEXT.md`, `active-context.md`, feature specs, ADRs, domain docs,
architecture docs, rules, `.scratch/`, or project test commands as replaceable
seed content.

## 3. Confirm the update

Recommend:

1. add every missing upstream file, including all of `docs/method/`;
2. keep every differing existing file unchanged unless a specific upstream
   change is required;
3. review and merge differing infrastructure files one by one;
4. refresh vendored Matt skills only if the user wants that in the same update.

Show the file lists and wait for confirmation before writing. Do not reduce this
to a repository-wide `cp`, `rsync --delete`, or force checkout.

## 4. Apply

Copy confirmed missing files with their upstream bytes and modes. For an
existing differing file, first show the relevant diff, then make only the merge
the user confirmed. New scripts need their executable bit: `chmod +x .git-memory-scripts/*.sh
.git-memory-scripts/test/*.sh`.

The update must never:

- delete target files;
- overwrite a differing file silently;
- edit files under `.agents/skills/` by hand;
- replace project memory with empty scaffold stubs;
- replace project-specific commands in `AGENTS.md`;
- change feature `Status:` or `Stage:`;
- add or rewrite an `ID:`, `Type:` or `Parent:` line on an existing node without
  the user asking for the backfill.

If Matt skills were included in the confirmed scope, update them through their
package manager:

```bash
npx skills@latest update
```

## 5. Verify

Run, in this order:

```bash
test -r .git-memory-scripts/lib/git-memory-lib.sh || echo 'MISSING: .git-memory-scripts/lib/git-memory-lib.sh'
chmod +x .git-memory-scripts/*.sh .git-memory-scripts/test/*.sh
./.git-memory-scripts/test/run-tests.sh
./.git-memory-scripts/check-memory.sh --fix
```

The first line is not ceremony. Every script sources that library and exits 2
without it, so a migration that copied the scripts but not `.git-memory-scripts/lib/` fails
on all four at once — and "exit 2, missing library" reads nothing like "your
memory is inconsistent". Check it before blaming the repository.

`run-tests.sh` proves the newly copied scripts run in this environment before any
of them is trusted; it uses throwaway fixtures under `mktemp -d` and writes nothing
into the project. Then run any additional documentation checks required by
`AGENTS.md`.

Run `./.git-memory-scripts/check-memory.sh --strict` once and show the output as a report. Its
warnings on a v1 repository are the backfill list from the migration section, not
work to do now.

Report exactly which files were added, merged, skipped, and which checks passed or
failed. A failed check is not permission to rewrite project-owned files.

## 6. Finish

Delete the temporary clone. Tell the user that Cursor discovers newly added
skills at session start, so they should open a new session before invoking one —
`prepare-packet` in particular is new in v2.

Do not commit, push, or open a pull request unless the user requested it.

## Install or refresh this updater

The updater itself is distributed through the skills CLI:

```bash
npx skills@latest add friofry/git-memory -s update-git-memory -a universal -y
```

Later, `npx skills@latest update` refreshes the updater and vendored skills.
Run `/update-git-memory` after that to update copied git-memory scaffold files.
