#!/usr/bin/env python3
"""Adapt a staged SKILL.md for Claude Web upload packaging."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


def truncate_desc(desc: str, limit: int) -> tuple[str, bool]:
    if len(desc) <= limit:
        return desc, False
    cut = limit - 1
    chunk = desc[:cut]
    if " " in chunk:
        chunk = chunk.rsplit(" ", 1)[0]
    return chunk.rstrip(".,;:") + "…", True


def adapt(path: Path, skill_name: str, kind: str, do_adapt: bool, desc_max: int) -> None:
    text = path.read_text(encoding="utf-8")
    m = re.match(r"^---\n(.*?)\n---\n(.*)$", text, re.S)
    if not m:
        raise SystemExit(f"No YAML frontmatter in {path}")
    fm, body = m.group(1), m.group(2)

    fm_lines: list[str] = []
    desc: str | None = None
    for line in fm.splitlines():
        if line.startswith("disable-model-invocation:"):
            continue
        if line.startswith("description:"):
            desc = line[len("description:") :].strip()
            continue
        fm_lines.append(line)

    if desc is None:
        raise SystemExit(f"Missing description in {path}")

    desc, truncated = truncate_desc(desc, desc_max)
    if truncated:
        print(
            f"warn: truncated description for {skill_name}: → {len(desc)} chars",
            file=sys.stderr,
        )
    fm_lines.append(f"description: {desc}")

    if do_adapt:
        body = re.sub(
            r"`?\.agents/skills/([a-z0-9-]+)/`?",
            r"the uploaded `\1` skill",
            body,
        )
        body = re.sub(
            r"`?\.cursor/skills/([a-z0-9-]+)(?:/SKILL\.md)?`?",
            r"the uploaded `\1` skill",
            body,
        )

        if kind == "repo" and skill_name == "setup-git-memory":
            body = body.replace(
                "This skill ships with a `scaffold/` directory next to it "
                "(sibling of `skills/` at the repo root, or next to this skill folder). "
                "Resolve it once:\n\n"
                "1. If `scaffold/docs/memory.md` exists relative to this skill's package root, use that.\n"
                "2. Else if the user passed a path (clone of `git-memory`), use `<path>/scaffold/`.\n"
                "3. Else clone: `git clone --depth 1 <git-memory-remote> /tmp/git-memory` "
                "and use `/tmp/git-memory/scaffold/`.\n",
                "This Claude Web package embeds `scaffold/` inside this skill folder. "
                "Resolve it once:\n\n"
                "1. Prefer `scaffold/docs/memory.md` next to this `SKILL.md` (bundled).\n"
                "2. Else if the user passed a path (clone of `git-memory`), use `<path>/scaffold/`.\n"
                "3. Else clone: `git clone --depth 1 https://github.com/friofry/git-memory.git "
                "/tmp/git-memory` and use `/tmp/git-memory/scaffold/`.\n",
            )

            old_install = (
                "5. Install Matt skills for the chosen set:\n\n"
                "```bash\n"
                "# build -s flags from matt-skill-sets.txt for minimal|full\n"
                "npx skills@latest add mattpocock/skills -s <name> -s <name> ... -a universal -y\n"
                "```\n"
            )
            new_install = (
                "5. Matt skills (Claude Web): do **not** run `npx skills`. Confirm the user "
                "uploaded and enabled the Matt ZIP set from this package (`minimal` or `full`). "
                "Companion craft skills compose by name once enabled.\n"
            )
            if old_install in body:
                body = body.replace(old_install, new_install)
            else:
                print(
                    f"warn: Matt install block not found in {skill_name}; skipping rewrite",
                    file=sys.stderr,
                )

            body = body.replace(
                "- Matt Pocock craft skills under `.agents/skills/` (via `npx skills`)\n",
                "- Matt Pocock craft skills as separately uploaded Claude skills (same package)\n",
            )
            body = body.replace(
                "**D — Matt install.** Recommended: **yes, now**.\n\n"
                "If the environment cannot run `npx skills` (old Node, offline), "
                "copy instructions into the Done section and skip the install.\n",
                "**D — Matt skills on Claude Web.** Recommended: **already uploaded**.\n\n"
                "Confirm the Matt ZIP set from this package is enabled. If not, list missing "
                "names from MANIFEST.txt and stop before writing the scaffold.\n",
            )
            body = body.replace(
                "- How to refresh Matt skills later: `npx skills@latest update && ./scripts/check-memory.sh --fix`\n",
                "- How to refresh Matt skills later: re-run `scripts/package-claude-web-skills.sh` "
                "and re-upload the Matt skill ZIPs\n",
            )
            body = body.replace(
                "If Matt install was skipped, paste the exact `npx skills add …` command for their chosen set.\n",
                "If Matt ZIPs are not enabled yet, list the missing names from MANIFEST.txt and stop.\n",
            )

            note = (
                "\n## Claude Web notes\n\n"
                "- Expect a Project / Code execution workspace with a git checkout.\n"
                "- Upload every ZIP under the package `skills/` folder and enable them.\n"
                "- Repo wiring skills compose with Matt craft skills by name when all are enabled.\n"
            )
            if "## Claude Web notes" not in body:
                body = body.rstrip() + "\n" + note

    path.write_text("---\n" + "\n".join(fm_lines) + "\n---\n" + body, encoding="utf-8")


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("skill_md", type=Path)
    p.add_argument("skill_name")
    p.add_argument("kind", choices=("repo", "matt"))
    p.add_argument("--adapt", action="store_true")
    p.add_argument("--desc-max", type=int, default=200)
    args = p.parse_args()
    adapt(args.skill_md, args.skill_name, args.kind, args.adapt, args.desc_max)


if __name__ == "__main__":
    main()
