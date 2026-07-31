# GitHub gates

How the files under [`../../.github/`](../../.github/) enforce the gates defined
in [`../method/gates.md`](../method/gates.md). This file is the home for the
GitHub side — which mechanism blocks which transition, what each one can and
cannot prove, and the two GitHub behaviours that make a gate pass itself if you
configure it the obvious way. It does not redefine a gate: cite the `M:gate-*`
address, read the evidence there.

A gate lives in three places at once. The definition is in
[`../method/gates.md`](../method/gates.md), the evidence is in the repository,
and the block is a GitHub setting. Only the third one is missing by default —
every file here ships inert until someone turns on branch protection.

## Which mechanism enforces which gate

| Mechanism | File | Gate | What it enforces |
|-----------|------|------|------------------|
| Issue forms | [`../../.github/ISSUE_TEMPLATE/`](../../.github/ISSUE_TEMPLATE/) | `M:gate-request` | A request arrives with an outcome sentence, a scope and a work type, or it does not arrive |
| PR template | [`../../.github/pull_request_template.md`](../../.github/pull_request_template.md) | `M:gate-checks`, `M:gate-memory` | The command output and the memory delta are in the body before a reviewer is asked to look |
| Required checks | [`../../.github/workflows/delivery.yml`](../../.github/workflows/delivery.yml) | `M:gate-ci` | The project's own commands ran green on the head commit |
| Advisory checks | [`../../.github/workflows/memory.yml`](../../.github/workflows/memory.yml) | `M:gate-memory` | Memory consistency, on the pull requests that touch documents or scripts |
| CODEOWNERS plus required review | [`../../.github/CODEOWNERS`](../../.github/CODEOWNERS) | `M:gate-approval`, `M:gate-acceptance` | A named human read the change and recorded a verdict |
| PR review | GitHub review UI | `M:gate-review` | A second party produced the artifact — the shape is [`../../templates/review.md`](../../templates/review.md) |

Two rows carry the weight. Required checks are the only mechanism here that
blocks without a human; everything else routes attention to a person who can
still say yes without looking. That asymmetry is why the required check must be
the one workflow that always runs.

## A skipped job reports success

This is a real GitHub behaviour and the single most expensive mistake available
in this layer.

When a workflow declares a `paths:` filter and a pull request touches none of
those paths, GitHub does not run the workflow. It does not report the check as
pending, and it does not report it as failed. Branch protection is waiting for a
status that will never arrive, so the check is treated as satisfied and the pull
request becomes mergeable. The gate reports success on exactly the changes it
was never allowed to inspect.

[`../../.github/workflows/memory.yml`](../../.github/workflows/memory.yml) is
path-filtered, and the filter is correct for its job: there is no reason to
re-run the document checker on a pull request that changes one Rust file. That
same filter makes it unsafe as a required check, and its header comment says so.

The rule, in one line: **a workflow you require must have no path filter.**
[`../../.github/workflows/delivery.yml`](../../.github/workflows/delivery.yml)
has none, runs on every pull request and every push to the default branch, and
is the workflow to require. If you want memory consistency inside the blocking
gate rather than beside it, uncomment the `check-memory.sh` step in that file's
`test` job — do not promote `memory.yml`.

The same trap has a second door. A job guarded by `if:` that evaluates false is
also skipped, and also reports success. A conditional step inside a job that
runs is safe; a conditional job you have made required is not.

## Strict versus loose required checks

Branch protection offers two shapes of required check, and the difference is
what "green" was measured against.

| | What it requires | What it misses |
|---|------------------|----------------|
| **Loose** | The checks passed on the head commit of the branch | The default branch may have moved since; the merge result was never tested |
| **Strict** | The above, plus the branch is up to date with the default branch | Nothing about the merge itself — it costs a rebase or merge per pull request |

Choose **strict** on the default branch. The failure it prevents is the
semantic conflict: two pull requests that pass independently and break once
merged, because one renamed the function the other started calling. Git merges
both without a textual conflict and no check ever saw the combination.

The cost is real and worth stating: every pull request must be updated when the
default branch moves, and on a busy repository that is a queue. Take the queue.
The alternative is a default branch that is broken between merges, which is the
state `M:gate-ci` exists to make impossible.

## Turning the files on

Nothing in this directory blocks anything until these are set. Do them in this
order.

