# `M:review-blocking`

Reference this when classifying a review finding as blocking: the change would
ship a defect, violate a documented rule, or contradict an ADR.

````md
## Blocking issues

### Signatures are verified against the current key, not the envelope's key

`src/events/envelope-signer.ts:48` verifies against the key the signer resolved
this call, ignoring `envelope.sig.keyId`.

`specs/007-auth-envelope/acceptance.md` scenario 4 requires an event signed with
`k-2026-01` to verify after rotation to `k-2026-07`; the test at
`src/events/envelope.spec.ts:31` passes only because its fixture never rotates.

Every event in flight across a rotation fails verification and the consumer drops
it — silently, since `verify` returns `false` rather than throwing.

### `sig` is written outside the seam

`src/jobs/replay.ts:112` builds `sig` inline instead of calling `EnvelopeSigner`,
contradicting the single-seam contract fixed in T:007/03 and ADR:0012.

Two signing implementations diverge on the next format change, and the one in
`replay.ts` has no test.
````

## Rules

- **Three sentences, in order: claim, evidence, consequence.** The claim names
  what is wrong, the evidence is a file and line or a quoted requirement, the
  consequence is what a user or a maintainer suffers. A finding missing the
  consequence gets argued about instead of fixed.
- **A blocking finding names a file and a line.** No line, no block. If the
  defect is structural and has no single line, name the file that would have to
  change and say so.
- **Blocking means one of three things, not four.** Ships a defect, violates a
  documented rule in [`../../../rules/`](../../../rules/) or
  [`../../../AGENTS.md`](../../../AGENTS.md), or contradicts an ADR under
  [`../../adr/`](../../adr/). Anything else is
  [non-blocking](review-nonblocking.md).
- **Every blocking finding is answered in the artifact**, either by a fix or by an
  explicit deferral with a ticket address. `M:gate-review` in
  [`../gates.md`](../gates.md) sends the feature to `Stage: rework` until they are.
- **The one thing people get wrong.** Softening a defect into the non-blocking
  list to avoid a second round. The severity is a property of the finding, not of
  how much time is left before the merge.
