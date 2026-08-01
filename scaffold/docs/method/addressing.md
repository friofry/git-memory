# Addressing

The home for the address wire format: six families, how each resolves to a path,
and what happens when one does not. An address is what you write in a `Refs:` line,
a prompt, a PR body or a handoff when a full path would be noise.

**The path is the truth; the address is a projection of it.** Nothing is stored
under an address that is not already stored at a path. Resolution is therefore
always a directory scan, never a lookup in a table someone has to maintain.

## The six families

Six, and no more. Adding a seventh is an ADR-shaped decision — write it up under
[`../adr/`](../adr/) before the first reference exists.

| Family | Form | Resolves to |
|--------|------|-------------|
| Feature | `F:007-auth-envelope` | `specs/007-auth-envelope/` |
| Ticket | `T:007/03` | `.scratch/auth-envelope/issues/03-*.md` |
| Spike | `S:007/proto-a` | `spikes/auth-envelope/proto-a/` |
| ADR | `ADR:0012` | `docs/adr/0012-*.md` |
| Term | `TERM:event-envelope` | `CONTEXT.md`, heading `## Event envelope` |
| Method | `M:gate-approval` | a `docs/method/**` heading whose text is `` `M:gate-approval` `` |

## Resolution rules

**`F:<NN>-<slug>`** — match `specs/<NN>-*/` on the number. Exactly one directory
must match. The slug in the address must equal the matched directory's slug; a
disagreement means the feature was renamed and this reference was not updated, and
the resolver reports both strings rather than guessing.

**`T:<NN>/<MM>`** — resolve `<NN>` to the feature directory, read its slug from the
directory name, then match `.scratch/<slug>/issues/<MM>-*.md`. Exactly one file must
match. The `.scratch/` folder must be named exactly the feature slug with no number
prefix; a folder named `007-auth-envelope` under `.scratch/` resolves nothing.

**`S:<NN>/<name>`** — same slug lookup, then `spikes/<slug>/<name>/`. The address
names the directory; the node file inside it is always `README.md`.

**`ADR:<NNNN>`** — match `docs/adr/<NNNN>-*.md`. Four digits, zero-padded, always.
An ADR number is never reused, so exactly one file matches or none does.

**`TERM:<anchor>`** — the address is the GitHub heading anchor, not the prose of the
heading: `## Event envelope` is addressed as `TERM:event-envelope`. Resolves to
`CONTEXT.md#<anchor>`.

**`M:<family>-<name>`** — scan headings under `docs/method/**/*.md` for one whose
text is exactly the address in backticks. Exactly one declaration must exist; two is
a failure, not a tie to break. Resolves to `<path>#<anchor>`, where the anchor drops
the backticks and the colon: `M:gate-approval` becomes `#mgate-approval`.

## Worked examples — `007-auth-envelope`

The feature is `specs/007-auth-envelope/`, its tickets are under
`.scratch/auth-envelope/`, and it ran one throwaway spike.

| Address | `./.git-memory-scripts/git-memory-resolve.sh resolve …` prints | Node file, if any |
|---------|--------------------------------------------------|-------------------|
| `F:007-auth-envelope` | `specs/007-auth-envelope/` | `specs/007-auth-envelope/spec.md` |
| `T:007/03` | `.scratch/auth-envelope/issues/03-envelope-schema.md` | the same file |
| `S:007/proto-a` | `spikes/auth-envelope/proto-a/` | `spikes/auth-envelope/proto-a/README.md` |
| `ADR:0012` | `docs/adr/0012-signed-auth-envelope.md` | — |
| `TERM:event-envelope` | `CONTEXT.md#event-envelope` | — |
| `M:gate-approval` | `docs/method/gates.md#mgate-approval` | — |

In use, the header of ticket `03` reads:

```
ID: T:007/03
Parent: F:007-auth-envelope
Blocked by: T:007/01
Refs: M:ticket-interface, TERM:event-envelope
```

Five addresses, no paths, and every one of them resolves without the reader knowing
that the feature's scratch folder is called `auth-envelope` and not `007-auth-envelope`.

## Globs and failure modes

Each family fails in exactly one interesting way. Know the failure, and an
unresolvable address takes seconds instead of an afternoon.

