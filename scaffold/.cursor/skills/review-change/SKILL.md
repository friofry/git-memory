---
name: review-change
description: Independently review a pinned diff range against acceptance, rules, glossary and the required commands, and produce the review artifact. Use at the review stage or on a pull request.
---

# Review change

Try to find defects in a pinned range of commits, classify what you find as
blocking or non-blocking, and write the artifact that lets the feature leave the
`review` stage.

You are looking for defects, not fixing them. A pass that fixes what it finds
produces a review record of problems nobody independently caught, and the next
person tunes the process against a number that is fiction —
[`../../../docs/method/work-types.md`](../../../docs/method/work-types.md),
`review` versus `rework`.

## Inputs

- **The diff range, pinned before you read a line.** A three-dot range against the
  merge base, plus the two shas it resolved to:

  ```bash
  git merge-base main HEAD
  git log --oneline main...HEAD
  git diff main...HEAD
  ```

  Record it as `main...HEAD on claude/auth-envelope, 6 commits, a1b2c3d..e4f5a6b`.
  "The branch" is not a range: it means whatever the branch was that afternoon, and
  a finding against it cannot be reproduced. If the branch moves mid-review, re-pin
  and say so in the artifact.
- **The node under review**, by address: `F:007-auth-envelope`, or `T:007/04` when
  the pass covers one slice.
- **The acceptance scenarios** the range claims to satisfy.

## Procedure

1. Assemble the `review` packet —
   [`../prepare-packet/SKILL.md`](../prepare-packet/SKILL.md). It is the widest
   profile in the set on purpose: a review runs two axes and each needs a different
   half, so it carries the diff, `acceptance.md`, `rules/`, the architecture
   documents and `CONTEXT.md`.

   ```bash
   ./scripts/git-memory-packet.sh F:007-auth-envelope review
   ```

2. Read the diff against [`../../../rules/`](../../../rules/) and the architecture
   documents under [`../../../docs/architecture/`](../../../docs/architecture/). For
   a full two-axis pass run `.agents/skills/code-review/`: its Standards axis reads
   `rules/`, the architecture documents, `CONTEXT.md` and `AGENTS.md`, and its Spec
   axis reads the feature's `acceptance.md`.
3. Check the glossary: no `_Avoid_` synonyms in new prose or new identifiers; a new
   term is either unnecessary or already added to `CONTEXT.md`.
4. Confirm a test exists for every behaviour change and every bug fix, and that it
   fails without the change. A test that passes on the parent commit proves nothing
   about this range.
5. Run the applicable commands from `AGENTS.md` yourself. Do not copy the builder's
   pasted output into your own Commands run section — that is their evidence for
   `M:gate-checks`, not yours.
6. Go through `acceptance.md` scenario by scenario and record a verdict per
   scenario. A scenario you did not check is listed as unchecked; silence in that
   section gets read as passed.

## Classify every finding

Two values, no third. Severity is a property of the finding, never of how much time
is left before the merge.

| Severity | Use when | Address |
|----------|----------|---------|
| Blocking | the change ships a defect, violates a documented rule, or contradicts an ADR | [`M:review-blocking`](../../../docs/method/boilerplates/review-blocking.md) |
| Non-blocking | the code is correct and compliant, and the finding is a judgement about craft | [`M:review-nonblocking`](../../../docs/method/boilerplates/review-nonblocking.md) |

Each blocking finding states claim, evidence, consequence, in that order, and names
a file and a line. Each non-blocking concern names the ticket it becomes: a concern
with no ticket is a comment, and it is gone the next time the file is skimmed.

## Write the artifact before touching the stage

The review artifact is the evidence `M:gate-review` demands, and the feature may not
enter `ci` without it —
[`../../../docs/method/gates.md`](../../../docs/method/gates.md). Write it first, at
`.scratch/<slug>/reviews/<NN>-<slug>.md`, in the shape of
[`../../../templates/review.md`](../../../templates/review.md); that file is the
home for the shape. A review that exists only as pull request comments cannot be
read by the next agent and cannot be checked by
`./scripts/check-memory.sh --strict`.

Then move `Stage:`:

- a blocking finding stands → `rework`;
- the range is clean → `ci`;
- CI green on the head commit → `acceptance`.

## Stop and escalate when

- **You wrote the code.** Say so in the `Reviewer:` line rather than signing your own
  work. Where no second party exists, the artifact records that fact —
  `M:gate-review`.
- **The range will not pin**, because the branch is being pushed to while you read.
  Stop and ask for a frozen head; a moving range produces findings against code that
  no longer exists.
- **A blocking finding contradicts an ADR that the diff seems to have replaced.**
  That is an architecture decision, not a review comment: route to
  [`../review-architecture/SKILL.md`](../review-architecture/SKILL.md).
- **The commands in `AGENTS.md` do not run.** Report that as the finding. A review
  of code whose checks were never executed is a reading, and it should not be
  labelled a review.
- **Do not fix anything, and do not move `Stage:` to `ci` while a blocking finding
  stands.**
