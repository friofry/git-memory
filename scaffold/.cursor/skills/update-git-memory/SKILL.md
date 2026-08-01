---
name: update-git-memory
description: Update an installed git-memory scaffold from upstream, including the v1 to v2 migration, without overwriting project-owned memory or local skill edits.
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

## 1. Fetch the current seed

Prefer a local clone supplied by the user. Otherwise clone the default branch into a
fresh temporary directory; do not clone over an existing one:

```bash
tmp_dir="$(mktemp -d)"
git clone --depth 1 https://github.com/friofry/git-memory.git "$tmp_dir/git-memory"
seed="$tmp_dir/git-memory/scaffold"
```

## 2. Inventory before writing

Compare the target with the fetched `scaffold/` and report four groups: missing
upstream files, safe to add; existing files identical to upstream; existing files
that differ and may carry project-owned changes; target-only files, which are left
alone. Pay particular attention to `.cursor/skills/`, `docs/agents/`,
`docs/memory.md`, `AGENTS.md`, `templates/`, `.git-memory-scripts/` and `.github/workflows/`.

Never treat `CONTEXT.md`, `active-context.md`, `context.md`, feature specs, ADRs,
domain docs, architecture docs, rules, `.scratch/`, or project test commands as
replaceable seed content.

## 3. Detect and report a v1 target

The target is on v1 if any of these hold: no `docs/method/` directory; a root
`context.md`; `.git-memory-scripts/` holding only `check-memory.sh`; specs whose headers carry
`Status:` and `Stage:` but no `ID:` or `Type:`. Say which of the four you observed,
then walk the user through this section before copying anything.

**What is new.** All additive; none of it changes the meaning of an existing
`Status:` or `Stage:` value.

| Addition | What it is | Where it lands |
|----------|-----------|----------------|
| Method layer | How work is typed, addressed, gated and packaged, addressable as `M:` refs | `docs/method/` |
| Node header | `ID:`, `Type:`, `Parent:`, `Children:`, `Blocked by:`, `Refs:` on specs, tickets and spike READMEs | existing node files |
| Three scripts | `git-memory-resolve.sh` (address to path), `git-memory-graph.sh` (the work graph), `git-memory-packet.sh` (the context envelope) | `.git-memory-scripts/` |
| Delivery workflow | Project tests, lint and typecheck, with no path filter, meant to be the required check | `.github/workflows/delivery.yml` |
| GitHub intake | Four issue forms, a pull request template carrying the handoff baton, `CODEOWNERS` | `.github/ISSUE_TEMPLATE/`, `.github/` |
| `prepare-packet` | The slash-only skill that assembles a stage's packet before a long turn | `.cursor/skills/prepare-packet/` |

None of the three new scripts writes into the repository, and nothing they produce
is committed — see "Projections" in `docs/memory.md`. Adding them cannot change
existing behaviour, so they are safe to take in full.

**What is renamed.** One file, and it is the only rename in the release. A root
`context.md` and `CONTEXT.md` are the same path on the macOS and Windows defaults,
so one silently clobbers the other on checkout:

```bash
git mv context.md active-context.md
```

Run it in the target repository, not in the seed. `.git-memory-scripts/check-memory.sh` fails on
a root `context.md` and prints this exact command, so the check tells the user the
same thing this skill does.

**What the user must decide.** Ask each of these and record the answer; none has a
safe default you may assume.

1. **Backfill node headers, or not yet?** A default `check-memory.sh` run stays
   green on a v1 repository — the missing `ID:`, `Type:` and `Parent:` lines are
   warnings under `--strict` only. Backfilling is a per-spec edit to project-owned
   files and is the user's call, feature by feature.
2. **Which workflow becomes the required check?** `delivery.yml`, not `memory.yml`.
   A path-filtered workflow that does not run reports success, so branch protection
   on `memory.yml` passes exactly the pull requests it never inspected —
   `docs/agents/github-gates.md`.
3. **Fill in `delivery.yml`'s commands?** It ships with the project commands
   commented out. Until they are filled from `AGENTS.md`, the required check proves
   nothing.
4. **Rewrite `/wayfinder` type aliases?** `Type: grilling` becomes `research` and
   `Type: task` becomes `implementation`. The aliases are deliberately not in the
   checker's accepted set, so any ticket carrying one fails until it is edited —
   `docs/method/work-types.md`.
5. **Adopt `CODEOWNERS` and the issue forms?** Both change who is asked to review
   and how requests arrive. Neither is a documentation change.

**What is never touched.** The migration adds files and renames one. It does not
rewrite `CONTEXT.md`, any spec, any ADR, any domain or architecture document, any
rule, anything under `.scratch/`, or the project commands in `AGENTS.md`. If a step
seems to require editing one of those, stop and ask — that is the boundary between
scaffold and project, and this skill does not cross it.

## 4. Confirm the update

Recommend, in this order: add every missing upstream file; keep every differing
existing file unchanged unless a specific upstream change is required; review and
merge differing infrastructure files one by one; refresh vendored Matt skills only
if the user wants that in the same update.

Show the file lists and wait for confirmation before writing. Do not reduce this to a
repository-wide `cp`, `rsync --delete`, or force checkout.

## 5. Apply

Copy confirmed missing files with their upstream bytes and modes. For an existing
differing file, first show the relevant diff, then make only the merge the user
confirmed.

The update must never delete target files, overwrite a differing file silently, edit
files under `.agents/skills/` by hand, replace project memory with empty scaffold
stubs, replace project-specific commands in `AGENTS.md`, or change a feature's
`Status:` or `Stage:`.

If Matt skills were in the confirmed scope, update them through their package
manager:

```bash
npx skills@latest update
```

## 6. Verify

```bash
chmod +x .git-memory-scripts/*.sh
./.git-memory-scripts/check-memory.sh --fix
./.git-memory-scripts/check-memory.sh --strict
```

The default run must be green before you report success. Treat `--strict` output as
the backfill worklist from decision 1, not as a failure to fix now. Then run any
additional documentation checks required by `AGENTS.md`, and report exactly which
files were added, merged and skipped, and which checks passed or failed.

## 7. Finish

Delete the temporary clone. Tell the user that Cursor discovers newly added skills at
session start, so they should open a new session before invoking `prepare-packet` or
any other skill this update added.

## Stop conditions

- **A failed check is not permission to rewrite project-owned files.** Report the
  failure and name the file that would have to change.
- **Never overwrite a differing file silently**, never `rsync --delete`, never force
  checkout, and never delete a target file.
- **Never edit a vendored skill under `.agents/skills/` by hand.** The next
  `npx skills update` reverts it without a diff; `.agents/skills.sha256` exists so
  the edit fails a check instead of vanishing.
- **Never change a feature's `Status:` or `Stage:`**, and never run
  `git mv context.md active-context.md` without saying you are about to.
- **Do not commit, push, or open a pull request** unless the user asked for it.
- **If the target is not a git-memory installation at all**, stop and recommend
  `/setup-git-memory`. This skill merges into an existing scaffold; it cannot create
  one.

## Install or refresh this updater

```bash
npx skills@latest add friofry/git-memory -s update-git-memory -a universal -y
```

Later, `npx skills@latest update` refreshes the updater and the vendored skills. Run
`/update-git-memory` after that to update copied git-memory scaffold files.
