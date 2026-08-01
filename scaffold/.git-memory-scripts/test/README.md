# Script layer tests

The home for how the scripts in [`../`](../) are proved to work:
[`run-tests.sh`](run-tests.sh) builds throwaway repositories under `mktemp -d`, runs
a script against one, and asserts on the exit status and on what was printed.

No bats, no npm, no committed fixtures. The suite is one bash file with no
dependency a repository that installed this scaffold does not already have, because
a test suite that needs installing is a test suite that stops being run.

## Running it

```bash
./.git-memory-scripts/test/run-tests.sh              # every section
./.git-memory-scripts/test/run-tests.sh --verbose    # print expected, actual and the whole output on failure
./.git-memory-scripts/test/run-tests.sh checker      # one section: resolver, graph, packet or checker
./.git-memory-scripts/test/run-tests.sh --keep       # leave the fixtures on disk and print the path
```

Output is TAP-ish — `ok N - description`, `not ok N - description`, a `1..N` plan
line, then a one-line summary. Exit status is 0 when every assertion passed, 1 when
one failed, 2 on a usage error. A full run is 191 assertions in about twenty
seconds; the budget is thirty, and a change that pushes past it is a change to
reconsider rather than a budget to raise.

`python3` is used for one thing only: proving that the JSON the graph and the packet
emit actually parses. It is not required — those two assertions report
`# SKIP python3 is not installed` and the rest of the suite runs unchanged.

Nothing outside the temporary directory is written, and a trap removes it however
the run ends, including on Ctrl-C. `--keep` is the one exception and prints where it
left things.

## What it covers

| Section | Script | The claims it pins down |
|---------|--------|-------------------------|
| `resolver` | [`../git-memory-resolve.sh`](../git-memory-resolve.sh) | a round trip for each of the six address families; an unresolvable address exits 1 and names the glob that came back empty; an address declared twice is a failure, not a tie to break; `--all` lists every node; `--check` prints nothing on either stream |
| `graph` | [`../git-memory-graph.sh`](../git-memory-graph.sh) | all three formats; every ndjson line parses as one JSON object; dot carries both edge kinds; a feature with two tickets and a spike is four nodes; a repository with no specs exits 0 and prints nothing |
| `packet` | [`../git-memory-packet.sh`](../git-memory-packet.sh) | for each of the ten stages that have a profile, the layers it carries and the layers it names as omitted; json parses and holds all six layers; `--budget` truncates and says so; `ci` and `request` exit 1; an unresolvable address exits 1 |
| `checker` | [`../check-memory.sh`](../check-memory.sh) | **a v1-shaped repository exits 0 on a default run**; one passing and one failing fixture per check; `--fix` regenerates the specs table; `--strict` catches what a default run does not; an unknown flag exits 2 |

The most important assertion in the file is the first one in the `checker` section: a
repository that installed this scaffold before the v2 node header existed must still
pass a default `check-memory.sh` run. Everything the header added lives behind
`--strict` — see [`../../docs/memory.md`](../../docs/memory.md). A default run that
fails on a repository installed last year is a broken upgrade, not a caught
inconsistency, and it is the one failure this suite exists to make impossible to
ship.

The profile matrix the `packet` section asserts against is written out again inside
`run-tests.sh`, transcribed from
[`../../docs/method/packet-profiles.md`](../../docs/method/packet-profiles.md)
rather than read from the script. That duplication is deliberate: a test that reads
its expectation from the code under test asserts only that the code is
self-consistent. If the doc changes, both copies change with it.

## The two fixtures

Every test starts from one of two shapes, each built once per run and copied for
each test that wants one.

| Builder | Shape | Used for |
|---------|-------|----------|
| `make_v1_repo` | a spec carrying `Status:` and `Stage:` and nothing else; tickets in the older `**Status:**` form; no ADR, no method layer, no spike | the backward-compatibility contract, and the graph's projection of a repository with no header lines |
| `make_v2_repo` | the same repository with full node headers, plus one node in each of the six address families: feature `007-auth-envelope`, tickets `T:007/01` and `T:007/03`, spike `S:007/proto-a`, `ADR:0012`, `TERM:event-envelope`, `M:gate-approval` | everything else |

Both use the running example `007-auth-envelope`, the same one the method docs use,
so a fixture path in a failure message reads the same way as a path in
[`../../docs/method/addressing.md`](../../docs/method/addressing.md).

