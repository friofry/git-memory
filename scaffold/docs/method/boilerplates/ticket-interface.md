# `M:ticket-interface`

Reference this from the `Refs:` line of a `Type: interface` ticket — the ticket
that fixes the contract between two modules before either one is built against it.

````md
# Fix the auth envelope schema and the signer contract

ID: T:007/03
Type: interface
Status: ready-for-agent
Parent: F:007-auth-envelope
Blocked by: T:007/01
Refs: M:ticket-interface, TERM:event-envelope

## Contract

Both sides code against this and nothing else:

```ts
type AuthEnvelope = {
  meta: EventMeta;              // unchanged, see T:007/01
  sig: { keyId: string; value: string };
};

interface EnvelopeSigner {
  sign(event: Event, keyId: string): AuthEnvelope;   // throws on unknown keyId
  verify(envelope: AuthEnvelope): boolean;           // false, never throws
}
```

`keyId` is resolved per call, not held — S:007/proto-a.

## Callers

| Caller | Uses | Ticket |
|--------|------|--------|
| `src/events/publisher.ts` | `sign` | T:007/04 |
| `src/jobs/replay.ts` | `sign` | T:007/06 |
| `src/events/consumer.ts` | `verify` | T:007/07 |

## Not decided here

Key storage, rotation schedule, and what a consumer does with a rejected event.
Those are ADR-shaped and belong in `decisions.md`, not in this signature.
````

## Rules

- **Every caller is listed with the ticket that will write it.** A contract with
  one named caller is a design guess; a contract with none is speculation.
- **The contract is quoted as code, in the project's own language**, including
  error behaviour. "Throws on unknown keyId" is part of the interface.
- **This ticket blocks its callers.** Each caller ticket carries
  `Blocked by: T:007/03` and does not start until it is `resolved`.
- **The one thing people get wrong.** Deciding more than the seam. A ticket that
  also settles storage or rotation cannot be resolved until those arguments end,
  and the callers wait on an argument that never needed to block them. Name what
  is out of scope in the ticket itself, as `## Not decided here` does above.
