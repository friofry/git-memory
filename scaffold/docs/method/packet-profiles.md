# Packet profiles

A **packet** is the context envelope assembled for one agent turn at one stage:
six layers, of which you send only the ones the stage needs. This file is the home
for which layers each stage carries and which files each layer is built from;
other files reference the `M:packet-*` address and do not restate the matrix.

Omission is the whole point. Every layer you add competes for the reader's
attention with the layer that answers the question, and attention degrades long
before the context window fills. A build packet that carries the whole glossary is
a build packet nobody reads: the ticket it exists to deliver is now on page four,
behind forty terms the builder already knows. Cutting a layer is not a saving to
be traded away under a deadline — it is what makes the remaining layers legible.

## The six layers

| Layer | Contains | Assembled from |
|-------|----------|----------------|
| **Route** | node address, stage, branch, requested action | the `ID:`/`Stage:` lines, `git branch --show-current` |
| **Objective** | the intended outcome, one paragraph | `spec.md` Outcome, or `active-context.md` |
| **Contract** | acceptance, scope, constraints, rules | `acceptance.md`, `spec.md` scope, `rules/`, ADR refs |
| **Memory** | glossary and architecture context | `CONTEXT.md`, `docs/domain/`, `docs/architecture/`, ADRs |
| **Slice** | the current ticket, files, commands | `.scratch/…`, `AGENTS.md`, changed paths |
| **Evidence** | tests, review, CI, blockers | review doc, check output, ticket answers |

Route is never omitted. A packet without it is a wall of text with no answer to
"which node, which stage, what am I being asked to do" — and that question is the
one an agent gets wrong most expensively.

## The profile matrix

This table is canonical. Cite a row by its `M:packet-*` address rather than
copying the ticks into another document.

| Stage | Route | Objective | Contract | Memory | Slice | Evidence |
|-------|:-----:|:---------:|:--------:|:------:|:-----:|:--------:|
| `research` | ● | ● | ○ | ● | ○ | ○ |
| `spec` | ● | ● | ● draft | ● | ○ | ○ |
| `approval` | ● | ● | ● | ● | ○ | ○ |
| `plan` | ● | ● | ● | ○ | ● | ○ |
| `build` | ● | ○ | ● | ○ | ● | ○ |
| `checks` | ● | ○ | ● | ○ | ● | ● |
| `review` | ● | ○ | ● | ● | ● | ● |
| `rework` | ● | ○ | ● | ○ | ● | ● |
| `acceptance` | ● | ● | ● | ○ | ○ | ● |
| `memory` | ● | ○ | ○ | ● | ○ | ● |

● = required, ○ = omitted.

Two of the twelve stages have no profile. `request` and `ci` have no agent turn to
assemble a packet for — one is a human writing a sentence, the other is GitHub
Actions running a workflow. Their stage rows live in
[`../agents/delivery-workflow.md`](../agents/delivery-workflow.md); asking for
`git-memory-packet.sh F:007-auth-envelope ci` is an error, not an empty packet.

## `M:packet-research`

**Layers.** Route, Objective, Memory.

**Files read.** The header and Outcome of `specs/007-auth-envelope/spec.md`;
[`../../CONTEXT.md`](../../CONTEXT.md); `docs/architecture/`; the titles of ADRs
under [`../adr/`](../adr/); any `spikes/auth-envelope/` README already present.

**Token shape.** Outcome quoted in full. Glossary entries the question touches
quoted in full; the rest of `CONTEXT.md` referenced by `TERM:` address. ADRs
carried as address plus title only — an ADR body enters the packet when the
research names it, not before.

**Most commonly over-read.** The whole ADR directory. Research exists to inventory
what is already known and name the unknowns; loading every past decision
substitutes reading for asking, and the questions never get written down.

## `M:packet-spec`

**Layers.** Route, Objective, Contract (draft), Memory.

**Files read.** `specs/007-auth-envelope/spec.md` and `research.md`;
`specs/007-auth-envelope/acceptance.md` as it currently stands;
[`../../CONTEXT.md`](../../CONTEXT.md); `docs/architecture/`; the ADRs named in
the spec's `Refs:` line.

