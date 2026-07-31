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

## A triage `Status:` is not a feature `Status:`

The same key means two different things depending on which node carries it, and
mixing them is the most common header error.

| Node | What `Status:` means | Vocabulary |
|------|---------------------|------------|
| Ticket — `.scratch/<slug>/issues/NN-*.md` | Triage state of one slice of work | The two tables above |
| Spec — `specs/<NN>-<slug>/spec.md` | How far the whole feature got | `draft` \| `active` \| `implemented` — see [`delivery-workflow.md`](delivery-workflow.md) |
| Spike — `spikes/<slug>/<name>/README.md` | Nothing; a spike carries no `Status:` line | — |

A spec therefore carries no triage label, and a ticket carries no feature status.
`Status: ready-for-agent` on a spec and `Status: active` on a ticket are both
rejected by `scripts/check-memory.sh` — each value is checked against the
vocabulary its node kind is allowed to use, not against the union of the two.

Feature progress has a second, finer line that only a spec carries: `Stage:`. A
ticket or spike with a `Stage:` line is a hard failure — see
[`../memory.md`](../memory.md), "Node headers".

## `Type:` is a separate axis from `Status:`

`Status:` answers "how far along is this?". `Type:` answers "what kind of work is
this?" — and the answer does not change as the work progresses. A ticket carries
both lines, they move independently, and neither implies the other: a
`Type: research` ticket can be `needs-info` today and `resolved` tomorrow while
staying `Type: research` forever.

The eleven `Type:` values live in [`../method/work-types.md`](../method/work-types.md).
Do not encode a type as a label — `needs-research` is not in the tables above, and
adding it would put one axis in two homes with no way to tell which is current.
