---
name: review-architecture
description: Review a diff or design against boundaries, ADRs, glossary, and the active spec; produce blocking vs non-blocking findings.
---

# Architecture review

Use before merging a cross-cutting change or when asked to review architecture.

Use the deep-module vocabulary from `.agents/skills/codebase-design/` when naming what is wrong with a seam.

## Review questions

1. Which module boundaries changed ([`docs/architecture/boundaries.md`](../../../docs/architecture/README.md))?
2. Did dependency direction change?
3. Did a source of truth move ([`docs/architecture/data-flow.md`](../../../docs/architecture/README.md))?
4. Is there a new shared abstraction that should be an ADR?
5. Are assumptions written in the active spec `decisions.md` / `Unknown`?
6. Does the diff contradict `CONTEXT.md` or an ADR?
7. Can the change be localized further?
8. Does behaviour match `specs/.../acceptance.md`?
9. Are [`rules/`](../../../rules/) violated?

## Required output

The shape in [`templates/review.md`](../../../templates/review.md) — that file is
the home for it. Put the checks you want run next under Commands run, marked as
suggested when you did not run them yourself.

## Stop and escalate when

- ADR conflict exists and the patch silently overrides it
- Public schema / durability / authz changed without human approval notes
