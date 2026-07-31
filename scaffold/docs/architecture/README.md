# Architecture

Module boundaries and dependency direction live here. Create `boundaries.md` (and other files) when the first real boundary decision lands — do not invent empty structure ahead of content. See [`docs/memory.md`](../memory.md).

Work that decides or moves a boundary, a seam or a dependency direction is
`Type: architecture`, whether it is a spec, a ticket or an ADR —
[`../method/work-types.md`](../method/work-types.md). Use the deep-module vocabulary
(module, interface, seam, adapter, depth) from the vendored `codebase-design` skill
when naming what a boundary is doing, so a review and a design document describe it
the same way.

What this layer forbids is restated as a checkable line under
[`../../rules/`](../../rules/) citing the decision it comes from. The reasoning
itself stays in [`../adr/`](../adr/): a boundary document that argues its own case
is one nobody rereads, and the argument is what an ADR is for.