**Token shape.** The Contract layer enters as a **draft**: acceptance criteria are
being written this turn, so they are quoted as the current state of a document
under edit, never as a constraint to satisfy. Research findings summarised to
their conclusions; the spike that produced them referenced by `S:007/proto-a`.

**Most commonly over-read.** Other features' specs, pulled in for a shape to copy.
The shape is in [`../../templates/feature-spec.md`](../../templates/feature-spec.md);
another feature's content only imports its scope creep.

## `M:packet-approval`

**Layers.** Route, Objective, Contract, Memory.

**Files read.** All four of `spec.md`, `design.md`, `acceptance.md` and
`decisions.md` under `specs/007-auth-envelope/`, plus the ADRs and glossary terms
they cite.

**Token shape.** The one packet where full quotation is the point. A human is
being asked to read and say yes, so nothing that carries meaning is summarised —
summarising the thing under approval approves the summary. Glossary and ADRs
still enter by address, expanded only where the four files depend on them.

**Most commonly over-read.** Source code. `M:gate-approval` is about meaning and
architecture — see [`gates.md`](gates.md) — and a diff in the packet reliably
turns the conversation into an implementation review before the meaning is
agreed.

## `M:packet-plan`

**Layers.** Route, Objective, Contract, Slice.

**Files read.** `spec.md` scope and Out of scope; `acceptance.md` in full;
`design.md` seams; [`../../rules/`](../../rules/); the command list in
[`../../AGENTS.md`](../../AGENTS.md); whatever already exists under
`.scratch/auth-envelope/issues/`.

**Token shape.** Acceptance scenarios quoted in full — they are what the tickets
are cut against. Design summarised to its seams and the files behind each one.
Existing tickets carried as `T:007/NN` plus title, so the planner sees the queue's
shape without re-reading its contents.

**Most commonly over-read.** The glossary. Planning names slices and their order;
it does not define terms, and a Memory layer here mostly produces tickets written
in vocabulary the spec never used.

## `M:packet-build`

**Layers.** Route, Contract, Slice.

**Files read.** One ticket —
`.scratch/auth-envelope/issues/03-envelope-signing.md`; the acceptance scenarios
that ticket satisfies; [`../../rules/`](../../rules/); the commands in
[`../../AGENTS.md`](../../AGENTS.md); the source files the ticket names.

**Token shape.** Ticket quoted in full. Its acceptance scenarios quoted in full.
The spec referenced by `F:007-auth-envelope` and not expanded — if the builder
needs the spec to understand the ticket, the ticket is underspecified and that is
a planning defect, not a packet defect. Objective is omitted for the same reason:
the outcome has already been compiled into acceptance criteria.

**Most commonly over-read.** The rest of the ticket queue. A builder holding nine
other tickets writes code for slices that are not theirs, and the resulting diff
fails review on scope rather than on correctness.

## `M:packet-checks`

**Layers.** Route, Contract, Slice, Evidence.

**Files read.** The command list in [`../../AGENTS.md`](../../AGENTS.md); the
changed paths; the output of the runs so far; the acceptance scenarios the diff
claims to satisfy.

**Token shape.** Commands quoted verbatim, because they are pasted into the PR
body to close `M:gate-checks`. Failing output quoted in full; passing output
reduced to one line per command. The diff carried as a path list, not as content.

**Most commonly over-read.** The spec. At `checks` the question is whether the
commands pass on this commit; re-reading the spec invites a design change at the
exact moment the loop should be going green.

## `M:packet-review`

**Layers.** Route, Contract, Memory, Slice, Evidence.

**Files read.** The full diff against the merge base;
`specs/007-auth-envelope/acceptance.md`; [`../../rules/`](../../rules/);
`docs/architecture/`; [`../../CONTEXT.md`](../../CONTEXT.md);
[`../../templates/review.md`](../../templates/review.md); the check output from
the previous stage.

**Token shape.** The widest packet in the set, and deliberately so: a review runs
two axes and each one needs a different half. Standards needs `rules/`,
architecture and the glossary; Spec needs `acceptance.md`. Diff quoted in full;
everything else summarised with addresses so a finding can cite `ADR:0012` or
`TERM:event-envelope` precisely.

**Most commonly over-read.** The commit-by-commit history. Reviewing the path the
builder took instead of the state they arrived at spends the reviewer's attention
on code that no longer exists.

