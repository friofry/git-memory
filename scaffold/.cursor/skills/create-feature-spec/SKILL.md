---
name: create-feature-spec
description: Open a feature folder under specs/ from templates, assign its address and type, cut tickets, and hand it to the approval gate. Use when starting a change larger than a tiny bugfix.
---

# Create feature spec

Open `specs/<NN>-<slug>/` for one outcome, fill the four files, and hand the result
to a human at the approval gate.

The threshold: a change needs a spec when someone other than you would have to
reconstruct what it was for. A one-line fix with a failing test and no design
question runs from a ticket, or from git evidence alone —
[`../../../docs/agents/delivery-workflow.md`](../../../docs/agents/delivery-workflow.md),
"Not every change is a feature".

## Inputs

- The outcome, in one sentence, in the requester's words. This is the evidence that
  closes `M:gate-request`; copy it verbatim rather than paraphrasing it.
- A feature slug, kebab-case, no number prefix.
- Optional related spike and ADR addresses.

## 1. Assign the address

Pick the next free number under `specs/` — `001`, `002`, … — and the address follows
from it. `specs/007-auth-envelope/` is `F:007-auth-envelope`, and nothing else. Its
tickets live under `.scratch/auth-envelope/`, the slug with **no** number prefix,
because the ticket address `T:007/03` already carries the number
([`../../../docs/method/addressing.md`](../../../docs/method/addressing.md)). Do not
store the address anywhere except the `ID:` line: the path is the truth, and `ID:` is
a checksum against it.

## 2. Choose the type

A spec carries exactly one of three values. The other eight are ticket types —
[`../../../docs/method/work-types.md`](../../../docs/method/work-types.md).

| `Type:` | Choose it when | Not when |
|---------|----------------|----------|
| `feature` | something a user can observe becomes true that was not true before | nothing observable changes — that is `architecture` |
| `bug` | you can name the intended behaviour being restored | you can only name the behaviour you now want — that is `feature` |
| `architecture` | a seam moves or a dependency reverses | the module graph is identical afterwards — that is a ticket, not a spec |

Choose before writing a line of body. The type decides which questions the spec has
to answer, and a `bug` spec that cannot name the behaviour it restores is a
`feature` wearing a defect's clothes — it reaches review with no reproduction anyone
can run.

## 3. Write the node header

Copy [`../../../templates/feature-spec.md`](../../../templates/feature-spec.md) into
`specs/<NN>-<slug>/spec.md`. Its header is plain `Key: value` lines, in this order,
no YAML:

```
ID: F:007-auth-envelope
Type: feature
Status: draft
Stage: request
Parent: none
```

Add `Children:` once tickets exist, `Refs:` for the ADRs, terms and method refs this
feature obeys, and `Implemented in:` only at the memory stage. The field rules are
in [`../../../docs/memory.md`](../../../docs/memory.md), "Node headers"; do not
restate them in the spec.

`Stage:` belongs here and nowhere else. A ticket or spike carrying one is a hard
failure in `./scripts/check-memory.sh`.

## 4. Fill the four files

`spec.md`, `design.md`, `acceptance.md` and `decisions.md` — all four are required
while the spec is `draft` or `active`, and `M:gate-approval` does not open until all
four exist and have been read.

1. Fill **Outcome**, **In / Out of scope** and **Known / Assumed / Unknown** before
   any implementation ticket exists. An Unknown with no ticket or spike assigned to
   it is why a feature stalls at `build` with two agents guessing in opposite
   directions.
2. Write acceptance as Given/When/Then in the shape of `M:contract-acceptance` —
   [`../../../docs/method/boilerplates/contract-acceptance.md`](../../../docs/method/boilerplates/contract-acceptance.md).
   The scenarios live in `acceptance.md`; the examples in `spec.md` illustrate and
   do not compete with them.
3. For the content itself — user stories, seams, implementation and testing
   decisions — follow `.agents/skills/grill-with-docs/`, and route its output into these
   four files per
   [`../../../docs/agents/vendored-skills.md`](../../../docs/agents/vendored-skills.md).
4. Link product, domain and ADR documents instead of copying paragraphs. A term this
   feature invents lands in `CONTEXT.md` before the spec is approved, not after.

Move `Stage:` as the work moves: `research` while inventorying with
`.agents/skills/research/`, `spec` once the four files hold content.

## 5. Cut tickets

When implementation slices exist, create `.scratch/<slug>/` with a `spec.md` pointer
at the `specs/` folder and `issues/NN-*.md` per
[`../../../docs/agents/issue-tracker.md`](../../../docs/agents/issue-tracker.md).
Each ticket gets its own `ID:`, `Type:`, `Parent: F:007-auth-envelope`, a
`Blocked by:` line where it depends on another ticket, and a `Refs:` line citing the
boilerplate its body follows. Numbers are unique within a feature: two files
starting `03-` make `T:007/03` ambiguous everywhere at once.

## 6. Hand it to the approval gate

Set `Stage: approval` when the four files are ready to read, assemble the packet, and
put them in front of a human in the `M:approval-checklist` shape —
[`../../../docs/method/boilerplates/approval-checklist.md`](../../../docs/method/boilerplates/approval-checklist.md).

```bash
./scripts/git-memory-packet.sh F:007-auth-envelope approval
```

That profile quotes the four files in full on purpose: a human who approves a summary
approved the summary ([`../prepare-packet/SKILL.md`](../prepare-packet/SKILL.md)).
You may prepare the files and say they are ready. You may not record the approval,
and you may not open `Stage: plan` — `M:gate-approval` in
[`../../../docs/method/gates.md`](../../../docs/method/gates.md).

## Output

- `specs/<NN>-<slug>/` with all four files, and `ID:` / `Type:` / `Status:` /
  `Stage:` / `Parent:` on `spec.md`.
- Optional `.scratch/<slug>/` tickets, each with its own header.
- `./scripts/check-memory.sh` green, and `--strict` green on the new files.

## Stop and escalate when

- The change contradicts an ADR. Say which one, by address, and stop — a spec that
  silently overrides a decision is how the decision gets lost.
- A spike is still unresolved for a blocking Unknown. Timebox the spike under
  `spikes/<slug>/<name>/` as `Type: research` or `Type: prototype`; do not write
  around the Unknown.
- None of the three spec types fits. The request is two features, or it is a ticket.
  Split it rather than inventing a fourth value.
- The outcome sentence still cannot be written after one round of questions. That is
  `M:gate-request` refusing to close, and it is a human's move, not yours.
