# Work types

The home for the `Type:` vocabulary: eleven values, a closed set, one per node.
`Type:` answers "what kind of work is this?" and nothing else — where a feature sits
in its lifecycle is `Stage:`, and the two never merge (see
[`glossary.md`](glossary.md), "Why Type is not a Stage value").

The line is a plain `Key: value` entry in the node header, required on every spec,
ticket and spike README:

```
Type: interface
```

`./scripts/check-memory.sh` rejects any value outside the table below, and any value
that is not legal for the node kind carrying it.

## The eleven values

| `Type:` | The node exists to… | You picked wrong when… |
|---------|--------------------|------------------------|
| `feature` | deliver a new user-visible outcome | nothing a user can observe changes when it lands — it is `architecture` or `implementation` |
| `bug` | restore intended behaviour | you cannot name the behaviour it restores, only the behaviour you now want — that is a `feature` |
| `research` | answer a question from existing sources | you had to write code that must keep working to get the answer — that is `prototype` |
| `prototype` | answer a question by building something throwaway | the code you wrote is going to be kept — that is `implementation` |
| `architecture` | decide or change a boundary, seam, or dependency direction | no seam moves and no dependency reverses — that is `implementation` |
| `interface` | fix the contract between modules before either is built | both sides already exist and already agree — that is `implementation` or `rework` |
| `test` | add or repair verification without changing behaviour | the suite only goes green after you change production behaviour — that is `implementation` or `bug` |
| `implementation` | make the change the contract already describes | you are still deciding what the change should be — that is `research`, `interface` or `architecture` |
| `review` | independently try to find defects | you are fixing what you find instead of recording it — the fix is `rework` |
| `rework` | act on a blocking review finding | no review artifact names the finding — your own build-loop fixes are `implementation` |
| `memory` | write durable facts and decisions back | you are also changing behaviour — split it; a memory node touches the memory layer only |

The "picked wrong" column is the working test. Apply it to the node you are about to
create, not to the node you wish you were creating.

## Where each type is legal

| Node kind | Legal `Type:` values |
|-----------|---------------------|
| Spec — `specs/<NN>-<slug>/spec.md` | `feature`, `bug`, `architecture` |
| Ticket — `.scratch/<slug>/issues/NN-*.md` | all eleven |
| Spike — `spikes/<slug>/<name>/README.md` | `research`, `prototype` |
| ADR — `docs/adr/NNNN-*.md` | *(no `Type:` line — an ADR is always a decision)* |

A spec answers "what outcome are we buying?", so only the three types that describe
an outcome are legal on one. Everything else is a slice of the work to get there and
belongs on a ticket. A spike is a question with a timebox, so it is `research` or
`prototype` and never anything else.

Worked example — feature `007-auth-envelope` carries `Type: feature` on
`specs/007-auth-envelope/spec.md`; its tickets carry `Type: interface`
(`T:007/03`, fixing the envelope schema between producer and consumer),
`Type: implementation` (`T:007/04`), `Type: test` (`T:007/05`) and `Type: memory`
(`T:007/09`); its spike `S:007/proto-a` carries `Type: prototype`.

## Choosing between adjacent types

Five pairs account for nearly every miscategorised node. Each has a decisive test.

### `research` vs `prototype`

Does answering the question require code that runs? If the answer exists in
something you can read — the codebase, an ADR, upstream docs, an issue thread — it
is `research`, and the output is prose. If you have to build something to see the
answer, it is `prototype`, the code lands in `spikes/<slug>/<name>/`, and it is
thrown away afterwards.

**Failure mode:** a `research` ticket that quietly grows a working branch. The code
then has no spike home, no throwaway marker, and gets merged because it exists.

### `architecture` vs `interface`

`architecture` changes *where the seam is* or *which way a dependency points*.
`interface` changes *what crosses a seam that already exists*. Ask whether the module
graph looks different afterwards: if yes it is `architecture` and probably wants an
ADR; if the graph is identical and only the contract across one edge changed, it is
`interface`.

**Failure mode:** an `interface` ticket that moves a module. It bypasses the
architecture review that a boundary change would have attracted.

### `implementation` vs `rework`

`rework` exists only in response to a blocking finding recorded in a review artifact.
If nobody else found it, it is `implementation`, however late in the cycle you found
it yourself.

**Failure mode:** relabelling your own build-loop fixes as `rework`. The review
record then appears to have caught defects it never saw, and the next person tunes
the review process using a number that is fiction.

### `test` vs `implementation`

A `test` node must leave behaviour identical. Write the test, run it, and watch what
you have to touch to make it pass: if the answer is production behaviour, the node
was `implementation` (the behaviour was missing) or `bug` (the behaviour was wrong).

**Failure mode:** a behaviour change hidden inside a `test` ticket. It reaches
acceptance without anyone having read it as a change, because the type said there was
nothing to accept.

### `memory` vs `review`

`review` looks for defects in a change and produces findings. `memory` writes back
the facts the change made true and produces edits to
[`../../CONTEXT.md`](../../CONTEXT.md), an ADR under [`../adr/`](../adr/), or
`decisions.md`. One reads and judges; the other writes and records.

**Failure mode:** a `memory` node that also touches code. The behaviour change then
sits after the review gate, in the one node type nobody re-reviews.

## Ticket skeletons

Five types have a body skeleton under [`boilerplates/`](boilerplates/). Cite it in
the ticket's `Refs:` line; do not paste it.

| `Type:` | Skeleton |
|---------|----------|
| `research` | [`M:ticket-research`](boilerplates/ticket-research.md) |
| `prototype` | [`M:ticket-prototype`](boilerplates/ticket-prototype.md) |
| `interface` | [`M:ticket-interface`](boilerplates/ticket-interface.md) |
| `implementation` | [`M:ticket-implementation`](boilerplates/ticket-implementation.md) |
| `review` | [`M:ticket-review`](boilerplates/ticket-review.md) |

The other six types have no skeleton on purpose: their bodies come from the
feature's `acceptance.md` or from the finding being answered, and a skeleton would
add ceremony to a ticket that is already fully specified elsewhere.

## Migrating from `/wayfinder`

Upstream `/wayfinder` writes two type values this repository does not use. Rewrite
the line when the ticket arrives:

| `/wayfinder` writes | Write instead |
|---------------------|---------------|
| `Type: grilling` | `research` |
| `Type: task` | `implementation` |

**The two aliases are not in the checker's accepted set, and that is deliberate.** A
ticket carrying `Type: grilling` fails `./scripts/check-memory.sh` with the offending
value named, which costs one edit. Accepting the alias instead would cost the closed
set: two words for one type, tables above that are no longer exhaustive, and a grep
for `Type: research` that silently misses a third of the tickets. A drifted
vocabulary must fail loudly. The same resolution, in the wider context of what
upstream assumes and what this repository answers, is in
[`../agents/vendored-skills.md`](../agents/vendored-skills.md).

## Stop conditions

- **Do not invent a twelfth value.** If none of the eleven fits, the node is two
  nodes; split it. A genuinely missing type is an ADR-shaped decision, not a header
  edit.
- **Do not change a node's `Type:` because the work moved on.** Type describes what
  the node exists to do, and that does not change when the feature reaches the next
  stage. If the intent changed, close the node and open the right one.
- **Do not put a `Stage:` line on a ticket or spike** to record how far its type has
  got. Stage belongs to the feature, in one file — see
  [`../agents/delivery-workflow.md`](../agents/delivery-workflow.md).
- **If two types fit equally well, split the ticket.** A ticket that is half
  `interface` and half `implementation` will be reviewed as neither.
