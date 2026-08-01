---
name: implement-feature
description: Implement an approved specs/ feature one ticket at a time, with a packet, scoped diffs, tests, and memory written back. Use at the plan, build, checks, rework and memory stages.
---

# Implement feature

Take one ticket from an approved feature, land the smallest diff that advances an
acceptance scenario, prove it with the repository's own commands, and write back
what changed.

Use when `specs/<NN>-<slug>/` exists, `M:gate-approval` is closed, and tickets are
ready for agent work.

Every `T:` and `M:` string below is an address, not a nickname: `T:007/03` is one
ticket file, `M:gate-approval` one heading under `docs/method/`. Resolve either with
`./.git-memory-scripts/git-memory-resolve.sh resolve <address>` —
[`../../../docs/method/addressing.md`](../../../docs/method/addressing.md).

## 1. Assemble the packet first

Do not start by reading the feature. Start by assembling the envelope for this node
and stage, and work from it —
[`../prepare-packet/SKILL.md`](../prepare-packet/SKILL.md).

```bash
./.git-memory-scripts/git-memory-packet.sh T:007/03 build
```

The `build` profile carries Route, Contract and Slice, and deliberately omits the
glossary and the feature Outcome: the outcome is already compiled into the
acceptance scenarios, and a builder holding the whole ticket queue writes code for
slices that are not theirs. The profile per stage, and what each one is most
commonly over-read with, is in
[`../../../docs/method/packet-profiles.md`](../../../docs/method/packet-profiles.md).

If you need the spec to understand the ticket, the ticket is underspecified. That is
a planning defect: say so and send it back, rather than reconstructing the missing
contract inside a build turn.

## 2. Confirm the gate, then claim by address

1. Confirm `Stage:` is past `approval`. If no ticket queue exists, publish one with
   [`../plan-feature/`](../plan-feature/) under `Stage: plan`, then set `Stage: build` when
   work starts —
   [`../../../docs/agents/delivery-workflow.md`](../../../docs/agents/delivery-workflow.md).
2. **Check `Blocked by:` before claiming.** A ticket is unblocked only when every
   address on that line carries a finished triage label — `resolved` for a question
   answered under `## Answer`, `done` for implementation that has landed. Any other
   label blocks; the full set is in
   [`../../../docs/agents/triage-labels.md`](../../../docs/agents/triage-labels.md).
   Resolve each address:

   ```bash
   ./.git-memory-scripts/git-memory-resolve.sh resolve T:007/01
   ```

   An unresolvable blocker is a stop, not a formality — it usually means the
   blocking ticket was renumbered and the two files now disagree about what is
   waiting on what. A `Blocked by:` line left in place after the ticket it names
   reached `done` or `resolved` is the opposite failure, and it is why a frontier
   looks empty while work is sitting there: delete the line when nothing blocks the
   ticket.
3. **Claim by address.** Set `Status: claimed` on the ticket file and say which
   address you took — `T:007/03`, not "the schema ticket". Two agents claiming
   different files under the same description is a merge conflict discovered at
   review.

Never add a `Stage:` line to a ticket to record how far it got. Stage belongs to the
feature, in one file.

## 3. Build the slice

The ticket's `Type:` decides the body it follows and therefore what finishing it
requires.
`Type: implementation` follows `M:ticket-implementation` —
[`../../../docs/method/boilerplates/ticket-implementation.md`](../../../docs/method/boilerplates/ticket-implementation.md)
— which names the scenario advanced, the seam, and the files that may change. The
other four skeletons and which type takes which are in
[`../../../docs/method/work-types.md`](../../../docs/method/work-types.md). Cite the
address on the ticket's `Refs:` line; do not paste the skeleton's prose.

1. Implement the smallest slice that advances one acceptance scenario.
   `.agents/skills/tdd/` is the craft; this skill is the repository wiring.
2. Write the test for that scenario first when the behaviour is crisp — the
   red-green loop in `.agents/skills/tdd/`. Reach for `.agents/skills/diagnosing-bugs/`
   when a slice or a review finding turns into a real defect and there is no tight
   failing loop yet.
3. Keep the diff inside the files the ticket names. A diff wider than its ticket
   fails review on scope rather than on correctness, and the correctness finding
   never gets made.

## 4. Prove it and hand off

1. Run every command in the **Before finishing** block of
   [`../../../AGENTS.md`](../../../AGENTS.md) — `./.git-memory-scripts/check-memory.sh` plus each
   project command that repository filled in — and no substitutes of your own. A
   command still commented out there is unfinished setup, not a command to skip: name
   the missing check in the pull request body. That is the `checks` stage — set
   `Stage: checks` while running them, and paste the exact commands and their
   unedited output into the pull request body, which is the evidence `M:gate-checks`
   demands — [`../../../docs/method/gates.md`](../../../docs/method/gates.md).
2. Append implementation choices to `decisions.md`; promote one to an ADR under
   `docs/adr/` when it outlives this feature.
3. Set the ticket's finished label in the same commit as the code it describes:
   `done` when the work landed, `resolved` when the ticket asked a question and the
   answer now sits under its `## Answer` heading. A ticket left `claimed` after its
   diff merges is why the next agent re-claims work that is already done.
4. Hand off with `Stage: review`. A returning finding moves the feature to `rework`,
   never straight back to `build`.

At `rework`, reassemble the packet for that stage and work only the blocking
findings, each quoted verbatim from the review artifact. Fixing the non-blocking
half grows the diff past the version that was reviewed and forces a second full
review — `M:review-nonblocking` in
[`../../../docs/method/boilerplates/review-nonblocking.md`](../../../docs/method/boilerplates/review-nonblocking.md).

## 5. Write memory back

After the human accepts, set `Stage: memory`, write the facts and decisions that
changed into their one home each — `CONTEXT.md` for a term, `docs/adr/` for a
hard-to-reverse decision, `decisions.md` for a local choice
([`../../../docs/memory.md`](../../../docs/memory.md), one-home rule) — add the
`Implemented in:` line, run `./.git-memory-scripts/check-memory.sh`, and only then set
`Status: implemented`. That is `M:gate-memory`.

## Output

- Scoped commits or a pull request whose body carries the commands and their output.
- Green targeted tests for every scenario the slice claims.
- `decisions.md` updated and the ticket closed at `done` or `resolved`.
- `./.git-memory-scripts/check-memory.sh` green.

## Stop and escalate when

- **A `Blocked by:` address is unresolved or unresolvable.** Do not claim around it.
- **Acceptance scenarios conflict with an ADR.** Name the ADR by address and stop;
  the spec is wrong, not the decision.
- **The design requires new infrastructure or a new dependency.** That is a human
  decision, and it is `Type: architecture` work, not a build slice.
- **An Unknown in the spec blocks correctness.** Open the spike; do not implement
  the interpretation that is most convenient today.
- **The ticket's type is not what you are doing.** If you are deciding what the
  change should be rather than making it, the node is `research`, `interface` or
  `architecture` — close this one and open the right one. Do not silently rewrite
  the `Type:` line.
