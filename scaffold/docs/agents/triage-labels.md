# Triage Labels

The vendored skills speak in terms of five canonical triage roles. This file maps
those roles to the label strings used in this repo's local-markdown tracker, and
adds the labels this repo needs beyond triage.

| Label in mattpocock/skills | Label in our tracker | Meaning                                  |
| -------------------------- | -------------------- | ---------------------------------------- |
| `needs-triage`             | `needs-triage`       | Maintainer needs to evaluate this issue  |
| `needs-info`               | `needs-info`         | Waiting on reporter for more information |
| `ready-for-agent`          | `ready-for-agent`    | Fully specified, ready for an AFK agent  |
| `ready-for-human`          | `ready-for-human`    | Requires human implementation            |
| `wontfix`                  | `wontfix`            | Will not be actioned                     |

Three more are in use here and have no upstream role:

| Label | Meaning | Written by |
|-------|---------|------------|
| `claimed` | An agent has taken this ticket and is working it | `/wayfinder`, `implement-feature` |
| `resolved` | A wayfinding question is answered, under an `## Answer` heading | `/wayfinder` |
| `done` | An implementation ticket's work has landed | `/to-tickets` queues, closed by the builder |

## Where the label goes

On a ticket file under `.scratch/<slug>/issues/`, near the top, in either form:

```md
**Status:** ready-for-agent
Status: resolved
```

The bold form is what upstream `/to-tickets` writes; the plain form is older.
Both are read the same way. `scripts/check-memory.sh` rejects any value outside
the two tables above, so a fourth vocabulary shows up as a failing check rather
than as drift.

A **spec** carries no triage label: its state is the `Status:` and `Stage:` lines
described in [`delivery-workflow.md`](delivery-workflow.md).
