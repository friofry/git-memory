# Spike — the question this answers, in one line

ID: S:<NN>/<name>
Type: prototype
Parent: F:<NN>-<slug>
Refs:

<!--
File: `spikes/<feature-slug>/<name>/README.md`. The address names the directory —
`S:007/proto-a` is `spikes/auth-envelope/proto-a/` — and this README is the node
file inside it. A spike directory without one records no question, carries no ID to
check against the path, and leaves no trace of what it settled:
`docs/method/addressing.md`.

- `ID:` — the address this path implies, `S:007/proto-a` for proto-a under feature
  007. The number is the feature's, not the spike's.
- `Type:` — `research` or `prototype`, and nothing else. Research answers from what
  already exists; a prototype builds something throwaway to answer it —
  `docs/method/work-types.md`.
- `Parent:` — the feature that raised the question, in full: `F:007-auth-envelope`.
  A spike with no parent answers a question nobody asked.
- `Refs:` — the terms, ADRs and method refs the experiment is bound by.
- **No status line and no stage line.** A spike is not tracked, it is timeboxed. Its
  outcome is tracked on the ticket or spec that asked the question.
-->

## Question

<!-- One question, answerable yes/no or with a number. Two questions are two spikes:
one that answers whichever question it reaches first answers neither. -->

## Why this is uncertain

<!-- What you already read or tried that failed to settle it. This is what stops the
spike re-deriving something an ADR or the codebase already knows. -->

## Alternatives

<!-- The options under comparison, named. A spike with one option is a build. -->

## Experiment

<!-- What you will build or measure, and the smallest version of it that still
discriminates between the alternatives. -->

## Dataset or examples

<!-- The real inputs used, with their provenance. Synthetic data that avoids the
awkward case is how a spike returns the answer you were hoping for. -->

## Success metrics

<!-- What result picks each alternative, written down before the run. Deciding
afterwards what would have counted as good is not a measurement. -->

## Timebox

<!-- Hours or days, fixed before starting, plus what happens when it expires: which
alternative wins by default, or which ticket carries the question onward. A timebox
with no stated default does not expire — it is a start date with an opinion. -->

## Results

<!-- What actually happened, including the runs that contradicted the hypothesis.
Numbers with the command that produced them. -->

## Decision

<!-- The answer, and where it now lives: an ADR under `docs/adr/`, a term in
`CONTEXT.md`, a constraint on the spec. A conclusion that stays in the spike is a
conclusion nobody applies. -->

## Production code reuse

Forbidden unless explicitly reviewed. Promote conclusions into ADR / domain / spec — do not silently merge spike code.

<!-- Spike code skipped the review, the tests and the seams production code gets.
Merging it moves an experiment's shortcuts into the codebase wearing the authority
of a reviewed change. Rewrite behind the contract instead. -->
