---
name: update-git-memory
description: Update an existing git-memory installation from upstream without silently overwriting project-owned memory or local skill edits.
disable-model-invocation: true
---

# Update git memory

Bring an existing git-memory project up to date. This is an explicit,
confirmation-driven update, not a blind scaffold overwrite.

## Preconditions

- Run from the root of a project that already contains `docs/memory.md` and
  `scripts/check-memory.sh`.
- Use `https://github.com/friofry/git-memory.git` unless the user explicitly
  supplies another git-memory remote or local clone.
- Do not run Matt's `/setup-matt-pocock-skills`.

If the preconditions do not hold, stop and recommend `/setup-git-memory`.

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
- `templates/`;
- `scripts/check-memory.sh`;
- `.github/workflows/memory.yml`.

Never treat `CONTEXT.md`, `context.md`, feature specs, ADRs, domain docs,
architecture docs, rules, `.scratch/`, or project test commands as replaceable
seed content.

## 3. Confirm the update

Recommend:

1. add every missing upstream file;
2. keep every differing existing file unchanged unless a specific upstream
   change is required;
3. review and merge differing infrastructure files one by one;
4. refresh vendored Matt skills only if the user wants that in the same update.

Show the file lists and wait for confirmation before writing. Do not reduce this
to a repository-wide `cp`, `rsync --delete`, or force checkout.

## 4. Apply

Copy confirmed missing files with their upstream bytes and modes. For an
existing differing file, first show the relevant diff, then make only the merge
the user confirmed.

The update must never:

- delete target files;
- overwrite a differing file silently;
- edit files under `.agents/skills/` by hand;
- replace project memory with empty scaffold stubs;
- replace project-specific commands in `AGENTS.md`;
- change feature `Status:` or `Stage:`.

If Matt skills were included in the confirmed scope, update them through their
package manager:

```bash
npx skills@latest update
```

## 5. Verify

Run:

```bash
chmod +x scripts/check-memory.sh
./scripts/check-memory.sh --fix
```

Then run any additional documentation checks required by `AGENTS.md`. Report
exactly which files were added, merged, skipped, and which checks passed or
failed. A failed check is not permission to rewrite project-owned files.

## 6. Finish

Delete the temporary clone. Tell the user that Cursor discovers newly added
skills at session start, so they should open a new session before invoking one.

Do not commit, push, or open a pull request unless the user requested it.

## Install or refresh this updater

The updater itself is distributed through the skills CLI:

```bash
npx skills@latest add friofry/git-memory -s update-git-memory -a universal -y
```

Later, `npx skills@latest update` refreshes the updater and vendored skills.
Run `/update-git-memory` after that to update copied git-memory scaffold files.
