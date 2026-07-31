# Feature name

ID: F:<NN>-<slug>
Type: feature
Status: draft
Stage: request
Parent: none
Children:
Refs:
Implemented in:

<!--
Header: plain `Key: value` lines, in this order, no YAML front matter — Status and
Stage are read with sed, and front matter would break every extraction. The line
rules live in `docs/memory.md`; each vocabulary lives where its bullet says. Paths
in these comments are written from the repository root and are not links: a
template is copied to a depth it cannot know, so a relative link inside one is
wrong the moment it is used.

- `ID:` — the address this file's own path implies. `specs/007-auth-envelope/spec.md`
  is `F:007-auth-envelope` and nothing else. A mismatch means the file was copied
  from another feature rather than created, and its parent and refs still point at
  that feature's work.
- `Type:` — `feature`, `bug` or `architecture`. Those three are the only values legal
  on a spec; the other eight are ticket types — `docs/method/work-types.md`.
- `Status:` — `draft`, `active` or `implemented`. This file is the only home for it.
  No sibling file and no `.scratch/` pointer repeats it.
- `Stage:` — `request` through `memory` — `docs/agents/delivery-workflow.md`. Specs
  only. The same line on a ticket or a spike is the one-home rule breaking.
- `Parent:` — `none` for a standalone feature, otherwise the address of the feature
  this one was split out of.
- `Children:` — the feature's tickets once they exist, comma-separated, written as
  `T:007/01, T:007/02`. Delete the line while there are none.
- `Refs:` — the ADRs, terms and method refs this feature obeys, written as
  `ADR:0012, TERM:event-envelope, M:gate-approval`. Reference them; a pasted copy
  of their prose drifts and no check catches it.
- `Implemented in:` — the PR or commit that shipped it, written in the memory stage.
  Delete the line until then.
-->

## Outcome

<!-- One sentence, in the user's language, naming what is different for them once
this ships. Not a plan, not a component list, not a restatement of the title. This
sentence is the evidence M:gate-request demands — `docs/method/gates.md`. -->

## User scenario

<!-- One concrete run through the change from outside the system, with real values:
a publisher signs an order.placed event with key k-2026-07, and a consumer holding
only the retired key rejects it. Not a taxonomy of every user type. -->

## In scope

<!-- The observable behaviour this feature changes. Tasks, file lists and sequencing
belong on tickets under `.scratch/<slug>/issues/`. -->

## Out of scope

<!-- What a reader would reasonably assume is included and is not — key rotation
policy, the admin UI, the replay job. An empty section here is a boundary nobody has
drawn yet, not a feature without boundaries. -->

## Domain concepts

<!-- Name the `CONTEXT.md` terms this feature is written in and link them. Do not
redefine them here: a term with no glossary entry is an entry to write, not a
definition to inline. A concept this feature invents is a glossary change, and it
lands in CONTEXT.md before this spec is approved. -->

## Acceptance examples

<!-- Two or three illustrations that make the outcome concrete for a reader. The
scenarios the feature is accepted against live in `acceptance.md` beside this file,
in the Given/When/Then shape of M:contract-acceptance —
`docs/method/boilerplates/contract-acceptance.md`. Do not maintain both: when the
two disagree, acceptance.md wins and this section is what misled someone. -->

## Constraints

<!-- Limits the implementation must respect: backward compatibility, a latency
budget, a fixed external contract, a date. Each one cites its home — ADR:0012, a
file under `rules/`, a term in CONTEXT.md. A constraint with no home is a
preference, and it gets argued about during review instead of before it. -->

## Known

<!-- Facts you can point at: a file path, a measurement, a decided ADR. What you
cannot cite belongs under Assumed. -->

## Assumed

<!-- Taken on trust, each with what breaks if it turns out false. "The signer runs
in-process, so key material never crosses a network boundary" is an assumption;
"the signer probably runs in-process" is an Unknown. -->

## Unknown

<!-- Open questions, each with the ticket or spike that will answer it — T:007/02,
S:007/proto-a. An Unknown with nothing assigned to it is why a feature stalls in the
build stage with two agents guessing in opposite directions. -->

## Risks

<!-- Named failure modes and what you would do about each: a rotation mid-flight
drops queued events, mitigated by verifying against the envelope's own keyId. One
line each. Not a severity matrix, and not "the schedule may slip". -->

## Related

- Design: `./design.md`
- Acceptance: `./acceptance.md`
- Decisions: `./decisions.md`
- ADRs / spikes: …

<!-- The first three are required while this spec is draft or active, and
M:gate-approval does not open until all three exist and have been read —
`docs/method/gates.md`. Sibling files go by path because they sit beside this one;
ADRs, spikes and method refs go by address. -->
