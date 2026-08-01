# `M:approval-checklist`

Reference this at the approval gate, when a human is being asked to read four
files and say yes before any ticket is cut — `M:gate-approval` in
[`../gates.md`](../gates.md).

````md
## Approval — F:007-auth-envelope

Read on 2026-07-31 by @ab. Files under `specs/007-auth-envelope/`.

- [x] `spec.md` — what becomes true for someone, and what is out of scope?
      Outcome: "a consumer can tell whether an event came from who it claims".
      An outcome, not a solution. Out of scope names key storage explicitly.
- [x] `design.md` — which seams move, and which stay?
      One seam, `EnvelopeSigner`, between publisher and consumer. Replay path
      named as a later caller, not folded in.
- [ ] `acceptance.md` — what would prove it, that could fail?
      Scenario 3 asserts `envelope.sig` is non-empty. That is an implementation
      detail; rewrite it as an observable — M:contract-acceptance.
- [x] `decisions.md` — what was chosen, what was rejected, what is reversible?
      Per-call key resolution (S:007/proto-a), rejected per-publisher signer.
      Rotation policy is hard to reverse and is lifted to ADR:0013.

Verdict: changes requested — acceptance scenario 3. Nothing else blocks.
````

## Rules

- **The four files are read, not counted.** `check-memory.sh` proves they exist
  and are non-empty; only a person proves they agree with each other and with
  what was asked for.
- **Ask the four questions above in that order.** An acceptance scenario written
  before the outcome is settled tests whatever the design happened to say.
- **The verdict names files, and only a human writes it.** An agent may prepare
  the four files and say they are ready; it may not record the approval.
- **A rejected item stops the gate, not the feature.** Fix the file and re-read
  it; do not open `Stage: plan` with one box empty.
- **The one thing people get wrong.** Approving the summary. If the four files
  reached you as a paraphrase in chat, you approved the paraphrase — the packet
  for this gate quotes the files in full for exactly that reason, see
  [`../packet-profiles.md`](../packet-profiles.md).
