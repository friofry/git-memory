# Specs

Active and historical feature contracts. Each substantial change gets a folder:

```
specs/<NN>-<slug>/
  spec.md          # outcome, scope, known/assumed/unknown — owns Status and Stage
  design.md        # how it fits architecture
  acceptance.md    # Given/When/Then
  decisions.md     # local decisions (promote globals to docs/adr/)
  research.md      # optional long inventory
```

`design.md` / `acceptance.md` / `decisions.md` are required while a spec is `draft` or `active`. A spec migrated in as `implemented` may carry `spec.md` alone.

## Address and node header

A feature directory is addressed `F:<NN>-<slug>`: `specs/007-auth-envelope/` is
`F:007-auth-envelope`, its tickets are `T:007/01` onward and its spikes `S:007/…`.
Ticket and spike addresses carry the number rather than the slug, so renaming a
feature does not invalidate every reference to its work — see
[`docs/method/addressing.md`](../docs/method/addressing.md).

`spec.md` opens with a node header: plain `Key: value` lines, no YAML front matter,
starting with `ID:` and `Type:`. Three rules are specific to a spec; the rest of the
field rules live in [`docs/memory.md`](../docs/memory.md).

- `ID:` must equal the address the directory's own path implies. A mismatch means
  the file was copied from another feature rather than created, and its `Parent:`
  and `Refs:` lines still point at that feature's work.
- `Type:` is `feature`, `bug` or `architecture`. The other eight values are ticket
  types — [`docs/method/work-types.md`](../docs/method/work-types.md).
- `Stage:` appears here and on no other file in the repository.

A spec written before the header existed carries `Status:` and `Stage:` alone. That
is a warning under `scripts/check-memory.sh --strict` and passes a default run, so
an installed v1 repository stays green.

## Status and stage

`Status:` lives in exactly one file per feature: `specs/<NN>-<slug>/spec.md`, with values `draft` | `active` | `implemented`. Sibling files and `.scratch/` pointers must not repeat it. Ticket files under `.scratch/<slug>/issues/` carry their own triage `Status:` — that is a different thing (see [`docs/agents/triage-labels.md`](../docs/agents/triage-labels.md)).

`Stage:` sits next to it in the same file and names the delivery step the feature is in, from `request` to `memory`. The vocabulary and the stage/status mapping live in [`docs/agents/delivery-workflow.md`](../docs/agents/delivery-workflow.md); `scripts/check-memory.sh` rejects an unknown stage or a stage that contradicts the status.

The table below is derived from those `spec.md` files. Regenerate with `scripts/check-memory.sh --fix`.

<!-- BEGIN generated:specs-table -->
| Spec | Stage | Status |
|------|-------|--------|
<!-- END generated:specs-table -->

Tickets for implementation live under `.scratch/<slug>/issues/`, from [`templates/ticket.md`](../templates/ticket.md) — see [`docs/agents/issue-tracker.md`](../docs/agents/issue-tracker.md).

Create new ones with [`.cursor/skills/create-feature-spec/`](../.cursor/skills/create-feature-spec/) and [`templates/feature-spec.md`](../templates/feature-spec.md).
