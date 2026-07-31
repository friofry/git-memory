# Gates

A **gate** is a named moment where a stage transition is blocked until specific
evidence exists in the repository. Seven of them. This file is the home for what
each gate demands and who may close it; other files reference the `M:gate-*`
address and do not restate the evidence.

Gates add no stages. The stage table in
[`../agents/delivery-workflow.md`](../agents/delivery-workflow.md) already says
what each stage is done when — a gate is that "done when" turned into something
that blocks, with a name you can put in a `Refs:` line, a PR body, or a prompt.
Read the two together: the stage table tells you where the feature is, the gate
tells you what has to be true before it may be anywhere else. If a gate and the
stage table ever disagree, the stage table is the definition and this file is the
bug.

## The seven gates

This table is canonical. Cite a row by its address rather than copying the
evidence column into another document.

| Gate | `M:` address | Blocks the move into | Required evidence | Enforced by |
|------|-------------|---------------------|-------------------|-------------|
| Request | `M:gate-request` | `research` / `spec` | One-sentence outcome written down | issue form or `spec.md` Outcome |
| Approval | `M:gate-approval` | `plan` | `spec.md`, `design.md`, `acceptance.md`, `decisions.md` all present and read | human; `check-memory.sh` proves presence |
| Checks | `M:gate-checks` | `review` | The commands in `AGENTS.md` pass locally | local run, pasted into the PR body |
| Review | `M:gate-review` | `ci` | A review artifact in `templates/review.md` shape | `check-memory.sh --strict`; PR review |
| CI | `M:gate-ci` | `acceptance` | Required checks green on the head commit | protected branch required checks |
| Acceptance | `M:gate-acceptance` | `memory` | Human verified demo against `acceptance.md` | PR approval |
| Memory | `M:gate-memory` | `implemented` | Changed facts written back; `check-memory.sh` green | `check-memory.sh` + policy |

`M:gate-memory` is the only gate whose target is a `Status:` value rather than a
`Stage:` value, because `memory` is the resting stage — see the stage-and-status
mapping in [`../agents/delivery-workflow.md`](../agents/delivery-workflow.md).

## `M:gate-request`

**Who opens it.** A human, by saying what outcome they want. No agent may open
this gate on its own initiative; a recommendation from a scan or a review enters
here as a new request and waits for the same sentence.

**What evidence closes it.** One sentence naming the outcome, written into a file
or an issue form — the Outcome section of `specs/007-auth-envelope/spec.md`, or a
GitHub issue raised from the feature-request form. The sentence must describe
what becomes true for someone, not which module gets edited.

**What the agent does the moment it is closed.** Create
`specs/007-auth-envelope/`, write the node header (`ID: F:007-auth-envelope`,
`Type: feature`, `Status: draft`, `Stage: research` or `Stage: spec`,
`Parent: none`), and copy the sentence verbatim into Outcome. Do not paraphrase
it — the wording is the thing being gated.

**The failure mode this gate prevents.** An outcome that lives only in chat drifts
to match whatever got built. Nobody can fail a build against a sentence they
cannot re-read, so the request quietly becomes the diff.

## `M:gate-approval`

**Who opens it.** A human, after reading all four files. An agent may prepare the
files and say they are ready; it may not record the approval.

**What evidence closes it.** `spec.md`, `design.md`, `acceptance.md` and
`decisions.md` present, non-empty, and mutually consistent, plus a human saying
yes to meaning and architecture. A decision that outlives this feature is lifted
into an ADR under [`../adr/`](../adr/) and cited from `decisions.md` by
`ADR:` address. `check-memory.sh` proves the four files exist; it cannot prove
anyone read them.

**What the agent does the moment it is closed.** Move `Stage: approval` to
`Stage: plan` and `Status: draft` to `Status: active` in the same commit as the
approved files, then slice tickets under `.scratch/auth-envelope/issues/`.

**The failure mode this gate prevents.** Building the wrong thing at speed. Every
stage after `plan` multiplies a wrong meaning by the number of tickets, and the
cheapest moment to change the meaning is while it is still four markdown files.

## `M:gate-checks`

**Who opens it.** The builder, on their own branch, before asking anyone to look.

**What evidence closes it.** The applicable commands from
[`../../AGENTS.md`](../../AGENTS.md) run to completion on the current head
commit, with their output pasted into the PR body. "Applicable" is the set
`AGENTS.md` lists for the paths the diff touches — not a subset chosen because
the rest are slow.

**What the agent does the moment it is closed.** Paste the command block and its
output into the PR, move `Stage: checks` to `Stage: review`, and request a review
from someone who did not write the code.

**The failure mode this gate prevents.** Spending human review attention on
failures a machine finds for free. A reviewer who has to run the test suite to
discover it is red has already lost the pass they were asked for.

## `M:gate-review`

