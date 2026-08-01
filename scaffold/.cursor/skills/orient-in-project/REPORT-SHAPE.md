# Orientation report shape

The eleven sections an orientation report produces, in this order. This file is the
home for the shape; [`SKILL.md`](SKILL.md) is the home for the procedure that fills
it. Every conclusion carries an evidence label — `Observed`, `Inferred`, `Unknown` —
as defined there.

Write every heading. A section with nothing in it gets the heading plus one line
saying why, because a silently dropped section reads as "nothing to report" when it
usually means "nobody looked".

## 1. Project

One or two sentences: what this project is and its main user outcome.

## 2. Current objective

The concrete outcome currently being pursued, in the user's language. Not the
implementation: "a consumer can tell whether an event came from who it claims" is an
objective; "add a signer to the publisher" is a task list.

## 3. Current delivery stage

The active feature by address, then its position, stated as
`N/12 <stage> — waiting on <owner>`, then the one line of evidence for it.

```
F:007-auth-envelope (specs/007-auth-envelope/) — Type: feature, Status: active
6/12 build — waiting on Builder
Observed: three commits on claude/auth-envelope touching src/events/, and
T:007/04 carries Status: claimed.
```

The stages, their owners and the evidence each demands are defined in
[`../../../docs/agents/delivery-workflow.md`](../../../docs/agents/delivery-workflow.md).
Do not restate the table here — cite the row. What blocks the next transition is a
gate, addressed as `M:gate-*` in
[`../../../docs/method/gates.md`](../../../docs/method/gates.md).

If the `Stage:` line and the evidence disagree, report both and mark the conflict.
The line is not corrected here; section 9 carries the mismatch.

If several features are active, repeat this section per feature and say which one
the session is about.

## 4. Architecture location

The relevant path through the system, and the module boundaries the work crosses.

```
MCP client
→ MCP adapter
→ replay application service
→ parser core
```

Name the seams in the deep-module vocabulary — module, interface, seam, adapter,
depth — so this section, a design document and a review describe the same thing the
same way. If `docs/architecture/` holds no boundary document yet, say so: an
undocumented boundary is a finding for section 9, not a blank line here.

## 5. Active artifacts

Only the artifacts this session will touch, each with its role and its address where
it has one: feature spec, acceptance criteria, design, ADRs, domain docs, skills,
tests, spikes.

```
F:007-auth-envelope  specs/007-auth-envelope/acceptance.md — the scenarios the diff
                     must satisfy
T:007/03             .scratch/auth-envelope/issues/03-envelope-schema.md — resolved;
                     fixes the seam T:007/04 implements
ADR:0012             docs/adr/0012-signed-auth-envelope.md — rotation policy
S:007/proto-a        spikes/auth-envelope/proto-a/ — per-call key resolution, answered
```

## 6. Observed state

Three groups: completed, in progress, not started. Base each entry on repository
evidence. A ticket queue makes this cheap — read `Status:` and `Blocked by:` across
`.scratch/<slug>/issues/` and report the frontier: which tickets are unblocked and
unclaimed right now.

## 7. Local changes

Modified files, untracked files, recent commits, failing checks. Do not expose
secrets or irrelevant generated files. A `build/` directory holding a redirected
packet or graph is generated output and is not a local change worth reporting.

## 8. Known, assumed, unknown

Three separate subsections. The split is the point: collapsing them is how an
assumption gets acted on as a fact.

### Known

Directly supported by code, tests, specifications, or repository state.

### Assumed

Likely true but not directly confirmed. Each entry names what breaks if it is false.

### Unknown

Missing information that affects the next decision. Each entry names the ticket or
spike that would answer it, or says that nothing is assigned to it yet.

## 9. Risks and inconsistencies

Look for, and report by name:

- spec and code disagreement;
- a `Stage:` line the evidence does not support;
- a node whose `ID:` does not match the address its path implies — that means the
  file was copied, and its `Parent:` and `Refs:` still point at another feature;
- a ticket or spike carrying a `Stage:` line, which is the one-home rule breaking;
- an unresolvable `Parent:`, `Blocked by:`, `Refs:` or `M:` address;
- architecture-boundary violations;
- undocumented public contract changes;
- an unclear source of truth, or the same fact stated in two files;
- unbounded scope;
- a stale `active-context.md`, or a root `context.md` predating the rename;
- failing or absent verification;
- unrelated work mixed into the branch.

## 10. Recommended next action

Exactly one. Small, concrete, and either finishing the current delivery stage or
opening the next one. Name the stage it belongs to and its owner. When the owner is
a human — `request`, `approval`, `acceptance` — the recommendation is what to put in
front of them, not work to start.

If the action is a long agent turn, name
[`../prepare-packet/SKILL.md`](../prepare-packet/SKILL.md) as its first step and the
stage whose profile it should assemble.

Examples: clarify one acceptance condition; create a timeboxed spike; review an
architecture design; implement one vertical slice; run verification; perform an
independent review.

## 11. Human decisions required

Only decisions that must not be made autonomously:

- public contract changes;
- schema migrations;
- security policy;
- module-boundary changes;
- significant new dependencies;
- destructive operations.

If none are required, write exactly:

`No human decision is currently required.`
