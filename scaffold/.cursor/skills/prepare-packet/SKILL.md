---
name: prepare-packet
description: Assemble and print the context envelope for the current node and stage before a long agent turn. Use before build, review, rework, or any turn that would otherwise read the repository.
disable-model-invocation: true
---

# Prepare packet

Assemble the context envelope for one node at one stage, print it, and begin the
turn from it.

One rule makes this worth running: **you read the packet, not the repository.**
A turn that opens files on demand carries whatever the session happened to
remember plus whatever it stumbles into; a turn that starts from a packet carries
the layers the stage's profile says it needs and nothing else. If you find
yourself opening a file the packet did not include, either the profile is wrong —
fix it in [`../../../docs/method/packet-profiles.md`](../../../docs/method/packet-profiles.md)
— or you have drifted off the stage you claimed to be at.

## Inputs

- **The node address.** `F:007-auth-envelope` for the feature, `T:007/03` when the
  turn is one ticket. Addresses and how they resolve:
  [`../../../docs/method/addressing.md`](../../../docs/method/addressing.md).
- **The stage.** Read it from the `Stage:` line of
  `specs/<NN>-<slug>/spec.md`. Do not choose it, and do not accept one from chat:
  the stage is evidence, and a packet built for the stage someone wishes they were
  at is the wrong six files.

## Procedure

1. **Resolve the address.**

   ```bash
   ./.git-memory-scripts/git-memory-resolve.sh resolve T:007/03
   ```

   Exit 1 means the address names nothing. Stop and report it. A packet assembled
   around a guessed path is worse than no packet: it looks complete.

2. **Read the stage** from the feature's `spec.md`. `request` and `ci` have no
   profile — one is a human writing a sentence, the other is GitHub Actions. Asking
   for either is an error, not an empty packet. Say so and stop.

3. **Print the packet.**

   ```bash
   ./.git-memory-scripts/git-memory-packet.sh F:007-auth-envelope build
   ./.git-memory-scripts/git-memory-packet.sh T:007/03 build --budget 8000
   ./.git-memory-scripts/git-memory-packet.sh F:007-auth-envelope review --format json
   ```

   The script picks the profile from the stage, assembles its layers, and writes to
   stdout. It writes nothing into the repository. Run `--help` for the usage block.

4. **Report inclusion and omission** in the shape below, then hand the packet to
   the turn.

## Report shape

Four lines, then the packet itself:

```
Node:     T:007/03 → .scratch/auth-envelope/issues/03-envelope-schema.md
Stage:    build (M:packet-build)
Included: Route, Contract, Slice
Omitted:  Objective — the outcome is already compiled into the acceptance
          scenarios carried under Contract. Memory — this turn implements a
          fixed contract and defines no terms. Evidence — no check has run yet.
```

Give a reason per omitted layer, in the packet's own terms. An unexplained
omission reads as an oversight, so the next agent re-reads the repository to cover
for it — which is the cost this skill exists to remove.

## When the script is not installed

Assemble by hand. The six layers, the file each is built from, and the profile per
stage are all in
[`../../../docs/method/packet-profiles.md`](../../../docs/method/packet-profiles.md),
with a "most commonly over-read" note per profile telling you what to leave out.
Produce the same report shape; a hand-assembled packet with no omission list is
indistinguishable from a session that read whatever it felt like.

## Under a budget

`--budget N` constrains the total, not the layer list. Shorten quotations, drop ADR
bodies back to titles, list changed paths instead of diff content — summarise
**within** a layer. Never drop a layer the profile marks required. Omission is
decided per stage in the matrix, not per turn under pressure, and a packet missing
a required layer is the failure the agent cannot see: it has no way to know the
layer was ever meant to be there.

## Stop conditions

- **Never edit a file.** This skill reads and prints. That includes the `Stage:`
  line: a packet reports the stage, it does not advance it.
- **Never run the work the packet is for.** Print it and stop. Assembling context
  and then spending it in the same breath removes the moment where a human can see
  the wrong stage was picked.
- **Never substitute a neighbouring stage** because its profile is more convenient.
  If the `Stage:` line and the evidence disagree, that mismatch is the finding —
  route it through [`../orient-in-project/SKILL.md`](../orient-in-project/SKILL.md)
  and do not assemble a packet on top of a contested claim.
- **Do not assemble for `request` or `ci`.**
- **A required layer whose source is missing is reported, not filled.** No
  `acceptance.md` at `build` means the Contract layer has a hole; print the packet
  with the hole named, and let the turn decide whether it can proceed. Inventing
  the missing acceptance criteria is how a feature gets built against a spec that
  never existed.
