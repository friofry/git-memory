# `M:handoff-pr`

Reference this whenever work leaves one session for another — a pull request
opened, an agent stopping mid-stage, a branch passed to a person.

````md
## Handoff

Node: F:007-auth-envelope — T:007/04 in flight, T:007/05 queued
Stage: checks, moving to review
Branch: feat/007-auth-envelope at 3e77b41
Blocker: none. T:007/06 (replay path) is out of scope for this PR by decision,
  not by oversight.
Next check: M:gate-review — an independent pass in the templates/review.md shape,
  by someone who did not write this diff.
Memory delta: CONTEXT.md term `Event envelope` gains the `sig` field;
  decisions.md records per-call key resolution (S:007/proto-a); ADR:0012
  unchanged; no new ADR.
Commands run:
  pnpm test src/events      24 passed, 0 failed
  pnpm typecheck            clean
  ./.git-memory-scripts/check-memory.sh green

Closes #142
````

## Rules

- **Six lines, all of them, even when the answer is "none".** An absent Blocker
  line reads as "not checked"; `Blocker: none` reads as "checked". The next
  session cannot tell the difference any other way.
- **The memory delta is a promise with an address.** Name the file each changed
  fact lands in before the merge, so `M:gate-memory` in [`../gates.md`](../gates.md)
  has something to be checked against rather than a memory of the conversation.
- **Commands are pasted with their result**, not named. "Tests pass" is a claim;
  `24 passed, 0 failed` under the command that produced it is evidence.
- **A handoff never goes to an OS temp directory.** Not `/tmp`, not a scratch
  path outside the repository, not a message that exists only in a chat
  transcript. A cloud agent's VM is destroyed when its turn ends and takes every
  unpushed file with it. The handoff lives in the PR body, or in a file committed
  on the branch — somewhere `git fetch` can reach.
- **The one thing people get wrong.** Writing the handoff as a narrative of what
  was done. The reader is deciding what to do next; they need the address, the
  blocker and the next check, and they will read the diff for the rest.
