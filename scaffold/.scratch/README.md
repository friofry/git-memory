# Scratch

Work in flight: the tickets that slice a feature up, the review artifacts that judge
the result, and the wayfinding maps that record what was already searched. This file
also keeps the directory present in a fresh clone.

This directory is committed. A global gitignore on some machines matches `.scratch`,
so [`../.gitignore`](../.gitignore) re-includes it explicitly — otherwise half the
tracker is versioned and half silently is not, and nobody notices until an agent
reads a ticket that no longer exists on someone else's machine.

## What lives here

| Path | Holds |
|------|-------|
| `.scratch/<feature-slug>/issues/<MM>-<slug>.md` | one ticket, numbered from `01` within the feature |
| `.scratch/<feature-slug>/reviews/<NN>-<slug>.md` | one review artifact, in the [`templates/review.md`](../templates/review.md) shape |
| `.scratch/<feature-slug>/map.md` | the wayfinding map: notes, decisions so far, fog |
| `.scratch/<feature-slug>/spec.md` | a pointer to `specs/<NN>-<slug>/`, carrying no feature status |

The folder is the feature's slug with **no number prefix** —
`.scratch/auth-envelope/` for `specs/007-auth-envelope/`. The number lives in the
address instead: ticket 03 of that feature is `T:007/03`, so renaming the feature
slug does not invalidate every ticket reference, every `Blocked by:` line and every
PR body that named one. Resolution rules:
[`../docs/method/addressing.md`](../docs/method/addressing.md).

## The node header

Every ticket opens with a block of plain `Key: value` lines. Start from
[`../templates/ticket.md`](../templates/ticket.md), which carries the field rules
and routes each `Type:` to its body boilerplate.

```
ID: T:007/03
Type: interface
Status: ready-for-agent
Parent: F:007-auth-envelope
Blocked by: T:007/01
Refs: M:ticket-interface, TERM:event-envelope
```

Two of those lines are where tickets go wrong most often:

- **`ID:` must equal the address this file's own path implies.** A ticket copied
  from another feature keeps that feature's ID, parent and refs, and then reads as
  authoritative work on a feature it has nothing to do with.
- **No stage line, ever.** The delivery stage belongs to the feature and lives on
  `specs/<NN>-<slug>/spec.md`. A ticket's `Status:` is a triage label from a
  different vocabulary — [`../docs/agents/triage-labels.md`](../docs/agents/triage-labels.md).

## Why intent never lives here

**Nothing durable may live only in this directory.** What the feature must do, why
it was scoped that way, and what it is accepted against belong in
[`../specs/`](../specs/); what a term means belongs in
[`../CONTEXT.md`](../CONTEXT.md); why a boundary was chosen belongs in
[`../docs/adr/`](../docs/adr/). This directory holds the slicing of that intent into
work, and the evidence produced while doing it.

The reason is lifetime. Tickets are written to be closed: a reader six months later
opens the spec, not `issues/04-sign-on-publish.md`, and a requirement that exists
only in a closed ticket has been deleted in every way that matters except literally.
The failure is quiet — the ticket still renders, still looks like documentation, and
is the last place anybody looks.

Conventions for creating and resolving tickets, including the wayfinding
operations, are in [`../docs/agents/issue-tracker.md`](../docs/agents/issue-tracker.md).