| Family | Exact glob or scan | The failure mode it produces |
|--------|-------------------|------------------------------|
| `F:` | `specs/<NN>-*/` | Two features numbered `007` — `specs/007-auth-envelope/` and `specs/007-auth-tokens/` both match, so every `T:007/*` and `S:007/*` in the repository becomes ambiguous at once. The resolver exits 1 and names both directories rather than picking the first. |
| `T:` | `.scratch/<slug>/issues/<MM>-*.md` | Two tickets numbered `03` in one feature, usually from two agents adding a ticket on separate branches. `./.git-memory-scripts/check-memory.sh` reports duplicate numbering; renumber the later one and fix its `ID:`. |
| `S:` | `spikes/<slug>/<name>/` | The spike directory exists but holds no `README.md`, so there is no node header, no `ID:` to compare against the path, and no record of the question the spike answered. |
| `ADR:` | `docs/adr/<NNNN>-*.md` | `ADR:12` written unpadded matches nothing. Padding is not cosmetic — it is what makes the glob a single unambiguous pattern. |
| `TERM:` | heading anchor in `CONTEXT.md` | A term renamed in the glossary leaves every `Refs:` entry dangling, and the glossary holds no back-references to tell you who cited it. Rename by grepping the old address first. |
| `M:` | heading text `` `M:…` `` under `docs/method/**` | The same address declared in two files, typically when a boilerplate is split. The resolver cannot choose and fails; delete one declaration, do not "keep both in sync". |

## Why addresses are path-derived

**Rename safety.** A path can move for reasons that have nothing to do with the
work — a slug typo, a renumbered feature, a spike promoted out of `spikes/`. If an
address were stored on the node, the move would leave the stored value right and the
path wrong, or the reverse, with no way to tell which. Derived from the path, an
address cannot disagree with where the file actually is.

**No second source of truth.** A stored address is a fact that has to be assigned,
kept unique and garbage-collected — an ID allocator, in a system whose whole premise
is that Git is the only store. Derivation makes uniqueness a property of the
filesystem instead of a property of someone's discipline.

**The `ID:` line is a checksum, not a store.** Every node file still carries
`ID: T:007/03`, and it must equal the address its own path implies. That line exists
to catch one specific accident: a file copied from another feature, header and all.
A mismatch is a hard failure precisely because it means the file was copied rather
than created.

## Why a ticket address carries the number, not the slug

`T:007/03`, not `T:auth-envelope/03`. A feature slug is prose and prose gets
rewritten; a feature number is assigned once and never reused. If a ticket address
carried the slug, renaming `007-auth-envelope` to `007-auth-envelopes` would
invalidate every ticket reference, every `Blocked by:` line and every PR body that
mentioned one — a repository-wide sweep as the price of a typo fix.

The trade is deliberate and asymmetric:

- `T:` and `S:` carry only the number, so they survive a rename untouched. The
  resolver pays one extra lookup — number to directory to slug — on every
  resolution.
- `F:` carries the full `NN-slug`, because a feature address is the one an operator
  types and reads most, and `F:007-auth-envelope` says what it is where `F:007` does
  not. The cost is that renaming a feature slug means updating `F:` references. That
  is a handful of lines, and `./.git-memory-scripts/check-memory.sh` finds every one of them.

## One resolver

`.git-memory-scripts/git-memory-resolve.sh` is the only implementation of address to path in
this system. `git-memory-graph.sh`, `git-memory-packet.sh` and `check-memory.sh` all
call it; none re-implements the parse. If you need resolution in a new script, call
the resolver — a second parser is a second definition of what an address means, and
the two will disagree first on the case nobody tested.

## Where addresses appear

In `ID:`, `Parent:`, `Children:`, `Blocked by:` and `Refs:` lines on node files, and
in prompts, packets, PR bodies and handoffs.

They do not replace markdown links in prose. A reader who clicks a link must land on
the file; a reader who reads `T:007/03` in a `Blocked by:` line is running a
resolver, not a browser. Both forms coexist in the same document —
[`gates.md`](gates.md) is a link, `M:gate-approval` is an address, and they point at
the same prose.

Field rules for those lines — which are required, which are optional, which node
kinds may carry them — are node-header rules, not addressing rules; the one-home map
in [`../memory.md`](../memory.md) points at the file that owns them. This file owns
only what an address is and how it resolves.
