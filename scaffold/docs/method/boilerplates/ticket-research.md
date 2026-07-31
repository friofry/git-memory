# `M:ticket-research`

Reference this from the `Refs:` line of a `Type: research` ticket — one question
answerable from sources that already exist, where building anything to answer it
would be premature.

````md
# Which publishers already stamp an envelope onto outbound events?

ID: T:007/01
Type: research
Status: resolved
Parent: F:007-auth-envelope
Refs: M:ticket-research, TERM:event-envelope

## Question

Which code paths attach an envelope to an outbound event today, and does any of
them already write a signature field?

## Why it blocks

T:007/03 fixes the envelope schema. If two publishers write incompatible shapes
now, the schema has to reconcile them rather than invent a third.

## Sources

- `src/events/` and every caller of `publish()`
- [`../../../CONTEXT.md`](../../../CONTEXT.md), term `Event envelope`
- ADR:0012

## A good answer

Names every publisher, lists the fields each writes, and says which consumer reads
them. A list of file paths with no field inventory is not an answer.

## Answer

`src/events/publisher.ts` and `src/jobs/replay.ts` both write `envelope.meta`;
neither writes a signature. Only `src/events/consumer.ts` reads it, and only
`meta.trace_id`. The T:007/03 schema keeps `meta` and adds `sig` beside it.
````

## Rules

- **The question is answerable from what exists.** If answering it requires
  running new code, it is a `Type: prototype` ticket — see
  [`ticket-prototype.md`](ticket-prototype.md).
- **`## Answer` is reserved from the moment the ticket is written**, empty until
  it is filled. The ticket moves to `Status: resolved` in the same commit as the
  answer, never before.
- **`## A good answer` is written before the work starts.** It is what stops a
  research turn from ending in a reading list.
- **The one thing people get wrong.** Answering in chat, in a PR comment, or in a
  commit message, and leaving the ticket holding only the question. The answer is
  the artifact; everything else is a copy that will be contradicted later and
  believed anyway.