## `M:packet-rework`

**Layers.** Route, Contract, Slice, Evidence.

**Files read.** The review artifact's blocking findings; the ticket under
`.scratch/auth-envelope/issues/`; the acceptance scenario each finding names; the
commands in [`../../AGENTS.md`](../../AGENTS.md).

**Token shape.** Blocking findings quoted in full, each with the file and line it
names. Non-blocking findings carried as titles only — they are ticket material,
not this turn's work. Memory is omitted because rework changes code the reviewer
has already read against the glossary.

**Most commonly over-read.** The non-blocking half of the review. Fixing it now
grows the diff past the version that was reviewed, which forces a second full
review and turns a two-line correction into another day.

## `M:packet-acceptance`

**Layers.** Route, Objective, Contract, Evidence.

**Files read.** The Outcome of `specs/007-auth-envelope/spec.md`; every
Given/When/Then in `acceptance.md`; the CI run on the head commit; the demo
artifacts posted to the PR.

**Token shape.** Scenarios quoted in full, each followed by one line of evidence
and a verdict. No code, no ticket contents, no design. Objective returns here
after five stages away, because acceptance is the first moment since `approval`
that anyone compares the result to what was originally wanted.

**Most commonly over-read.** The diff. Reading it turns the accepting human into a
second reviewer, and the scenario that nobody demonstrated passes unnoticed while
they are busy reading code — the exact failure `M:gate-acceptance` exists to
prevent, in [`gates.md`](gates.md).

## `M:packet-memory`

**Layers.** Route, Memory, Evidence.

**Files read.** [`../../CONTEXT.md`](../../CONTEXT.md); `docs/domain/`; the ADRs
under [`../adr/`](../adr/); `specs/007-auth-envelope/decisions.md`; the review
artifact; the merged PR's summary.

**Token shape.** The glossary entries and ADRs the change touches quoted in full,
because they are being edited and an edit needs the current wording. Everything
else by address. Evidence enters as decisions and findings, not as code.

**Most commonly over-read.** The full diff, on the theory that memory is written
from what changed. It is written from what was decided — the one-home rule in
[`../memory.md`](../memory.md) picks the destination, and a diff cannot tell you
whether a choice was local to this feature or global to the project.

## How to assemble one

```bash
./.git-memory-scripts/git-memory-packet.sh F:007-auth-envelope build
./.git-memory-scripts/git-memory-packet.sh F:007-auth-envelope review --format json
./.git-memory-scripts/git-memory-packet.sh T:007/03 build --budget 8000
```

The script resolves the address through `.git-memory-scripts/git-memory-resolve.sh`, reads the
`Stage:` line to pick the profile, and prints the assembled packet to stdout. It
writes nothing into the repository. Run `--help` for the full usage block.

When `--budget` binds, summarise **within** a layer — shorten quotations, drop
ADR bodies back to titles, list changed paths instead of diff content. Never drop
a layer the profile marks required. Omission is a decision made per stage in the
matrix above, not per turn under budget pressure, and a packet missing a required
layer is worse than a long one: the agent cannot tell that it is missing.

## Rejected framings

- **Cache the assembled packet under `build/`.** A packet is a projection of files
  that change on every commit, so a cached one is stale the moment a ticket is
  claimed or a review lands — and detecting that staleness costs exactly one
  reassembly, which is the work the cache was avoiding. Generate per turn and
  commit nothing.
- **Key the profile on the skill instead of the stage.** The stage is evidence,
  recorded as a `Stage:` line in `specs/007-auth-envelope/spec.md`; the skill is
  intent, chosen fresh each turn. Two different skills run at `build` and both
  need the same context, so a skill-keyed table would carry duplicate rows that
  drift apart. Worse, a packet could not be assembled until the agent had already
  decided what to do — and `acceptance` runs no skill at all while still needing
  a packet.
- **Send every layer and let the model ignore the rest.** This treats the context
  window as the scarce resource. Attention is the scarce resource: an irrelevant
  layer does not sit inertly, it competes, and the cost lands as a builder who
  implements the spec's scope rather than the ticket's.

The `M:` families and how a method address is declared are in
`docs/method/README.md`. Which evidence a stage transition demands is in
[`gates.md`](gates.md).
