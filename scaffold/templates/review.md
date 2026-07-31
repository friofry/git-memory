# Review — what was reviewed, in one line

Node: F:<NN>-<slug>
Range: main...HEAD on <branch>, <n> commits, <base-sha>..<head-sha>
Reviewer: <who>, <date>
Severity: M:review-blocking | M:review-nonblocking

<!--
File: `.scratch/<feature-slug>/reviews/<NN>-<slug>.md`, linked from the review
ticket that ordered it. A review is evidence, not a node: it carries no ID, no type
and no stage of its own — the node it judges is named above.

- `Node:` — the address under review: `F:007-auth-envelope`, or the ticket
  `T:007/04` when the pass covers one slice.
- `Range:` — pinned before reading, as a three-dot range against the merge base plus
  the two shas it resolved to. "The branch" is not a range; it means whatever the
  branch was that afternoon, and a finding against it cannot be reproduced. If the
  branch moves mid-review, re-pin and say so here.
- `Reviewer:` — someone who did not write the change. Where no second party exists,
  say so here rather than signing your own work — M:gate-review in
  `docs/method/gates.md`.
- `Severity:` — the two-value vocabulary every finding below is classified under.
  Blocking means the change ships a defect, violates a documented rule, or
  contradicts an ADR: M:review-blocking, in
  `docs/method/boilerplates/review-blocking.md`. Everything else is non-blocking:
  M:review-nonblocking, in `docs/method/boilerplates/review-nonblocking.md`. There
  is no third value, and severity is a property of the finding, not of how much time
  is left before the merge.
-->

## Scope

<!-- What the pass covered and what it deliberately did not: which axes (standards,
spec), which paths, which behaviour was taken on trust. An unstated exclusion reads
as a clean bill of health for code nobody opened. -->

## Blocking issues

<!-- Claim, evidence, consequence, in that order, one finding per heading, each
naming a file and a line — M:review-blocking. While one of these stands, the feature
goes to the rework stage and does not move on. -->

## Non-blocking concerns

<!-- Findings worth fixing that do not block the merge, each with the ticket it
becomes — M:review-nonblocking. A concern with no ticket is a comment, and it is
gone the next time this file is skimmed. -->

## Violated rules

<!-- The rule under `rules/`, the line in `AGENTS.md`, or the ADR the diff
contradicts, quoted, with the file that breaks it. A violation with no citation is a
preference wearing a rule's clothes. -->

## Acceptance coverage

<!-- Scenario by scenario from `specs/<NN>-<slug>/acceptance.md`: which you
verified, how, and which you could not. A scenario you did not check is listed as
unchecked — silence here gets read as passed. -->

## Commands run

<!-- The exact commands and their results. Mark anything you are recommending rather
than reporting as suggested, so nobody mistakes it for evidence. -->

## Residual risks

<!-- What can still go wrong once every blocking finding is answered, and what would
detect it. This is the section a post-incident reader opens first. -->
