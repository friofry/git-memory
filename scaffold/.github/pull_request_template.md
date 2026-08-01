<!--
This body is the handoff baton. Its shape is `M:handoff-pr`, defined in
../docs/method/boilerplates/handoff-pr.md — fill every line, including the ones
whose honest answer is "none". An absent Blocker line reads as "not checked";
`Blocker: none` reads as "checked", and the reader cannot tell the difference
any other way.

Delete the example text. Do not delete a heading.
-->

## Handoff

```
Node: F:007-auth-envelope — T:007/04 in flight, T:007/05 queued
Stage: checks, moving to review
Branch: feat/007-auth-envelope at 3e77b41
Blocker: none. T:007/06 (replay path) is out of scope for this PR by decision,
  not by oversight.
Next check: M:gate-review — an independent pass in the templates/review.md
  shape, by someone who did not write this diff.
Memory delta: CONTEXT.md term `Event envelope` gains the `sig` field;
  decisions.md records per-call key resolution (S:007/proto-a); ADR:0012
  unchanged; no new ADR.
```

## Commands run

Paste each command with the result it produced. "Tests pass" is a claim;
`24 passed, 0 failed` under the command that produced it is evidence — this
block is what closes `M:gate-checks`.

```
pnpm test src/events      24 passed, 0 failed
pnpm typecheck            clean
./scripts/check-memory.sh green
```

## Acceptance scenarios covered

One line per scenario in `specs/<NN>-<slug>/acceptance.md`, naming the evidence.
A scenario this PR does not cover is listed here as not covered, with the reason.

| Scenario | Covered by |
|----------|------------|
| 1. Consumer verifies a signed envelope offline | `src/events/verify.test.ts:41` |
| 2. Consumer rejects a tampered payload | `src/events/verify.test.ts:78` |
| 3. Unknown key id is rejected, not fetched | not covered — needs the resolver in T:007/06 |

## Reviewer checklist

Each line is a gate. Definitions are in
[`../docs/method/gates.md`](../docs/method/gates.md); do not restate the
evidence here, tick against it.

- [ ] `M:gate-checks` — the Commands block names the commands
      [`../AGENTS.md`](../AGENTS.md) lists for the paths this diff touches, run
      on this head commit
- [ ] `M:gate-review` — a review artifact exists in the
      [`../templates/review.md`](../templates/review.md) shape, written by
      someone who did not write this diff, every finding classified blocking or
      non-blocking
- [ ] `M:gate-ci` — required checks green on the head commit, not on an earlier
      commit of the same branch
- [ ] `M:gate-acceptance` — the scenarios above were demonstrated, not inferred
      from the tests passing
- [ ] `M:gate-memory` — every fact this change altered has a named home in the
      Memory delta, and `./scripts/check-memory.sh` is green

Stop conditions: do not approve because CI is green — a file of the right name
with the wrong content passes every check in this repository. Do not accept a
`Stage:` line the evidence in this PR does not support.

<!-- The closing keyword is what shuts the intake issue. One direction, one
moment, no reconciliation loop — see ../docs/agents/issue-tracker.md. Replace
the number; delete the line only if this PR closes no issue. -->

Closes #142
