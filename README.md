# git-memory

Drop this into a repository and an agent recovers project state from Git artifacts
instead of from chat memory. A feature then travels through twelve named stages
whose evidence — spec, tickets, review, CI, memory write-back — sits in files a
`grep` can find, and seven gates decide when it is allowed to move. [Matt Pocock's
agent skills](https://github.com/mattpocock/skills) supply the craft; this repo owns
where their output lands, what it is called, and which command proves it.

Born in [`friofry/starcraft-benchmark`](https://github.com/friofry/starcraft-benchmark);
this repo is the domain-free extract.

## What you get

| Piece | Role |
|-------|------|
| `scaffold/` | The files copied into a target project |
| `skills/setup-git-memory/` | One-shot installer (`/setup-git-memory`) |
| `skills/update-git-memory/` | Confirmation-driven updater, including v1 → v2 (`/update-git-memory`) |
| `matt-skill-sets.txt` | The `minimal` and `full` lists for `npx skills add` and for packaging |
| `scripts/package-claude-web-skills.sh` | Per-skill ZIPs for Claude.ai upload |

Inside [`scaffold/`](scaffold/):

- [`docs/memory.md`](scaffold/docs/memory.md) — the layer map, node headers, and the one-home rule
- [`docs/agents/delivery-workflow.md`](scaffold/docs/agents/delivery-workflow.md) — the stages `request` … `memory`, and which skill performs each
- [`docs/method/`](scaffold/docs/method/) — work types, addressing, gates, packet profiles, and the referenced boilerplates
- [`docs/agents/vendored-skills.md`](scaffold/docs/agents/vendored-skills.md) — what upstream skills assume and what this repo answers
- [`docs/agents/github-gates.md`](scaffold/docs/agents/github-gates.md) — which GitHub mechanism enforces which gate, and the two that pass themselves
- [`.cursor/skills/`](scaffold/.cursor/skills/) — `ask-git-memory`, `orient-in-project`, `prepare-packet`, `create-feature-spec`, `implement-feature`, `review-change`, `review-architecture`, `update-git-memory`
- [`scripts/`](scaffold/scripts/) — `check-memory.sh`, `git-memory-resolve.sh`, `git-memory-graph.sh`, `git-memory-packet.sh`, and a fixture-based `test/run-tests.sh`
- [`.github/`](scaffold/.github/) — two workflows, four issue forms, a PR template, `CODEOWNERS`
- [`templates/`](scaffold/templates/) — empty forms for specs, tickets, ADRs, reviews, spikes

## Install into another project

### A. Agent skill (recommended)

1. Add the installer to the target project or to your user skills:

```bash
npx skills@latest add friofry/git-memory -s setup-git-memory -a universal -y

# or copy from a clone:
# cp -R skills/setup-git-memory <target>/.cursor/skills/
```

2. In the target project, run **`/setup-git-memory`** (or attach the skill and ask
   it to run).
3. Answer scope (`full` / `minimal`), then the method layer and the GitHub intake
   layer as separate opt-ins, then the merge policy. Confirm the plan. It vendors
   Matt's skills, runs `./scripts/check-memory.sh --fix`, and runs
   `./scripts/test/run-tests.sh` once to prove the tooling works in your environment
   before it reports success.

### B. Manual

```bash
git clone https://github.com/friofry/git-memory.git /tmp/git-memory
cd <your-project>

# copy the seed (never overwrite an existing AGENTS.md / CONTEXT.md blindly)
rsync -a --ignore-existing /tmp/git-memory/scaffold/ ./

# vendor Matt skills (full set)
npx skills@latest add mattpocock/skills \
  -s research -s grilling -s domain-modeling -s grill-with-docs \
  -s to-spec -s to-tickets -s wayfinder -s triage -s implement -s tdd \
  -s codebase-design -s prototype -s diagnosing-bugs -s code-review \
  -s resolving-merge-conflicts -s handoff \
  -s improve-codebase-architecture -s writing-great-skills \
  -a universal -y

chmod +x scripts/*.sh scripts/test/*.sh
./scripts/test/run-tests.sh      # proves the tool layer runs here
./scripts/check-memory.sh --fix
```

Then fill [`docs/product/charter.md`](scaffold/docs/product/charter.md), grow
`CONTEXT.md`, put the real commands into `AGENTS.md` **and** into
[`.github/workflows/delivery.yml`](scaffold/.github/workflows/delivery.yml), and
replace `@your-org/memory-owners` in
[`.github/CODEOWNERS`](scaffold/.github/CODEOWNERS). Nothing under `.github/` blocks
a merge until branch protection is switched on.

## After setup

| Intent | Skill |
|--------|-------|
| What should happen next? | `/ask-git-memory` |
| Where are we? | `/orient-in-project` |
| Starting a long turn | `/prepare-packet` — prints the context envelope this stage calls for |
| New feature | `/create-feature-spec` → human approval → `/to-tickets` → `/implement-feature` |
| Review | `/review-change` (drives vendored `/code-review`), `/review-architecture` |
| Refresh the scaffold | `npx skills@latest add friofry/git-memory -s update-git-memory -a universal -y`, then `/update-git-memory` |
| Refresh Matt skills | `npx skills@latest update && ./scripts/check-memory.sh --fix` |

`npx skills@latest update` refreshes skills installed through the CLI; it does not
touch scaffold files already copied into a project. `/update-git-memory` compares
the current upstream scaffold, adds what is missing, and asks before merging any
existing file that differs.

You say **what** and answer **yes/no**; the agent does **how** and writes the
evidence into Git. Three stages need a human — `request`, `approval`, `acceptance` —
and everything between them is agent-driven by stage. The stage table, the skill
per stage, and the one prompt that starts a feature are in
[`scaffold/docs/agents/delivery-workflow.md`](scaffold/docs/agents/delivery-workflow.md).

Do **not** run Matt's `/setup-matt-pocock-skills` on a project that already has this
seed — it would overwrite `docs/agents/issue-tracker.md`, `triage-labels.md` and
`domain.md`. Do **not** edit files under `.agents/skills/`; bindings and conflicts
live in [`scaffold/docs/agents/vendored-skills.md`](scaffold/docs/agents/vendored-skills.md).

## What v2 adds

v1 answered "where does this fact live?" and "which stage is this feature in?". v2
answers "what kind of work is this?", "how do I name it?", "what do I send the
agent?" and "what actually blocks a merge?".

### Six orthogonal axes

Confusing any two of these is the failure mode the whole model exists to prevent.

| Axis | Question | Home |
|------|----------|------|
| Address | Which node is this? | The path — the address is derived from it, never stored |
| Type | What kind of work is it? | `Type:` line on the node file |
| Stage | Where is it in the lifecycle? | `Stage:` line in `specs/<NN>-<slug>/spec.md`, and nowhere else |
| Status | How far along, coarsely? | `Status:` line — feature status on the spec, triage label on a ticket |
| Owner | Who acts next? | Derived from the stage; no file carries an `Owner:` line |
| Evidence | What proves the claim? | Files, checks, PRs, CI runs, reviews |

`Type:` is not `Stage:`. A `Type: research` ticket can exist while its feature sits
at `Stage: build` — they answer different questions about different things.

### The method layer

**Project truth** (`CONTEXT.md`, `docs/domain/`, `docs/architecture/`, `docs/adr/`,
`specs/`) says what this product is. **Method truth**
([`scaffold/docs/method/`](scaffold/docs/method/)) says how work is typed,
addressed, gated and handed over. They do not mix: a review-severity rubric pasted
into the glossary is skipped by the people who came for the vocabulary and lost to
the people who needed the process.

Method truth is portable — it ships intact into the next repository — and it is
referenced by address, never copied. Eleven work types, six `M:` families, and the
rule for adding one are in
[`scaffold/docs/method/README.md`](scaffold/docs/method/README.md).

### Addressing

An address is a short projection of a path. Nothing is stored under an address that
is not already stored at a path, so renaming a file cannot orphan a reference that
`scripts/git-memory-resolve.sh` cannot recompute.

| Family | Example | Resolves to |
|--------|---------|-------------|
| Feature | `F:007-auth-envelope` | `specs/007-auth-envelope/` |
| Ticket | `T:007/03` | `.scratch/auth-envelope/issues/03-*.md` |
| Spike | `S:007/proto-a` | `spikes/auth-envelope/proto-a/` |
| ADR | `ADR:0012` | `docs/adr/0012-*.md` |
| Term | `TERM:event-envelope` | `CONTEXT.md`, that heading |
| Method | `M:gate-approval` | a `docs/method/**` heading |

A ticket address carries the feature's **number**, not its slug, so renaming a
feature does not invalidate every reference to its queue. Resolution rules and
worked examples: [`scaffold/docs/method/addressing.md`](scaffold/docs/method/addressing.md).

### Packets

A packet is the context envelope assembled for one agent turn at one stage, from six
layers — Route, Objective, Contract, Memory, Slice, Evidence — of which the stage's
profile keeps only some. A `build` packet carries Route, Contract and Slice and
deliberately omits the glossary; a `review` packet adds Memory and Evidence back,
because a reviewer without architecture context reviews syntax.

```bash
./scripts/git-memory-packet.sh F:007-auth-envelope build
```

Packets and the work graph print to stdout and are never committed. A committed
projection is a second copy of facts the node headers already carry, and the second
copy goes stale the first time someone edits a `Refs:` line. The profile table is
[`scaffold/docs/method/packet-profiles.md`](scaffold/docs/method/packet-profiles.md).

### Gates

Seven gates: request, approval, checks, review, CI, acceptance, memory. Each is a
named moment where a stage transition is blocked until specific evidence exists, and
each is addressable — `M:gate-approval` goes in a `Refs:` line, a PR body or a
prompt. Gates add no stages; they are the enforcement projection of the stage table.
Who opens each, what closes it, and the one failure mode it prevents:
[`scaffold/docs/method/gates.md`](scaffold/docs/method/gates.md).

### The GitHub layer

Issue forms carry `M:gate-request`; the PR template carries the handoff baton (node
address, stage, blocker, memory delta, commands and their results, closing keyword);
`CODEOWNERS` plus required review carries `M:gate-approval`.

Two workflows, split on purpose.
[`memory.yml`](scaffold/.github/workflows/memory.yml) is path-filtered and advisory.
[`delivery.yml`](scaffold/.github/workflows/delivery.yml) has no path filter and is
the one you make a required check — **a skipped job reports success**, so a
path-filtered workflow passes on exactly the changes it was never allowed to
inspect. Prefer strict required checks on the default branch. The whole layer ships
inert until branch protection is on:
[`scaffold/docs/agents/github-gates.md`](scaffold/docs/agents/github-gates.md).

## Versus vanilla Matt Pocock skills

Matt's skills are the craft. This repo adds a process that survives the end of a
chat session. The adapter-level detail is in
[`scaffold/docs/agents/vendored-skills.md`](scaffold/docs/agents/vendored-skills.md).

| | Vanilla Matt | This repo (after setup) |
|--|--|--|
| Spec | One `/to-spec` document | Four files under `specs/` + `Status:` / `Stage:` |
| "Where is the feature?" | Chat / tracker / memory | `Stage:` line in Git; `/orient-in-project` checks it against evidence |
| Tickets | `.scratch/` or GitHub Issues | Same local markdown + label vocabulary + `check-memory.sh` |
| Work typing | `grilling` / `task` from `/wayfinder` | Eleven types, one closed set, checked — the two aliases are rewritten on arrival |
| Naming a thing | Prose and file paths | Six address families, one resolver, usable in prompts and PR bodies |
| Context per turn | Decided again every session | The stage's packet profile, assembled by a script |
| Process boilerplate | Inside whichever skill uses it | `docs/method/`, cited by `M:` address, never pasted |
| TDD / review | `/tdd`, `/code-review` | Same craft; entry via `implement-feature` / `review-change` |
| Contracts | "Read CONTEXT / ADR" | Plus enforceable one-home checks |
| What blocks a merge | Nothing in particular | Seven gates, and a required check that always runs |
| Setup | `/setup-matt-pocock-skills` | Adapters already in the seed — do not re-run Matt setup |
| Autonomy | You hold the process in your head | Twelve stages in Git; human gates are request / approval / acceptance |

## Claude Web (upload ZIPs)

Claude.ai accepts **one skill per ZIP** (`skill-name/SKILL.md` at the archive root)
and cannot pull from `npx skills` or from GitHub. Package this repo's skills plus
Matt's set:

```bash
./scripts/package-claude-web-skills.sh              # full Matt set
./scripts/package-claude-web-skills.sh --set minimal
```

Artifacts land in `dist/claude-web/`:

| Artifact | Use |
|----------|-----|
| `skills/<name>.zip` | **27 files** for the full set — 9 repo skills plus 18 Matt skills. Upload each in **Customize → Skills → Upload a skill**, then enable it |
| `all-skill-zips.zip` | Convenience bag of those ZIPs (still upload one by one from inside) |
| `git-memory-claude-plugin.zip` | Optional Claude Code / org plugin layout |
| `MANIFEST.txt` | The exact skill list for the chosen Matt set |

`setup-git-memory.zip` is only the installer — it embeds `scaffold/`, including the
four scripts and the test harness, because in this channel there is no clone to copy
bytes from. The Matt craft skills and the other repo skills are **sibling** ZIPs in
the same `skills/` folder, not inside that archive. The script fails with a count
error rather than leaving one ZIP behind.

The packager clones [mattpocock/skills](https://github.com/mattpocock/skills) (or
takes `--matt-dir`), rewrites `.agents/skills/…` path references to uploaded-skill
names, and truncates descriptions to Claude's ~200-character limit. It discovers
repo skills from `skills/` and `scaffold/.cursor/skills/`, so adding a skill needs no
edit to the script.

## Layout of this repository

```
git-memory/
├── README.md
├── LICENSE
├── matt-skill-sets.txt
├── scripts/
│   └── package-claude-web-skills.sh    # Claude Web ZIP packager
├── skills/
│   ├── setup-git-memory/               # the installer skill
│   └── update-git-memory/              # the safe updater skill
└── scaffold/                           # bytes copied into targets
    ├── AGENTS.md
    ├── CONTEXT.md
    ├── docs/
    │   ├── memory.md
    │   ├── agents/                     # delivery workflow, tracker, vendored skills, github gates
    │   ├── method/                     # types, addressing, gates, packet profiles
    │   │   └── boilerplates/           # the prose that is cited, never pasted
    │   └── adr/ · architecture/ · product/
    ├── specs/ · .scratch/ · rules/ · templates/
    ├── scripts/
    │   ├── check-memory.sh
    │   ├── git-memory-resolve.sh       # the only address parser
    │   ├── git-memory-graph.sh
    │   ├── git-memory-packet.sh
    │   └── test/run-tests.sh
    ├── .cursor/skills/
    └── .github/
        ├── workflows/                  # memory.yml (advisory) · delivery.yml (requirable)
        ├── ISSUE_TEMPLATE/
        ├── pull_request_template.md
        └── CODEOWNERS
```

## Design notes

- **Upstream owns the craft** (grill, TDD, review axes). **The target repo owns
  placement** (the `Stage:` line, the paths, the test commands). The ADR-shaped
  write-up of that split is ADR 0016 in
  [`friofry/starcraft-benchmark`](https://github.com/friofry/starcraft-benchmark).
- **Projections are computed, not committed.** The graph and packets print to
  stdout; `build/` is gitignored. There is therefore no stale-generated-file failure
  mode — the only way for the graph to be wrong is for the node headers to be wrong,
  which `check-memory.sh` already checks.
- **Local markdown is the writable truth; GitHub Issues are intake.** Two writable
  stores mean an unbounded reconciliation problem with no correct answer. The two
  layers meet once, at the pull request.
- **Addresses are derived from paths, never stored.** An address that is stored can
  disagree with the file it names; one that is derived cannot.
- **v1 installs stay green.** Every new structural requirement lives behind
  `check-memory.sh --strict`, so a repository that predates node headers keeps
  passing a default run. `/update-git-memory` migrates it when its owner is ready.
- **Vendored skill bytes are pinned** in `.agents/skills.sha256` after install, so a
  local edit fails the checker instead of vanishing on the next `npx skills update`.
- **Empty product folders stay thin on purpose** — see the growth rule in
  [`scaffold/docs/memory.md`](scaffold/docs/memory.md).
