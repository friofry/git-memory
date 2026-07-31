# `M:ticket-implementation`

Reference this from the `Refs:` line of a `Type: implementation` ticket — a slice
whose contract is already fixed, where the only open question is whether the code
does what the contract says.

````md
# Sign outbound events on publish

ID: T:007/04
Type: implementation
Status: ready-for-agent
Parent: F:007-auth-envelope
Blocked by: T:007/03
Refs: M:ticket-implementation, M:contract-acceptance, TERM:event-envelope

## Scenario advanced

`specs/007-auth-envelope/acceptance.md`, scenario 2, quoted verbatim:

> Given a publisher holding signing key `k-2026-07`
> When it publishes an `order.placed` event
> Then a consumer verifying with `k-2026-07` accepts the event

## Seam

`EnvelopeSigner`, as fixed by T:007/03. Implement it in
`src/events/envelope-signer.ts` and call it from the one place
`src/events/publisher.ts` builds an envelope. No other file changes.

## Done when

- Scenario 2 passes as an automated test that fails with the signer removed.
- The commands `AGENTS.md` lists for `src/events/` pass on this branch.
- `src/jobs/replay.ts` still publishes unsigned events; that is T:007/06.
````

## Rules

- **One acceptance scenario, quoted, not paraphrased.** A ticket that advances no
  scenario is either unnecessary work or a gap in
  [`../../../specs/`](../../../specs/) — resolve which before writing code.
- **One seam.** Name the interface the diff is allowed to touch and the files
  behind it. A second seam is a second ticket.
- **`Blocked by:` names the ticket that fixed the contract**, and the ticket does
  not start until that address is `resolved` or `done`.
- **No `Stage:` line.** Stage belongs to the spec — see
  [`../../agents/delivery-workflow.md`](../../agents/delivery-workflow.md).
- **The one thing people get wrong.** Writing `## Done when` as "the feature
  works". Every entry must be a command someone else can run, or an observable
  someone else can check — see [`contract-acceptance.md`](contract-acceptance.md).
  "Done when it works" is a ticket that can only be closed by its author.
