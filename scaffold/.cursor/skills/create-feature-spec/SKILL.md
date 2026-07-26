---
name: create-feature-spec
description: Create a new feature folder under specs/ from templates, link .scratch tickets, and keep one-home memory rules.
---

# Create feature spec

Use when starting a substantial change (more than a tiny bugfix).

## Inputs

- Feature slug (kebab-case)
- Outcome in one sentence
- Optional related spike / ADR paths

## Procedure

1. Pick the next free number under `specs/` (`001`, `002`, …).
2. Copy sections from `templates/feature-spec.md` into:
   - `specs/<NN>-<slug>/spec.md` — the only file carrying `Status:` and `Stage:`; start at `draft` / `request`, and move the stage as you go: `research` while inventorying with `.agents/skills/research/`, `spec` once the four files hold content
   - `specs/<NN>-<slug>/design.md`
   - `specs/<NN>-<slug>/acceptance.md`
   - `specs/<NN>-<slug>/decisions.md`
3. Fill **Outcome**, **In/Out of scope**, **Known / Assumed / Unknown** before implementation tickets.
4. Write acceptance as Given/When/Then scenarios (see `templates/feature-spec.md`). For the content itself — user stories, seams, implementation and testing decisions — follow `.agents/skills/to-spec/`, and route its sections into our four files per `docs/agents/vendored-skills.md`.
5. If implementation tickets are needed, create `.scratch/<slug>/` with `spec.md` pointing at the `specs/` folder and `issues/NN-*.md` per `docs/agents/issue-tracker.md`.
6. Link product/domain/ADR docs instead of copying paragraphs.
7. If grill produced new terms, ensure they landed in `CONTEXT.md`.
8. Hand the spec to the human for the `approval` stage — set `Stage: approval` when it is ready to read (`docs/agents/delivery-workflow.md`).

## Stop and escalate when

- Change contradicts an ADR
- Spike is still unresolved for a blocking Unknown

## Output

- Populated `specs/<NN>-<slug>/` tree with `Status:` and `Stage:` on `spec.md`
- Optional `.scratch/<slug>/` tickets
