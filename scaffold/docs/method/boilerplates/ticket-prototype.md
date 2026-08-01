# `M:ticket-prototype`

Reference this from the `Refs:` line of a `Type: prototype` ticket — a question
only running code can answer, where the code is written to be deleted.

````md
# Does one signer per publisher survive key rotation?

ID: T:007/02
Type: prototype
Status: claimed
Parent: F:007-auth-envelope
Blocked by: T:007/01
Refs: M:ticket-prototype

## Question

Does a signer held once per publisher stay correct across a key rotation, or does
rotation force the key to be resolved on every call?

## Timebox

Four hours. At the timebox this ticket is answered with what is known, including
"still unknown". Buying more time is a new ticket with a narrower question.

## Where it lives

`spikes/auth-envelope/proto-a/` — S:007/proto-a, README in the shape of
[`../../../templates/spike.md`](../../../templates/spike.md). Nothing under
`src/` imports it, and nothing under `src/` is refactored to suit it.

## Disposal

The code under `spikes/auth-envelope/proto-a/` is deleted in the commit that sets
this ticket to `done`. The spike README survives, carrying the result and the
decision. If the decision is hard to reverse it is lifted into an ADR under
[`../../adr/`](../../adr/) first, and the ticket cites that address.

## Answer

A per-publisher signer serves stale keys for up to the rotation interval. Resolve
the key per call; the signer stays stateless. Recorded in `decisions.md`.
````

## Rules

- **A timebox in hours or days, written before the work starts**, and an answer
  written at it. A prototype with no timebox becomes an implementation nobody
  reviewed.
- **A disposal plan that names what is deleted and what survives.** The default:
  code goes, the spike README and the answer stay.
- **The spike is the node, the ticket is the question.** The spike README carries
  `ID: S:007/proto-a` and `Type: prototype`; neither file carries a `Stage:` line.
- **The one thing people get wrong.** Letting the prototype graduate. Code written
  under a timebox with no tests and no review does not become production code by
  being useful — the answer graduates, and the implementation is written again
  against a fixed contract. See [`ticket-interface.md`](ticket-interface.md).
