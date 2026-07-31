# `M:review-nonblocking`

Reference this when classifying a review finding as non-blocking: the code is
correct and compliant, and the finding is a judgement about craft.

````md
## Non-blocking concerns

### `EnvelopeSigner` takes a `keyId` its only caller already knows

`src/events/publisher.ts:64` resolves the key id and passes it straight into
`sign`. The signer could resolve it itself and take one argument.

Every future caller repeats the resolution, and the two-argument form invites a
caller to pass a key id the publisher never held. Not a defect today — the
contract in T:007/03 says exactly this, and it was chosen deliberately.

Ticket if pursued: `Type: rework`, after the replay path in T:007/06 lands and
shows whether the second caller wants the same shape.

### Test names repeat the fixture instead of the behaviour

`src/events/envelope.spec.ts:12-58` — six tests named after `k-2026-07`. A reader
scanning a failure sees the key, not the rule that broke.
````

## Rules

- **Same sentence shape as a blocking finding**: claim, evidence, consequence —
  see [`review-blocking.md`](review-blocking.md). A vaguer sentence is not a
  lighter severity, it is a finding nobody can act on.
- **Say what would make it worth doing.** A non-blocking finding with no trigger
  and no ticket is an opinion in a file that ships.
- **It never blocks the merge and never becomes a silent extra commit.** If it is
  pursued, it becomes a ticket with `Type: rework`; if it is not, it stays in the
  artifact as the record that someone looked and chose.
- **The one thing people get wrong.** Escalating taste to blocking because the
  reviewer is confident. "I would have written it differently" with no rule, no
  ADR and no defect is this list, however strongly it is held — and a reviewer who
  blocks on style teaches the next author to stop asking.
