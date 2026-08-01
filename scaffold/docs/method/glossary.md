# Method glossary

The vocabulary of work itself. Domain vocabulary — what the product's nouns mean —
lives in [`../../CONTEXT.md`](../../CONTEXT.md); this file is the home for the words
that describe how work is addressed, typed, moved and proved.

Use these terms exactly, in specs, tickets, commits, prompts, PR bodies and skills.
Synonyms listed under `_Avoid_` cause real drift and must not be used as the name.

## Terms

**Node** — a file that carries a header of plain `Key: value` lines and represents
one unit of work: a spec (`specs/007-auth-envelope/spec.md`), a ticket
(`.scratch/auth-envelope/issues/03-envelope-schema.md`), or a spike README. A node
is addressable, typed and parented. A document with no such header — an ADR, a
glossary, this file — is not a node and never gains one.
_Avoid_: item, entity, record.

**Address** — a short identifier derived from a node's path, in one of six families
(`F:`, `T:`, `S:`, `ADR:`, `TERM:`, `M:`). The path is the truth; the address is a
projection of it. Nothing is stored under an address that is not already stored at a
path — see [`addressing.md`](addressing.md).
_Avoid_: ID, key, slug. (`ID:` is the header line that carries the address, not
another word for it; a slug is one path segment inside one.)

**Axis** — one of the six independent questions asked of a node: Address, Type,
Stage, Status, Owner, Evidence. Each axis has exactly one home, and no line answers
two of them. Confusing two axes is the failure this model exists to prevent.
_Avoid_: field, attribute, dimension.

**Type** — what kind of work a node exists to do, recorded as a `Type:` line from a
closed set of eleven values. Type is a property of the node and does not change as
the feature advances — see [`work-types.md`](work-types.md).
_Avoid_: category, kind, label. (A label is a triage value carried on `Status:` —
see [`../agents/triage-labels.md`](../agents/triage-labels.md).)

**Stage** — the position of a *feature* in the twelve-step delivery lifecycle,
recorded as a `Stage:` line on `specs/<NN>-<slug>/spec.md` and nowhere else. Tickets
and spikes have no stage; a `Stage:` line on either is a hard failure. The
vocabulary is owned by
[`../agents/delivery-workflow.md`](../agents/delivery-workflow.md).
_Avoid_: phase, step, state.

**Status** — how far along a node is, coarsely: `draft` | `active` | `implemented`
on a spec, a triage label on a ticket. Status is the value humans and generated
tables speak in; Stage is the fine-grained position underneath it.
_Avoid_: state, progress, stage.

**Gate** — a named moment where a stage transition is blocked until specific
evidence exists. Seven of them, each with an `M:gate-*` address in
[`gates.md`](gates.md). A gate performs no work and adds no stage; it decides
whether the move is allowed and names what would prove it.
_Avoid_: checkpoint, milestone, sign-off.

**Packet** — the context envelope assembled for one agent turn at one stage, from
six layers: Route, Objective, Contract, Memory, Slice, Evidence. A stage profile
names which of the six that stage carries, and omission is deliberate — the reasons
and the matrix are in [`packet-profiles.md`](packet-profiles.md). A packet is
computed per turn and never committed.
_Avoid_: prompt, context dump, payload.

**Evidence** — an artifact outside the claim that makes the claim checkable: a file
that exists, a command that passed, a review document, a CI run on a named commit, a
PR approval. A `Stage:` line is a claim; the review it points at is evidence. A
stage line that no evidence supports is worse than no line at all.
_Avoid_: assertion, self-report, "the status says".

**Projection** — a view computed from the repository rather than stored in it: an
address, the work graph, a packet, the frontier. Projections print to stdout and are
not committed, so there is no stale-generated-file failure mode to check. The one
exception is the generated specs table, which lives between markers and is rebuilt
by `./.git-memory-scripts/check-memory.sh --fix`.
_Avoid_: cache, export, build artifact.

