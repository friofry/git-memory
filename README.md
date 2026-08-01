# git-memory

Drop this into a repository and an agent recovers project state from Git
artifacts instead of from chat memory.

Works in **Claude Code**, **Cursor**, and any harness that reads `AGENTS.md`.
Born in [`friofry/starcraft-benchmark`](https://github.com/friofry/starcraft-benchmark);
this is the domain-free extract.

## Why

An agent forgets between sessions. That is fixable with context.

You forget *why*, and that is only fixable by writing it down.

Six weeks after a decision, the argument that produced it is gone, and the
version of you that shows up is tired and wants the elegant solution. Without a
record, the tired one wins — not because the argument is better, but because it
is the one in the room. A repository that keeps its reasoning does not have that
fight twice.

So: a feature travels through twelve named stages. Its evidence — spec, tickets,
review, CI, the write-back to memory — sits in files a `grep` can find, and seven
gates decide when it is allowed to move. Nothing lives in a chat log, and nothing
lives in your head.

The cost is real: roughly 15–20% more time, and on a one-day script it is pure
loss. The signal for whether it pays is not team size but **number of returns**.
Come back to the code once and the memory is still in your head. Come back five
times over six months and each return without a record costs an evening of
reconstruction.

## Difference from Matt Pocock's skills

[Matt's skills](https://github.com/mattpocock/skills) are the **craft**: how to
interview a plan, design a deep module, drive TDD, review a diff, debug something
hard. They are excellent and this repository does not try to replace them.

This repository is the **process**: where a fact lives, what a thing is called,
which stage it is in, what evidence lets it move, and what the agent is told for
one turn.

The rule for what gets vendored follows from that. If an upstream skill was the
entry point for a stage this repository now drives itself, it goes — two entry
points for one stage is how an agent picks the wrong one. If it is craft, it
stays, because nothing here replaces it and nothing is planned to.

| | Vanilla upstream | With git-memory |
|--|--|--|
| Spec | one `/to-spec` document | four files, plus `Status:` and `Stage:` |
| "Where is this feature?" | chat, tracker, memory | a `Stage:` line, checked against evidence |
| Planning | `/to-tickets` | `/plan-feature` — typed tickets, `Blocked by:` edges, cycle detection, scenario coverage |
| Context per turn | decided again every session | the stage's packet, assembled by a script |
| What blocks a merge | nothing in particular | seven gates and a required check that always runs |
| Acceptance | tests are green | six scenarios verified against a demonstration |

After v2 the dependency is optional in kind: a repository with this seed and no
vendored skills still has its stages, gates, packets, addresses and checks. It
just has a less skilled agent working inside them.

## The twelve stages

| Stage | Owner | Done when |
|-------|-------|-----------|
| `request` | Human | The wanted outcome is written down, not just said |
| `research` | Agent | Unknowns are named; the ones needing data get a spike |
| `spec` | Agent | Outcome, design and Given/When/Then exist and agree |
| `approval` | **Human** | Meaning and architecture are approved |
| `plan` | Agent | Work is sliced into tickets against the acceptance scenarios |
| `build` | Agent | The smallest slices are implemented |
| `checks` | Agent | The commands in `AGENTS.md` pass locally |
| `review` | Agent | An independent pass tried to find defects |
| `rework` | Agent | Every blocking finding is fixed or explicitly deferred |
| `ci` | CI | The checks are repeated independently of the builder |
| `acceptance` | **Human** | A demonstration satisfies `acceptance.md` |
| `memory` | Agent | Facts and decisions that changed are written back |

Three stages need a human. Everything between them is agent-driven.

Six axes stay orthogonal, and confusing any two is the failure the model exists
to prevent. **Address** is which node — derived from the path, never stored.
**Type** is what kind of work, on the node file. **Stage** is where the feature
is, in `spec.md` and nowhere else. **Status** is how far along. **Owner** is
derived from the stage, so no file carries an `Owner:` line and no two files can
disagree about it. **Evidence** is what proves the claim.

A `Type: research` ticket inside a `Stage: build` feature is not a contradiction.
It is a Tuesday: you were building and found something you had to go look up.

## Packets

Every session, someone decides what the agent is told. By hand you either paste
the whole feature and bury the one thing that matters, or paste too little and
get code written against a contract the agent never saw.

A **packet** is that decision, generated — the context envelope for one turn at
one stage.

```bash
./scripts/git-memory-packet.sh T:012/03 build
```

Six layers exist; a **profile** is which of them a stage carries.

| Layer | Carries |
|-------|---------|
| Route | which node, which stage, what you are asked to do |
| Objective | the outcome in one sentence |
| Contract | acceptance scenarios, scope, rules the change must obey |
| Memory | glossary terms and ADRs the feature touches |
| Slice | the ticket under work, the queue, the commands, what changed |
| Evidence | command output, review artifacts, CI |

`build` carries Route, Contract and Slice, and **deliberately drops the
glossary** — a builder implementing one ticket does not need the domain
vocabulary competing for attention. `review` puts Memory and Evidence back,
because a reviewer without architecture context reviews syntax.

An omitted layer is still named, with its reason, so a reader can tell *empty*
from *never asked for* — `Memory: omitted (build profile)`, not silence.

A `build` packet is about **1.3k tokens**; the same feature's four files plus
tickets and the workflow is **8.2k**, most of it about stages you are not on. One
profile is expensive on purpose — `approval`, at 2.5k, quotes all four spec files
in full, because a human who approves a summary approved the summary.

`--budget N` truncates the lowest-priority layer within itself and says by how
much; a required layer is never dropped. Use it for a long turn, not as a
default: a truncated packet looks like a complete one.

Packets print to stdout and are never committed. Full table:
[`packet-profiles.md`](scaffold/docs/method/packet-profiles.md).

## Scripts

Plain bash, portable to macOS 3.2 and BSD userland, no dependencies. Each runs
from anywhere and exits 2 on a usage error, so a typo never reads as a clean
repository.

| Script | What it does |
|--------|--------------|
| `check-memory.sh` | The consistency checks no single file can perform. `--fix` regenerates derived blocks; `--strict` adds what v2's node header demands |
| `git-memory-resolve.sh` | Address to path — **the only address parser in the system**. `--print` gives the section an address names rather than the file holding it |
| `git-memory-packet.sh` | The context envelope, per stage |
| `git-memory-graph.sh` | The work graph: `ndjson`, `md` or `dot` |
| `git-memory-progress.sh` | The twelve stages as a checklist, filled from evidence. `--cheatsheet` prints one line per stage |
| `test/run-tests.sh` | 232 assertions on throwaway fixtures, under 30 seconds |

Addresses are six families, each a projection of a path: `F:012-transfers`,
`T:012/03`, `S:012/proto-a`, `ADR:0011`, `TERM:envelope`, `M:gate-approval`. A
ticket address carries the feature's **number**, not its slug, so renaming a
feature invalidates nothing. Details:
[`addressing.md`](scaffold/docs/method/addressing.md).

`git-memory-progress.sh` has one box most tools do not. `[!]` means the feature
walked past that stage with nothing to show for it — not *wrong*, but
**unproven**, which is a different and more useful claim.

## Skills

Nine are authored here and drive a stage:

`ask-git-memory` · `orient-in-project` · `prepare-packet` ·
`create-feature-spec` · `plan-feature` · `implement-feature` · `review-change` ·
`review-architecture` · `update-git-memory`

Thirteen are vendored from upstream and supply craft, never placement:

`research` · `grilling` · `grill-with-docs` · `domain-modeling` · `tdd` ·
`codebase-design` · `code-review` · `diagnosing-bugs` · `prototype` ·
`resolving-merge-conflicts` · `improve-codebase-architecture` · `wayfinder` ·
`writing-great-skills`

The `minimal` set keeps seven of those. Which, and why each of the six dropped
ones was dropped: [`matt-skill-sets.txt`](matt-skill-sets.txt).

## Install, update, remove

**Install.** Add the installer, then run it in the target project:

```bash
npx skills@latest add friofry/git-memory -s setup-git-memory -a universal -y
```

It asks for scope, the method and GitHub layers as separate opt-ins, and the
merge policy; confirms the plan before writing; and runs the test suite once in
your environment before reporting success.

Manually, if you would rather see every step:

```bash
git clone https://github.com/friofry/git-memory.git /tmp/git-memory
cd <your-project>
rsync -a --ignore-existing /tmp/git-memory/scaffold/ ./
ls -l .claude/skills || ln -sfn ../.cursor/skills .claude/skills
chmod +x scripts/*.sh scripts/test/*.sh
./scripts/test/run-tests.sh && ./scripts/check-memory.sh --fix
```

Then fill `docs/product/charter.md`, put the real commands into `AGENTS.md`
**and** into `.github/workflows/delivery.yml`, and replace
`@your-org/memory-owners` in `.github/CODEOWNERS`. Nothing under `.github/`
blocks a merge until branch protection is switched on.

**Update.** `/update-git-memory` adds what is missing and asks before merging any
file that differs. It handles v1 → v2, which is additive with exactly one rename
(`context.md` → `active-context.md`); every v2 requirement lives behind
`--strict`, so you migrate when ready rather than when the update lands.

```bash
npx skills@latest add friofry/git-memory -s update-git-memory -a universal -y
npx skills@latest update && ./scripts/check-memory.sh --fix   # craft skills only
```

**Remove.** Nothing here is load-bearing for your code, so removal is deletion.
The tool layer and the method layer go first:

```bash
git rm -r scripts/check-memory.sh scripts/git-memory-*.sh scripts/lib scripts/test
git rm -r docs/method .cursor/skills .claude .agents skills-lock.json CLAUDE.md
git rm .github/workflows/memory.yml .github/workflows/delivery.yml
```

Keep `specs/`, `.scratch/`, `docs/adr/`, `CONTEXT.md` and `AGENTS.md` — that is
**your** memory, ordinary markdown, still readable with nothing installed. Node
headers become inert lines. Drop `delivery.yml` from branch protection too, or
the required check blocks every pull request forever.

## A feature, end to end

The request is a bug: a user's expense report double-counts money moved between
their own accounts.

`research` finds an unknown that needs data rather than thought: what date window
catches a transfer. A spike answers it and leaves a number — ±3 days, 99.9%
coverage, 0.65% false pairs. Guessing ±7 would have tripled the false pairs and
nobody would have known.

`spec` writes four files, and the interview asks what nobody said out loud: what
happens when the same statement is imported twice? That becomes a scenario.

`approval` is a human reading all four in full. Reading them surfaces that
currency transfers need four bank-specific parsers for 0.3% of rows — so they are
cut, in writing, with the reason. Without the gate that decision is never made;
the work just starts and stops halfway.

`plan` cuts six tickets against the scenarios with real dependency edges. `build`
and `checks` are ordinary work with `/tdd`.

`review` finds a missing test case, and one thing only `/review-architecture`
could see: the matcher imports the report aggregator, an edge pointing the wrong
way against an ADR. The code worked. The arrow was backwards. `rework` answers
the blocking findings and nothing else; the rest becomes a ticket at
`needs-triage` rather than a good intention.

`acceptance` runs the scenarios against a real statement and one fails — two
identical subscriptions charged the same day on different cards, matched as a
transfer. Every test was green. The rule gains a line: a pair needs opposite
signs.

`memory` writes the term into `CONTEXT.md`, the decision into an ADR with its own
review condition, and `Implemented in: #47` onto the spec.

Four evenings, one of them not writing code. That evening bought a number instead
of a guess, a decision that stayed decided, an arrow turned around, and a bug
that all the tests had missed.

## Layout

```
git-memory/
├── matt-skill-sets.txt              # the two sets, and why each skill is in or out
├── scripts/package-claude-web-skills.sh
├── skills/                          # setup-git-memory, update-git-memory
└── scaffold/                        # what gets copied into your project
    ├── AGENTS.md                    # the contract
    ├── CLAUDE.md                    # a pointer to AGENTS.md, nothing more
    ├── CONTEXT.md                   # the domain glossary
    ├── docs/
    │   ├── memory.md                # the layer map and the one-home rule
    │   ├── agents/                  # delivery workflow, vendored skills, github gates
    │   └── method/                  # types, addressing, gates, packet profiles
    ├── specs/ · .scratch/ · spikes/ · rules/ · templates/
    ├── scripts/                     # the six above, plus lib/ and test/
    ├── .cursor/skills/              # nine repo-authored skills
    ├── .claude/skills -> ../.cursor/skills
    └── .github/                     # memory.yml (advisory) · delivery.yml (requirable)
```

For Claude.ai, which cannot install from a CLI,
`scripts/package-claude-web-skills.sh` builds one ZIP per skill.

## Design notes

**One home per fact.** Everything else follows from this. The graph and packets
print to stdout and are never committed, because a committed projection is a
second copy that goes stale the first time someone edits a `Refs:` line. Removing
the failure mode beats adding a check for it.

**One parser per fact.** One resolver for addresses, one reader for node headers.
Four header readers existed once and only one skipped fenced code blocks, so a
spec quoting an *example* header made three scripts read the example.

**Addresses are derived, never stored.** A stored address can disagree with the
file it names. A derived one cannot.

**Owner is derived from stage.** Write `Owner:` into a file and you have given a
fact a second home; move the stage and the two disagree with nothing to break the
tie.

**Local markdown is writable truth; GitHub Issues are intake.** Two writable
stores is an unbounded reconciliation problem with no correct answer. The layers
meet once, at the pull request.

**A skipped job reports success.** `delivery.yml` has no path filter for exactly
this reason — a path-filtered required check passes on the changes it was never
allowed to inspect.

**v1 installs stay green.** Every v2 requirement is behind `--strict`.

**What this does not protect against.** Writing a spec to have written a spec.
Four files, empty of substance, an `acceptance.md` reading "works correctly" —
that passes every check and buys nothing. The method gives thinking a shape to
land in. It cannot make anyone think.
