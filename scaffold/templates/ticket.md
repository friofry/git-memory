# What this ticket changes, not the area it touches

ID: T:<NN>/<MM>
Type: implementation
Status: needs-triage
Parent: F:<NN>-<slug>
Blocked by:
Refs:

<!--
File: `.scratch/<feature-slug>/issues/<MM>-<slug>.md`, numbered from 01 within the
feature. The folder is the feature's slug with no number prefix —
`.scratch/auth-envelope/`, not `.scratch/007-auth-envelope/` — because the address
carries the number instead: `docs/method/addressing.md`.

- `ID:` — the address this path implies. Ticket 03 of feature 007 is `T:007/03`,
  whatever its slug says. Two files numbered 03 in one feature make every reference
  to `T:007/03` ambiguous at once; renumber the later one and fix its ID line.
- `Type:` — any of the eleven values in `docs/method/work-types.md`. It decides the
  body shape below, so choose it before writing a line of body.
- `Status:` — a triage label, a different vocabulary from a feature's status:
  `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `claimed`,
  `resolved`, `done`, `wontfix` — `docs/agents/triage-labels.md`.
- `Parent:` — the feature this ticket serves, written in full at least once as
  `F:007-auth-envelope`. A ticket with no parent is scratch work, not a ticket.
- `Blocked by:` — other ticket addresses, comma-separated. This ticket is unblocked
  when every address it names is `resolved` or `done`. Delete the line when nothing
  blocks it: a blocker left behind after its ticket resolved is why the frontier
  looks empty while work is waiting.
- `Refs:` — the boilerplate this body follows, plus the terms and ADRs it obeys:
  `M:ticket-interface, TERM:event-envelope`.
- **No stage line.** The delivery stage belongs to the feature and lives on
  `specs/<NN>-<slug>/spec.md`. A stage recorded here is the one-home rule breaking
  where it costs most — two files claiming the same fact and disagreeing silently.
-->

## Body

The body shape comes from `Type:`. Cite the boilerplate on the `Refs:` line and
follow it here; do not paste its prose into this file, or this copy becomes the
version that contradicts the method three features from now.

| `Type:` | Body shape to follow |
|---------|----------------------|
| `implementation`, `feature`, `bug`, `test`, `rework`, `memory` | `M:ticket-implementation` |
| `research` | `M:ticket-research` |
| `prototype` | `M:ticket-prototype` |
| `interface`, `architecture` | `M:ticket-interface` |
| `review` | `M:ticket-review` |

All five are declared under `docs/method/boilerplates/`; resolve one with
`./scripts/git-memory-resolve.sh resolve M:ticket-interface`.

Three types carry an obligation the shared shape does not state:

- A `bug` ticket names the failing test before the fix. The reproduction is the
  first deliverable, not a step in the description.
- A `rework` ticket quotes the blocking finding it answers, verbatim, from the
  review artifact. Rework with no quoted finding is ordinary implementation.
- A `memory` ticket names the file it writes to. "Update the docs" closes without
  anyone being able to check whether it happened.

## Answer

<!-- Research, prototype and interface tickets only. Reserved from the moment the
ticket is written, empty until it is filled, and filled in the same commit that sets
the status to resolved. Then append a one-line pointer to the feature's
decisions.md or map.md, so the next reader finds the answer without opening every
ticket. Delete this heading on tickets that produce code rather than an answer. -->

## Comments

<!-- Append-only, oldest first, each entry naming who and when. Do not rewrite the
body to reflect a comment: the body is what was asked for, the comments are what
happened, and collapsing the two erases the reason the ticket changed shape. -->