1. **Set required status checks** on the default branch to the job names in
   [`../../.github/workflows/delivery.yml`](../../.github/workflows/delivery.yml)
   — `lint`, `typecheck`, `test`. Tick the strict option ("require branches to
   be up to date before merging").
2. **Fill in the commands** in that workflow from
   [`../../AGENTS.md`](../../AGENTS.md), "Before finishing", and delete the
   placeholder steps. A required check that runs nothing is a green tick with no
   evidence behind it, and it is worse than no check, because a reviewer trusts
   it.
3. **Require at least one approving review**, and tick "require review from Code
   Owners" so [`../../.github/CODEOWNERS`](../../.github/CODEOWNERS) becomes a
   block rather than a suggestion.
4. **Dismiss stale approvals on new commits.** Without this, an approval given
   before the last three commits still counts, and `M:gate-acceptance` is
   closed by a reviewer who never saw the change that shipped.
5. **Replace `OWNER/REPO`** in
   [`../../.github/ISSUE_TEMPLATE/config.yml`](../../.github/ISSUE_TEMPLATE/config.yml)
   — a contact link needs an absolute URL and GitHub will not resolve a
   repo-relative path.

## What CODEOWNERS does and does not do

CODEOWNERS is a routing table. It maps a path to the people GitHub requests a
review from, and on its own it requests only — the pull request merges without
them. It becomes an enforcement mechanism under exactly three conditions, all of
which must hold:

- the file is on the **default branch** (a CODEOWNERS added on a topic branch
  does not govern that branch's own pull request);
- the named team or user has **write access** to the repository, or the rule is
  ignored with no warning anywhere in the UI;
- branch protection **requires review from code owners** for the branch in
  question.

The memory layer is owned there because a change to
[`../method/`](../method/) or to
[`../memory.md`](../memory.md) changes how every future feature is run, and
that is a decision, not a documentation edit. Which paths are covered is in the
file itself.

The failure mode: ownership recorded and not enforced. The file reads as though
the memory layer is protected, everyone acts as though it is, and the protection
does not exist. Check it by opening a pull request that touches
[`../method/gates.md`](../method/gates.md) and confirming the merge button is
blocked — not by re-reading the file.

## Issues are intake; the repository is the truth

GitHub Issues are the **human intake and visibility layer**. The forms under
[`../../.github/ISSUE_TEMPLATE/`](../../.github/ISSUE_TEMPLATE/) are where a
request arrives with enough structure to close `M:gate-request`, and the issue
is how someone without the repository checked out can see the work exists.

Agents do not write state there. `specs/` and `.scratch/` are the writable
truth, and the reasoning — two writable stores mean an unbounded reconciliation
problem with no correct answer — is in
[`issue-tracker.md`](issue-tracker.md), "Why not GitHub Issues as a second
writable truth". Do not restate it; do not work around it.

The two layers meet once, at the pull request. The body carries the node
address, the stage, the blocker, the memory delta and the commands with their
results — the shape is
[`M:handoff-pr`](../method/boilerplates/handoff-pr.md) — and the closing keyword
shuts the intake issue at merge. One direction, one moment, no synchronisation
loop.

| Layer | Written by | Read by | Survives |
|-------|-----------|---------|----------|
| Issue | Humans, through a form | Anyone | Until the PR's keyword closes it |
| Spec / ticket | Agents and humans, in commits | Whoever has the branch | Forever, in `git log`, beside the code |
| Pull request | The agent handing off | The reviewer | As the merge commit's record |

## Stop conditions

- **Do not make a path-filtered workflow a required check.** It reports success
  when it does not run. This is the whole reason `delivery.yml` exists as a
  separate file.
- **Do not report `M:gate-ci` closed because the checks are green.** Confirm they
  are green on the **head commit**, and that the branch is up to date if strict
  is on. A tick beside an earlier commit of the same branch proves nothing about
  the code being merged.
- **Do not add a required check whose command is a placeholder.** Fill it in or
  leave it unrequired; a check that cannot fail is a false statement about the
  change.
- **Do not open an issue to record agent state.** State lives in
  `specs/<NN>-<slug>/spec.md` and `.scratch/<slug>/issues/`. An issue that
  disagrees with a ticket file has no rule to resolve it, and the loser is
  believed silently.
- **Do not weaken branch protection to land a change.** That is a decision about
  how this repository is governed; it goes through an ADR under
  [`../adr/`](../adr/), not through a merge you were in a hurry to finish.
