# `M:contract-acceptance`

Reference this when writing or reviewing a scenario in
`specs/<NN>-<slug>/acceptance.md` — the Given/When/Then shape a feature is
accepted against.

````md
## Scenario 2 — a published event verifies against the key that signed it

Given a publisher holding signing key `k-2026-07`
When it publishes an `order.placed` event
Then a consumer verifying with `k-2026-07` accepts the event
And a consumer verifying with the retired key `k-2026-01` rejects it

Evidence: `pnpm test src/events/envelope.spec.ts` — "verifies across rotation"

## Scenario 4 — an event signed before a rotation still verifies after it

Given an event signed with `k-2026-01` and still in the queue
When the signing key rotates to `k-2026-07`
Then a consumer verifying that event accepts it
And the rejection counter does not move

Evidence: demo run against staging, 2026-07-31, log line pasted in the PR
````

## Rules

- **One Given, one When, one or more Then.** Given is the state before, When is
  the single action under test, Then is what an outside observer can check
  afterwards. Two Whens is two scenarios.
- **Every Then names an observable**, not an implementation: what a consumer,
  a user, a log or an API sees. `Then a consumer verifying with k-2026-07 accepts
  the event` is an observable; `Then signEnvelope() is called` is not.
- **Every scenario carries its evidence line** — the command or the demo that
  proves it. `M:gate-acceptance` in [`../gates.md`](../gates.md) is walked
  scenario by scenario, and a scenario that cannot be demonstrated is a failed
  acceptance, not a footnote.
- **Scenarios are quoted, never paraphrased, into the tickets that advance them**
  — see [`ticket-implementation.md`](ticket-implementation.md).
- **The one thing people get wrong.** Writing Then against the code, because the
  code is what is in front of them. A scenario asserting that a function was
  called passes the moment the function exists, survives every refactor that
  breaks the behaviour, and cannot fail for the reason the feature was requested.
