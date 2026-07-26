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

## Status and stage

`Status:` lives in exactly one file per feature: `specs/<NN>-<slug>/spec.md`, with values `draft` | `active` | `implemented`. Sibling files and `.scratch/` pointers must not repeat it. Ticket files under `.scratch/<slug>/issues/` carry their own triage `Status:` — that is a different thing (see [`docs/agents/triage-labels.md`](../docs/agents/triage-labels.md)).

`Stage:` sits next to it in the same file and names the delivery step the feature is in, from `request` to `memory`. The vocabulary and the stage/status mapping live in [`docs/agents/delivery-workflow.md`](../docs/agents/delivery-workflow.md); `scripts/check-memory.sh` rejects an unknown stage or a stage that contradicts the status.

The table below is derived from those `spec.md` files. Regenerate with `scripts/check-memory.sh --fix`.

<!-- BEGIN generated:specs-table -->
| Spec | Stage | Status |
|------|-------|--------|
<!-- END generated:specs-table -->

Tickets for implementation live under `.scratch/<slug>/issues/` — see [`docs/agents/issue-tracker.md`](../docs/agents/issue-tracker.md).

Create new ones with [`.cursor/skills/create-feature-spec/`](../.cursor/skills/create-feature-spec/) and [`templates/feature-spec.md`](../templates/feature-spec.md).
