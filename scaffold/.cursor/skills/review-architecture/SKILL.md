---
name: review-architecture
description: Review a diff or design against seams, dependency direction, ADRs and the active spec, and produce blocking and non-blocking findings. Use before merging a cross-cutting change.
---

# Architecture review

Judge where the seams are and which way the dependencies point, not whether the code
is correct — [`../review-change/SKILL.md`](../review-change/SKILL.md) does that.
Use before merging a cross-cutting change, on a `Type: architecture` node, or when
asked to review architecture.

## Vocabulary

Name what is wrong in the deep-module vocabulary from `.agents/skills/codebase-design/`
— **module**, **interface**, **seam**, **adapter**, **depth**, **leverage**,
**locality** — and use those words exactly. Do not substitute "component",
"service", "API" or "boundary": a finding written in one vocabulary and a design
document written in another describe the same change and cannot be compared.
[`../../../docs/architecture/README.md`](../../../docs/architecture/README.md) binds
that vocabulary to this repository's architecture layer.

An **interface** here is everything a caller must know to use the module correctly —
invariants, ordering, error modes, configuration, performance — not only the type
signature. Most architecture findings are about the part of the interface that has
no type.

## Where the boundaries are written down

Boundaries and dependency direction live under
[`../../../docs/architecture/`](../../../docs/architecture/), conventionally in
`boundaries.md` and `data-flow.md`.

**Those files may not exist yet.** The layer starts empty on purpose — see
[`../../../docs/architecture/README.md`](../../../docs/architecture/README.md) — and
a review is often the first time anyone needs them. When the file you want is
absent:

1. Reconstruct the intended boundary from the ADRs under
   [`../../../docs/adr/`](../../../docs/adr/), the constraints under
   [`../../../rules/`](../../../rules/), and the active spec's `design.md`.
2. Say in the artifact which document you reconstructed it from, so the next
   reviewer knows the boundary was inferred rather than read.
3. If the diff decides a boundary that nothing records, that is itself a finding:
   the decision belongs in an ADR before the code merges, and the checkable
   restatement belongs under `rules/` citing that ADR.

Do not create `boundaries.md` as part of a review. Writing the boundary and
approving the change that moves it in one pass is the conflict this stage exists to
avoid.

## Seam questions

Ask these of the diff or the design, in this order. Each one has a decisive answer.

1. **Where is the seam, and did it move?** Compare the module graph before and after
   the range. A moved seam is `Type: architecture` and probably wants an ADR; an
   unchanged graph with a changed contract across one edge is `interface` —
   [`../../../docs/method/work-types.md`](../../../docs/method/work-types.md).
2. **Does something actually vary across it?** One adapter means a hypothetical
   seam. Two means a real one. A seam introduced for a single implementation is
   interface a caller must learn in exchange for nothing.
3. **Did the interface get wider without getting deeper?** More methods or more
   parameters carrying the same behaviour is a shallower module: the caller learns
   more per unit of capability. Name it that way.
4. **Apply the deletion test.** If the module were deleted, does complexity vanish
   (it was a pass-through) or reappear across N callers (it was earning its keep)?
5. **Did the dependency direction reverse anywhere?** A stable layer that now
   references a volatile one is the same failure as
   [`../../../docs/memory.md`](../../../docs/memory.md) rule 2, in code.
6. **Did a source of truth move?** Two components now able to write the same fact is
   a defect that no test in the diff will catch.
7. **Can the change be localised further?** If the same outcome fits behind one
   existing seam, the wider version costs every future maintainer a decision.
8. **Is the test surface the interface?** If the new tests reach past the interface
   into the implementation, the module is probably the wrong shape.
9. **Is the diff written in the glossary's terms?** A new identifier that renames an
   existing `CONTEXT.md` term, or uses one of its `_Avoid_` synonyms, is drift and
   it compounds.
10. **Does the diff contradict an ADR, a rule, or the spec's `decisions.md`?** Name
    the address — `ADR:0012` — not "an earlier decision".
11. **Are the assumptions recorded?** Anything the design relies on and cannot prove
    belongs in the spec's Assumed or Unknown section, with what breaks if it is
    false.

## Required output

The shape in [`../../../templates/review.md`](../../../templates/review.md) — that
file is the home for it. Classify every finding under the two-value severity
vocabulary, blocking or non-blocking, defined at
[`M:review-blocking`](../../../docs/method/boilerplates/review-blocking.md) and
[`M:review-nonblocking`](../../../docs/method/boilerplates/review-nonblocking.md).
Put checks you want run but did not run yourself under Commands run, marked as
suggested, so nobody mistakes them for evidence.

## Stop and escalate when

- **An ADR conflict exists and the patch silently overrides it.** Blocking, always,
  and the address of the ADR goes in the finding.
- **A public schema, a durability guarantee, or an authorisation rule changed**
  without human approval notes. That is a human decision, not a review verdict.
- **The boundary the diff crosses is recorded nowhere.** Report it, do not invent
  the record.
- **You designed the seam under review.** Say so in the `Reviewer:` line rather than
  signing your own work.
- **Do not refactor, and do not move a `Stage:` line.** An architecture review
  produces findings; `review-change` owns the stage transition.
