# Rules

Short, checkable constraints. Each rule cites its home (ADR, domain doc, or architecture note). Prefer adding a file here only when the constraint is enforced often enough that agents miss it in longer docs.

One file per topic, one constraint per heading. A rule is the enforceable
restatement of a decision made elsewhere: it exists so an agent obeys the decision
without first reading the document that made it.

## What makes a good rule

- **One sentence, imperative, no reasoning.** "Every outbound event is signed
  through `EnvelopeSigner`; no file builds `sig` inline."
- **Checkable by someone who has not read the discussion.** Name the observable a
  reviewer can point at: a file, an import direction, a call site. "Keep the events
  layer clean" is not checkable, and it gets waived the first time it is
  inconvenient.
- **Cites its home, on the same line.** `— ADR:0012`, `— TERM:event-envelope`,
  `— docs/architecture/boundaries.md`. Changing the decision then means grepping for
  the citation instead of remembering which copies exist. A rule with no home is a
  preference that acquired a folder.
- **Earns its place by being missed.** The test is not "is this true", it is "has an
  agent broken this while the longer document was open in another tab".

## What does not belong here

| Not a rule | Its home |
|------------|----------|
| The reasoning behind the constraint | [`../docs/adr/`](../docs/adr/) — a rule that argues is a rule nobody finishes |
| What a domain term means | [`../CONTEXT.md`](../CONTEXT.md) |
| How work is typed, gated, reviewed or handed over | [`../docs/method/`](../docs/method/) |
| A constraint that binds one feature only | That feature's `spec.md`, under Constraints |
| Something a test or a linter already fails on | The test — prose repeating a machine check drifts from it silently |

## Citing a rule

A rule has no address. Six address families exist and a seventh is an ADR-shaped
decision, not a convenience — [`../docs/method/addressing.md`](../docs/method/addressing.md).
Cite a rule by path and heading: `rules/events.md`, heading `## Signing goes through
the seam`. A review finding that says only "violates `rules/`" cannot be answered,
because nobody can tell which line it means.

## Stop conditions

- **Do not restate an ADR in full here.** Restate the constraint, cite the number,
  leave the argument where it was made.
- **Do not write a rule for a decision nobody has made.** The rule is downstream of
  the decision; writing it first buries the choice where no reader looks for it.
- **Do not leave a rule whose home was retired.** When an ADR is superseded, the
  rules citing it are part of that change. A rule outliving its reason is the worst
  artifact in this directory, because it still reads as authority.
