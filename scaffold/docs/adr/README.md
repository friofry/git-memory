# Architecture Decision Records

Append-only. Format: [`templates/adr.md`](../../templates/adr.md). Number `NNNN-slug.md` one above the highest existing file.

Addressed as `ADR:NNNN` — four digits, zero-padded, one file per number, never
reused. `ADR:12` written unpadded resolves to nothing
([`../method/addressing.md`](../method/addressing.md)). Specs, tickets and spikes
carry the number on their `Refs:` line instead of restating what was decided.

An ADR carries no node header. No `Type:` line, because an ADR is always a decision
and an axis with one value stores nothing; no status and no stage either, because
the layer is append-only. A decision that turns out wrong becomes a new ADR naming
the one it supersedes, and the original stays readable as the reasoning that was
actually available at the time.