**One-home rule** — every fact has exactly one file that owns it; other files link
rather than restate, and a restatement that must exist ends with a pointer to its
home. This is what makes every other term above safe to rely on. Owned by
[`../memory.md`](../memory.md).
_Avoid_: single source of truth (too broad — it says nothing about which file).

**Method ref** — an `M:` address naming a piece of method prose, declared by a
heading under `docs/method/` and cited from a node's `Refs:` line. A ref is how a
node obeys a rule without carrying a copy of it.
_Avoid_: include, import, citation.

**Boilerplate** — the reusable prose a method ref points at: a ticket skeleton,
review severity language, a handoff shape, a contract snippet. Lives under
[`boilerplates/`](boilerplates/) and is referenced, never pasted. Distinct from
`templates/`, which holds empty forms a human copies to create a new file — a
template becomes a file, a boilerplate stays here.
_Avoid_: template, snippet, pattern.

**Frontier** — the tickets of one feature that are open, unblocked and unclaimed;
the lowest-numbered one is what to work next. A projection over ticket nodes,
computed by scanning `.scratch/<slug>/issues/`, never written down — see
[`../agents/issue-tracker.md`](../agents/issue-tracker.md).
_Avoid_: backlog, queue, next up.

**Baton** — the minimum a handoff carries so the next session can act without the
previous conversation: node address, stage, unresolved blocker, next expected check,
memory-update delta, commands run. The baton crosses a session boundary in the PR
body, not in a temp directory that dies with the machine.
_Avoid_: summary, status update, notes.

## Relationships

- A **node** has exactly one **address**, derived from its path.
- The six **axes** each have one home. A node file carries `Type:` and `Status:`; a
  spec also carries `Stage:`; **Owner** is read from the stage table and stored
  nowhere; **Evidence** lives in the artifacts themselves.
- A **gate** guards one **stage** transition and is closed by **evidence**.
- A **packet** is assembled for one **node** at one **stage**, and carries the
  layers that stage's profile names.
- A **method ref** points at **boilerplate**. A node's `Refs:` line holds refs; the
  node body never holds the prose.
- An **address**, the work graph, a **packet** and the **frontier** are all
  **projections** of the paths and the header lines.
- The **one-home rule** is the invariant underneath all of the above: one axis, one
  home, one owner per fact.
- The **baton** is what crosses a session boundary when the **frontier** has not
  moved and the work is mid-**stage**.

## Rejected framings

**Why not a database.** Git already stores, versions, reviews, branches and
distributes these files; a database is a second source of truth that `git clone`
does not carry and a pull request diff cannot review. Every query this system needs
— resolve an address, list the frontier, walk the graph, assemble a packet — is a
scan over paths and header lines and finishes in under a second at this scale. The
property being protected is that an agent holding only the working tree can recover
state; a database breaks it on the first offline session.

**Why not YAML front matter.** Node headers are plain `Key: value` lines so that
`sed -n 's/^Status: *//p'` keeps working and every consumer stays parser-free. A
plain header also survives what actually happens to these files: a partial read, a
diff hunk, a paste into a prompt. Front matter invites nesting, and nesting invites
storing a derived value — an `owner:` key under a `meta:` block — which is exactly
the second copy this model forbids. The cost is real and accepted: no typed lists,
no comments, no nesting.

**Why Type is not a Stage value.** They answer different questions — "what kind of
work is this?" against "where is this feature in its lifecycle?". `research` is both
a stage name and a type name, and that is not a collision: a `Type: research` ticket
can be opened while its feature sits at `Stage: build`. Fold them together and a
feature has to be "in the research type", and a `review` ticket and a `test` ticket
can no longer coexist at one stage. The failure mode is concrete: a ticket that
grows a `Stage:` line, putting feature position in two files that will disagree
within a day.

**Why Owner is derived and never stored.** Who acts next is a function of the stage,
and [`../agents/delivery-workflow.md`](../agents/delivery-workflow.md) already holds
that function for all twelve stages. Ownership changes at every transition, so a
stored `Owner:` line is wrong more often than it is right, and it is wrong silently
— nothing checks it, because there is nothing to check it against. Read the owner
from the table; no node file gains an `Owner:` line.