**Who opens it.** A reviewer who did not write the change. Self-review closes
nothing; if no second party exists, say that in the review artifact rather than
signing your own work.

**What evidence closes it.** A review artifact in the shape of
[`../../templates/review.md`](../../templates/review.md), with every finding
classified blocking or non-blocking. `check-memory.sh --strict` fails a spec at
`Stage: ci` or later with no review artifact.

**What the agent does the moment it is closed.** If any blocking finding stands,
set `Stage: rework` and answer each one in the artifact. If none does, set
`Stage: ci` and push. Non-blocking findings become tickets with
`Type: rework`, not silent extra commits.

**The failure mode this gate prevents.** "Reviewed" degrading into "read". An
approval with no artifact leaves no record of what was checked, so the next
regression cannot be traced to a pass that missed it.

## `M:gate-ci`

**Who opens it.** GitHub Actions, on the head commit of the pull request.

**What evidence closes it.** The required checks green **on the head commit** —
not on an earlier commit of the same branch. Make the required check
`.github/workflows/delivery.yml`, which has no path filter: a skipped job reports
success to the branch protection rule, so a path-filtered workflow such as
`memory.yml` is unsafe as a required check. Prefer strict required checks, so the
branch must be up to date with the default branch before merge.

**What the agent does the moment it is closed.** Set `Stage: acceptance` and post
the demo evidence the acceptance scenarios ask for — a run log, a screenshot, a
recorded command — next to the green checks.

**The failure mode this gate prevents.** Green that proves nothing. A stale
commit, a skipped filtered job, or a branch behind the default branch all show a
tick, and each one lets an untested merge through wearing CI's authority.

## `M:gate-acceptance`

**Who opens it.** A human, against
`specs/007-auth-envelope/acceptance.md` — the same person who opened
`M:gate-request` where possible.

**What evidence closes it.** A demo walked through the Given/When/Then scenarios,
one line of evidence per scenario, and a PR approval recording the verdict. A
scenario that cannot be demonstrated is a failed acceptance, not a footnote.

**What the agent does the moment it is closed.** Write the `Implemented in:` line
on `spec.md` with the PR or commit that delivered it, set `Stage: memory`, and
leave `Status: active` until memory is written.

**The failure mode this gate prevents.** Accepting the tests instead of the
outcome. CI green proves the code does what the code says; only this gate proves
it does what the person asked for.

## `M:gate-memory`

**Who opens it.** Whichever agent changed a fact — the one that learned it, not a
cleanup pass scheduled for later.

**What evidence closes it.** Every fact the change altered written back to its one
home: a term to [`../../CONTEXT.md`](../../CONTEXT.md), a hard-to-reverse
decision to an ADR under [`../adr/`](../adr/), a feature-local choice to
`decisions.md`, an invariant to `docs/domain/`. Then `check-memory.sh` green with
no `--fix` pending. The one-home rule that decides which of those is the right
home is in [`../memory.md`](../memory.md).

**What the agent does the moment it is closed.** Set `Status: implemented` with
`Stage: memory`, in the same commit as the memory edits, and close the tickets
under `.scratch/auth-envelope/issues/`.

**The failure mode this gate prevents.** Paying twice for the same knowledge. A
decision that exists only in a merged diff is a decision the next session will
rediscover by breaking it.

## Gates you cannot enforce mechanically

Two gates are fully mechanical: `M:gate-ci` is a branch protection rule, and
`M:gate-memory` is `check-memory.sh` plus a policy about what counts as a changed
fact. The other five rest on a human reading something, and no checker will ever
close them.

What the checker can prove is **presence**. What it cannot prove is **quality**:

| Gate | The checker can prove | Only a human can prove |
|------|-----------------------|------------------------|
| `M:gate-request` | An Outcome section exists and is non-empty | The sentence names an outcome, not a solution already chosen |
| `M:gate-approval` | The four spec files exist and are non-empty | Someone read them and agrees with the meaning |
| `M:gate-checks` | The PR body carries a command block | The commands are the ones `AGENTS.md` lists, run on this commit |
| `M:gate-review` | A review artifact exists in the template's shape | The reviewer tried to find defects rather than skimming |
| `M:gate-acceptance` | A PR approval exists and `Implemented in:` is set | The demo satisfied the scenarios |

Two stop conditions follow, and they are the reason this section exists:

- **Do not report a gate closed because the checker is green.** A file of the
  right name with the wrong content passes every check in this repository.
- **Do not move a `Stage:` line to unblock yourself.** A `Stage:` line that no
  evidence supports is worse than no line at all — orientation reports the
  mismatch instead of the claim.

Which context an agent should be holding when it works a gate is a separate
question, answered per stage in [`packet-profiles.md`](packet-profiles.md). The
`M:` families and how a method address is declared are in
`docs/method/README.md`.
