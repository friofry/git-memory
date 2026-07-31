# The method layer

This directory is the home for **method truth** — how work in this repository is
named, typed, addressed, gated, packaged and handed over. Nothing here describes
the product. Everything here describes the machinery that carries a product change
from a request to durable memory.

The governing split, also stated in [`../memory.md`](../memory.md):

> **Project truth** lives in project layers: `CONTEXT.md`, `docs/domain/`,
> `docs/architecture/`, `docs/adr/`, `specs/`.
> **Method truth** lives in `docs/method/`.
> Project artifacts reference method artifacts by `M:` address instead of copying
> the prose.

## Why method truth is separated

**A glossary that also holds process stops being a glossary.**
[`../../CONTEXT.md`](../../CONTEXT.md) is the canonical domain vocabulary and
nothing else. A reviewer looking up what "auth envelope" means should not scroll
past a review-severity rubric to find it. Process prose in the glossary is skipped
by the people who need the glossary and lost to the people who need the process.

**Boilerplate without a home is copied.** A ticket skeleton that lives nowhere gets
pasted into each new ticket. The fifth copy contradicts the first, both look
authoritative, and nothing fails. A method ref makes the copy unnecessary: the
ticket cites [`M:ticket-interface`](boilerplates/ticket-interface.md) and inherits
every later correction.

**The two layers change at different rates.** Project truth changes when the
product changes — once per feature. Method truth changes when you decide to work
differently — rarely, and deliberately. Files that change at different rates belong
apart; that is the growth rule in [`../memory.md`](../memory.md).

**Method truth is portable, project truth is not.** This scaffold is dropped into
repositories that share no domain. `docs/method/` ships intact; `CONTEXT.md` starts
empty in every one of them.

## What belongs here

| In `docs/method/` | In a project layer |
|-------------------|--------------------|
| What a gate demands before a stage may move | Whether *this* feature has passed it — `specs/<NN>-<slug>/spec.md` |
| The body skeleton for a `Type: interface` ticket | The actual interface being fixed — `.scratch/auth-envelope/issues/03-*.md` |
| What `blocking` and `non-blocking` mean in a review | The findings of one review — a document in the `templates/review.md` shape |
| Which context layers a `build` packet carries | The packet itself — generated, never committed |
| What "acceptance" is as a contract shape | The Given/When/Then for a feature — `specs/<NN>-<slug>/acceptance.md` |

If a sentence would still be true in a repository that builds something else
entirely, it belongs here. If it names a domain term, a module or a feature, it
does not.

## The six `M:` ref families

Six prefixes, no others. A seventh family is an ADR-shaped decision, not a
convenience — write it up under [`../adr/`](../adr/) first.

| Family | Purpose | Declared in |
|--------|---------|-------------|
| `M:gate-*` | a gate definition and the evidence it demands | [`gates.md`](gates.md) |
| `M:ticket-*` | a ticket body skeleton for one work type | [`boilerplates/`](boilerplates/) |
| `M:review-*` | review criteria and severity language | [`boilerplates/`](boilerplates/) |
| `M:packet-*` | a context-assembly profile for one stage | [`packet-profiles.md`](packet-profiles.md) |
| `M:handoff-*` | a session or PR handoff shape | [`boilerplates/`](boilerplates/) |
| `M:contract-*` | a reusable contract snippet (acceptance, invariant, timebox) | [`boilerplates/`](boilerplates/) |

## How a method ref is declared

A method ref is declared by a markdown heading anywhere under `docs/method/` whose
text is exactly the address wrapped in backticks — a level-2 heading reading
`` ## `M:gate-approval` `` in [`gates.md`](gates.md) declares `M:gate-approval` and
resolves to that heading's anchor. Definition and resolution are the same one-line
grep, the document stays readable, and a ref cannot exist without prose underneath
it explaining what it means.

A heading-shaped line is a declaration wherever it appears, including inside a
fenced code block. Never paste a declaration line into an example; describe the
shape in prose, as the paragraph above does.

`scripts/git-memory-resolve.sh` is the only thing that reads these headings, and it
requires exactly one declaration per address. Two headings declaring the same
address is a failure, not a merge to be resolved by whoever greps first.

## Adding a new method ref

1. **Check it is method truth.** Apply the test above. A rule that names a domain
   term belongs in a project layer.
2. **Pick the family.** One of the six. If none fits, you are adding a family, which
   is an ADR.
3. **Pick the file.** A gate goes in [`gates.md`](gates.md); a stage profile in
   [`packet-profiles.md`](packet-profiles.md); everything else is a new or existing
   file under [`boilerplates/`](boilerplates/). One address may not span two files.
4. **Write the heading, then the prose.** The prose is the point; the address is the
   handle. State the failure mode the ref exists to prevent — that is what makes a
   reader stop skimming.
5. **Reference it, never copy it.** Add the address to the `Refs:` line of the nodes
   that obey it: `Refs: M:gate-approval, TERM:event-envelope`.
6. **Run `./scripts/check-memory.sh`.** It fails on a duplicate declaration and on a
   `Refs:` entry that resolves to nothing.

## Never copy the prose

Copying a boilerplate into a ticket and then editing it is the failure this layer
exists to prevent. The copy looks like the method and is not, so the next reader
follows a rule that was retired three features ago and no check can tell them.

The rule: a node file names the address; the prose stays here. Where a restatement
genuinely has to exist — `AGENTS.md`, `rules/` — it stays short and cites its home,
exactly as [`../memory.md`](../memory.md) requires (`— M:gate-checks`).

## Files in this directory

| File | Home for |
|------|----------|
| [`glossary.md`](glossary.md) | The vocabulary of work itself — node, address, axis, gate, packet, projection |
| [`addressing.md`](addressing.md) | The six address families, their resolution rules, and worked examples |
| [`work-types.md`](work-types.md) | The eleven `Type:` values, where each is legal, and the `/wayfinder` mapping |
| [`gates.md`](gates.md) | The seven gates: who opens each, what evidence closes it, what it prevents |
| [`packet-profiles.md`](packet-profiles.md) | The six packet layers and which of them each stage carries |
| [`boilerplates/`](boilerplates/) | The referenced prose: ticket skeletons, review language, handoff and contract shapes |

Stage vocabulary is not here. Stages are the delivery lifecycle and live in
[`../agents/delivery-workflow.md`](../agents/delivery-workflow.md); gates are the
enforcement projection of that table and add no stage to it.

## Stop conditions

- **Do not add a file here to hold one paragraph.** Add a heading to an existing
  file. This directory is indexed by address, not by filename.
- **Do not write a ref you will not reference.** An `M:` address with no citer is
  prose nobody asked for; delete it or cite it.
- **Do not put a feature, a module or a domain term in this directory.** The moment
  method prose names `007-auth-envelope` as anything other than an illustration, the
  layer has leaked.
- **Do not restate a gate, a type table or a packet profile in a skill.** Skills
  reference `M:` addresses. A skill that repeats a gate's evidence list will drift
  from it within two changes.