The fixtures are directories, not Git repositories. That is deliberate — `git init`
per fixture buys nothing and costs a fork — and it means the packet's Route layer
prints `Branch: (not a git repository)`, which is asserted rather than tolerated.

## Adding a test

A new test is three lines, not forty. Build a fixture, run a script, assert:

```bash
repo=$(new_repo)
make_v2_repo "$repo"
run "$repo" git-memory-graph.sh --format md
expect_status 0 "graph: --format md exits 0"
expect_has "$RUN_OUT" "# Work graph" "graph: md opens with a title"
```

`run` captures the two streams apart into `RUN_OUT` and `RUN_ERR`, the status into
`RUN_STATUS`, and both streams concatenated into `RUN_BOTH` for the one assertion
that a command printed nothing at all. `run_from_elsewhere` is the same call from an
unrelated working directory, which is how "every script runs from anywhere" is
tested.

| Assertion | Asserts |
|-----------|---------|
| `expect_status <n> <desc>` | the exit status of the last `run` |
| `expect_has <haystack> <needle> <desc>` | a substring is present |
| `expect_lacks <haystack> <needle> <desc>` | a substring is absent |
| `expect_line <haystack> <line> <desc>` | a whole line matches exactly |
| `expect_equal <actual> <want> <desc>` | two strings are equal |
| `expect_empty <value> <desc>` | a captured stream is empty |
| `skip <desc> <reason>` | the test could not run here, and that is not a failure |

Assert on **output content as well as exit status**. A script that exits 1 for the
wrong reason passes a status-only test, and the next person to read the message
believes it.

To add a failing fixture for a new checker rule, write a mutator that takes the
repository first and turns a clean v2 fixture into the one repository that fails
exactly that rule, then name it in one `case_fail` line:

```bash
mut_unknown_type() { set_field "$1" "$ticket_md" Type grilling; }

case_fail "an unknown Type: value" "unknown work type 'grilling'" mut_unknown_type
```

`set_field` rewrites a header line, or prepends it when the key is absent.
`set_stage` rewrites `Stage:` and `Status:` together and regenerates the specs table,
because a stage change that leaves the table stale fails a second check and buries
the one you meant to test.

## The rule for a new check

**A new check in [`../check-memory.sh`](../check-memory.sh) lands with a passing
fixture and a failing fixture in the same commit.** Both, in the same commit, or the
check does not land.

- The **failing** fixture proves the check fires, and that its message names the
  offending value rather than reporting that something somewhere is wrong.
- The **passing** fixture proves it does not fire on a clean repository. Assert the
  exact `ok` line the check prints, in the clean-v2 block at the top of
  `test_checker`. A check that fires on a correct repository gets disabled within a
  week, and every check after it is trusted a little less.

The same rule applies to a new stage profile in
[`../../docs/method/packet-profiles.md`](../../docs/method/packet-profiles.md) — add
its row to `profile_included` and `profile_omitted` — and to a seventh address
family, which is an ADR-shaped decision before it is a test
([`../../docs/method/addressing.md`](../../docs/method/addressing.md)).

## Portability

These scripts ship into other people's repositories, so the suite and everything it
tests must run on macOS `bash 3.2` with a BSD userland as well as on Linux. Forbidden
throughout: `mapfile`, `readarray`, `declare -A`, `${var^^}`, `sed -i`, `grep -P`,
`find -printf`, `stat -c`, `date -d`, `readlink -f`, `sort -V`, and `echo` with
escapes. Use `printf`, quote every expansion, and remember that `grep` exits 1 on no
match — which kills a pipeline under `pipefail` and is the single most common way a
check silently stops checking.

## Stop conditions

- **Do not commit a fixture repository.** Every fixture is built in the test that
  needs it. A committed fixture drifts from the shape the scripts actually meet, and
  the suite goes on passing against a repository nobody has any more.
- **Do not assert on a generated file's presence in the working tree.** The graph and
  the packet print to stdout and write nothing; that is the design, not an
  oversight — [`../../docs/method/addressing.md`](../../docs/method/addressing.md).
- **Do not make a test depend on another test's fixture.** Each one builds its own,
  so a failure is reproducible with `--keep` and one command.
- **Do not weaken an assertion to make a red suite green.** The suite is the evidence
  that `M:gate-checks` demands — [`../../docs/method/gates.md`](../../docs/method/gates.md).
  A red suite is a finding; an edited expectation is a lost one.
