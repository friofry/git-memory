# `M:ticket-review`

Reference this from the `Refs:` line of a `Type: review` ticket — an independent
pass over a fixed diff range, held by someone who did not write it.

````md
# Review the envelope signing slice

ID: T:007/05
Type: review
Status: ready-for-human
Parent: F:007-auth-envelope
Blocked by: T:007/04
Refs: M:ticket-review, M:review-blocking, M:review-nonblocking, M:gate-review

## Diff range

`git diff main...HEAD` on `feat/007-auth-envelope`, six commits,
`a1f9c20..3e77b41`. Three-dot, so the comparison is against the merge base.
Re-pin the range and say so in the artifact if the branch moves mid-review.

## Standards axis

Does the diff follow what this repository documents — [`../../../rules/`](../../../rules/),
[`../../../AGENTS.md`](../../../AGENTS.md), the seams in `design.md`, ADR:0012 —
and is anything smelling of duplication or a leaked boundary?

## Spec axis

Does the diff do what `specs/007-auth-envelope/acceptance.md` and T:007/04 asked
for: nothing missing, nothing extra, nothing implemented against the wrong
meaning?

## Output

One review artifact in the shape of
[`../../../templates/review.md`](../../../templates/review.md), every finding
classified blocking or non-blocking, linked from this ticket.
````

## Rules

- **The two axes stay separate, and neither is merged into the other.** Code can
  follow every standard and build the wrong thing, or build the right thing and
  break every convention. Ranking findings across the axes hides one behind the
  other.
- **The range is pinned before reading**, as a fixed point and a commit list. A
  review of "the branch" is a review of whatever it was that afternoon.
- **Reviewer is not author.** Where no second party exists, say so in the
  artifact rather than signing your own work — `M:gate-review` in
  [`../gates.md`](../gates.md).
- **The one thing people get wrong.** Opening the review before the checks pass.
  `M:gate-checks` comes first for a reason: human attention spent rediscovering a
  red test suite is the most expensive way this repository can find a failure.
