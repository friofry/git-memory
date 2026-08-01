# Short title of the decision

One dense paragraph: the context that forced a choice, what we decided, and why. Name the rejected alternatives in the same paragraph (`Rejected: …`) when the rejection is what a future reader will question. No Status / Context / Decision sections — every ADR under `docs/adr/` is written this way.

<!--
File name: docs/adr/NNNN-slug.md, one above the highest existing number.

Write an ADR only when all three hold: the decision is hard to reverse, it is
surprising without context, and it came out of a real trade-off.

Addressed as ADR:NNNN — four digits, zero-padded, one file per number, never
reused. ADR:12 written unpadded matches nothing, because the padding is what makes
the address a single unambiguous glob: ../docs/method/addressing.md. Specs, tickets
and spikes cite the number on their Refs: line instead of restating the decision.

An ADR carries no header block. No Type: line, because an ADR is always a decision
and an axis with one value stores nothing. No Status: and no Stage: either: the
layer is append-only, so a decision that turns out wrong becomes a new ADR naming
the one it supersedes, and the original stays readable as the reasoning someone
actually had at the time.

Do not markdown-link into specs/ or .scratch/ — an ADR is a stable layer and
.git-memory-scripts/check-memory.sh rejects links down into volatile ones. Naming a spec in
prose or backticks is fine.
-->
