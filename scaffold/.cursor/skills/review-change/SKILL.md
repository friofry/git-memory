---
name: review-change
description: Verify a change against acceptance, rules, glossary, and required test commands before handoff.
---

# Review change

Use at the end of an implementation session or when reviewing a PR.

## Procedure

1. Identify the active spec (if any) and read `acceptance.md`.
2. Diff against `rules/*.md` and `docs/architecture/boundaries.md`. For a full two-axis pass run `.agents/skills/code-review/`; its Standards axis reads `rules/`, `docs/architecture/boundaries.md`, `CONTEXT.md` and `AGENTS.md`, and its Spec axis reads the spec's `acceptance.md`.
3. Check glossary: no `_Avoid_` synonyms; new terms either unnecessary or added to `CONTEXT.md`.
4. Confirm tests exist for behaviour changes / bug fixes.
5. Run applicable commands from `AGENTS.md`.
6. Report gaps as blocking vs non-blocking.
7. Move the spec's `Stage:` to `rework` when a blocking finding stands, or to `ci` when the change is clean; once CI is green, to `acceptance` (`docs/agents/delivery-workflow.md`).

## Required output

The shape in [`templates/review.md`](../../../templates/review.md) — that file is
the home for it. Fill Acceptance coverage with the scenarios you verified, and
Commands run with the exact commands and their results.
