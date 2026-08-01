# CLAUDE.md

Claude Code reads this file; Cursor, Codex and the other harnesses read
[`AGENTS.md`](AGENTS.md). The project contract is one document and it lives
there.

**→ Read [`AGENTS.md`](AGENTS.md) first.**

Nothing else belongs in this file. A second copy of the build commands, the
layer map or the delivery stages would give a fact that already has one home a
second one, and the two would disagree the first time somebody edited only the
near copy — the exact failure [`docs/memory.md`](docs/memory.md) exists to
prevent.

`.claude/skills/` is a symbolic link to `.cursor/skills/`, so the repo-authored
skills load in Claude Code and in Cursor from the same bytes rather than from
two copies that drift. If your platform or Git configuration does not restore
symbolic links (`git config core.symlinks` reads `false` on Windows without
Developer Mode), replace the link with a copy and re-run
`./.git-memory-scripts/check-memory.sh` — it verifies the two directories hold the same
skills either way.
