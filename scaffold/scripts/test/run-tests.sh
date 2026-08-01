#!/usr/bin/env bash
#
# The test suite for the script layer (see scripts/test/README.md).
#
#   scripts/test/run-tests.sh             run every section, TAP-ish output
#   scripts/test/run-tests.sh --verbose   print expected and actual on every failure
#   scripts/test/run-tests.sh checker     run one section only
#   scripts/test/run-tests.sh --help      usage, exit 0
#
# No bats, no npm, no fixtures committed to the repository: every test builds the
# repository it needs under mktemp -d, runs a script against it, and asserts on the
# exit status and on the output. python3 is used for one thing only — proving that
# emitted JSON parses — and its absence skips those tests rather than failing them.
#
set -uo pipefail
shopt -s nullglob

# The scripts under test are this script's siblings one level up, and each of them
# cd's to its own repository root, so the harness never has to.
cd "$(dirname "$0")/.." || exit 1
scripts_dir=$(pwd)

self=$(basename "$0")
nl=$'\n'

# The address index is tab-separated, and a literal tab inside a test's expected
# string is the kind of byte an editor silently rewrites into spaces. Named once.
tab=$(printf '\t')

VERBOSE=0
KEEP=0
SECTIONS="resolver graph packet checker headers"

usage() {
  cat <<'EOF'
usage: run-tests.sh [--verbose] [--keep] [resolver|graph|packet|checker|headers]
       run-tests.sh --help

Run the script layer's tests. Each test builds a throwaway repository under
mktemp -d, runs one of the scripts against it, and asserts on the exit status
and on what was printed. Nothing outside that temporary directory is written, and
a trap removes it however the run ends.

  --verbose  print the expected value, the actual value and the whole captured
             output for every failing assertion.
  --keep     leave the fixture repositories on disk and print the path. Use it to
             reproduce a failure by hand; the run is otherwise unchanged.
  <section>  run one of resolver, graph, packet, checker, headers. Default: all.

Output is TAP-ish: one "ok N - description" or "not ok N - description" per
assertion, a "1..N" plan line, then a one-line summary.

Exit status: 0 every assertion passed, 1 one or more failed, 2 a usage error.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -v|--verbose) VERBOSE=1 ;;
    --keep)       KEEP=1 ;;
    -h|--help)    usage; exit 0 ;;
    resolver|graph|packet|checker|headers) SECTIONS=$1 ;;
    *)
      printf '%s: unknown argument %s\n\n' "$self" "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

# --- 1. the temporary root -----------------------------------------------------
# One root for the whole run, one directory per fixture inside it. The trap is
# installed before the first mkdir so a failure between here and the first test
# still cleans up; INT and TERM are named separately because bash runs the EXIT
# trap after them and rm -rf twice is harmless.

tmproot=$(mktemp -d "${TMPDIR:-/tmp}/git-memory-tests.XXXXXX") || exit 1

cleanup() {
  if [ "$KEEP" -eq 1 ]; then
    printf '# fixtures kept in %s\n' "$tmproot"
    return
  fi
  rm -rf "$tmproot"
}
trap cleanup EXIT
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

new_repo() { mktemp -d "$tmproot/repo.XXXXXX"; }

# --- 2. TAP reporting ----------------------------------------------------------
# One assertion is one numbered line. A failure prints what was expected and what
# arrived; --verbose adds the whole captured output, which is the difference
# between "not ok 41" and knowing why.

tests=0
failures=0
skips=0

pass() {
  tests=$((tests + 1))
  printf 'ok %d - %s\n' "$tests" "$1"
}

fail() { # description, expected, actual
  tests=$((tests + 1))
  failures=$((failures + 1))
  printf 'not ok %d - %s\n' "$tests" "$1"
  printf '#   expected: %s\n' "$2"
  printf '#   actual:   %s\n' "$3"
  [ -n "$RUN_CMD" ] && printf '#   command:  %s (in %s)\n' "$RUN_CMD" "$RUN_DIR"
  if [ "$VERBOSE" -eq 1 ] && [ -n "$RUN_ALL" ]; then
    printf '%s\n' "$RUN_ALL" | sed 's/^/#   > /'
  fi
}

skip() { # description, reason
  tests=$((tests + 1))
  skips=$((skips + 1))
  printf 'ok %d - %s # SKIP %s\n' "$tests" "$1" "$2"
}

# --- 3. running a script under test --------------------------------------------
# stdout and stderr are captured apart, because "--check is silent" and "the
# diagnostic names the address" are different claims about different streams.

RUN_OUT=""
RUN_ERR=""
RUN_ALL=""
RUN_BOTH=""
RUN_STATUS=0
RUN_CMD=""
RUN_DIR=""

# RUN_BOTH is the two streams concatenated with nothing between them, which is the
# only form in which "this command printed nothing at all" is one assertion.
capture() {
  RUN_ERR=$(cat "$tmproot/stderr" 2>/dev/null)
  RUN_ALL="$RUN_OUT$nl--- stderr ---$nl$RUN_ERR"
  RUN_BOTH="$RUN_OUT$RUN_ERR"
}

run() { # repo, script, args...
  local repo=$1 script=$2
  shift 2
  RUN_DIR=$repo
  RUN_CMD="scripts/$script $*"
  RUN_OUT=$(cd "$repo" && bash "scripts/$script" "$@" 2>"$tmproot/stderr")
  RUN_STATUS=$?
  capture
}

# Same script, invoked by absolute path from an unrelated working directory: rule 4
# of the contract's script layer is that every script runs from anywhere.
run_from_elsewhere() { # repo, script, args...
  local repo=$1 script=$2
  shift 2
  RUN_DIR=$tmproot
  RUN_CMD="$repo/scripts/$script $* (cwd $tmproot)"
  RUN_OUT=$(cd "$tmproot" && bash "$repo/scripts/$script" "$@" 2>"$tmproot/stderr")
  RUN_STATUS=$?
  capture
}

# --- 4. assertions -------------------------------------------------------------
# Every needle is matched with a quoted case pattern, so a needle holding * or [
# is compared literally rather than read as a glob.

expect_status() { # want, description
  if [ "$RUN_STATUS" -eq "$1" ]; then
    pass "$2"
  else
    fail "$2" "exit status $1" "exit status $RUN_STATUS"
  fi
}

expect_has() { # haystack, needle, description
  case "$1" in
    *"$2"*) pass "$3" ;;
    *)      fail "$3" "output contains: $2" "it does not" ;;
  esac
}

expect_lacks() { # haystack, needle, description
  case "$1" in
    *"$2"*) fail "$3" "output does not contain: $2" "it does" ;;
    *)      pass "$3" ;;
  esac
}

expect_line() { # haystack, whole line, description
  case "$nl$1$nl" in
    *"$nl$2$nl"*) pass "$3" ;;
    *)            fail "$3" "a line reading: $2" "no such line" ;;
  esac
}

expect_equal() { # actual, want, description
  if [ "$1" = "$2" ]; then
    pass "$3"
  else
    fail "$3" "$2" "$1"
  fi
}

expect_empty() { # value, description
  if [ -z "$1" ]; then
    pass "$2"
  else
    fail "$2" "nothing" "$1"
  fi
}

have_python3() { command -v python3 >/dev/null 2>&1; }

# --- 5. fixture construction ---------------------------------------------------
# Two shapes, one builder each, so a new test is three lines rather than forty:
#
#   make_v1_repo  a repository installed before the v2 node header existed. It
#                 carries a status and a stage on its spec and nothing else, and
#                 the whole backward-compatibility contract is that a default
#                 check-memory.sh run stays green on it.
#   make_v2_repo  the same repository with full node headers, an ADR, a glossary
#                 term, a method declaration and a spike — one node in each of the
#                 six address families.

write() { # path (content on stdin)
  mkdir -p "${1%/*}"
  cat > "$1"
}

# Each shape is built once and copied for every test that wants one. A fixture is
# twenty small files and four scripts; building it per test cost more than running
# the script under test did, and the suite has a thirty-second budget to keep.
# cp -R "<dir>/." copies the dotfiles too, which matters: .scratch/ is the whole
# ticket layer.
clone_template() { # builder, template name, destination
  local builder=$1 template="$tmproot/template.$2" dest=$3
  if [ ! -d "$template" ]; then
    mkdir -p "$template"
    "$builder" "$template"
  fi
  cp -R "$template/." "$dest/"
}

install_scripts() { # repo
  mkdir -p "$1/scripts/lib"
  cp "$scripts_dir/git-memory-resolve.sh" \
     "$scripts_dir/git-memory-graph.sh" \
     "$scripts_dir/git-memory-packet.sh" \
     "$scripts_dir/check-memory.sh" "$1/scripts/"
  # The shared header reader travels with them; every script refuses to run
  # without it rather than falling back to a private copy, which is the whole
  # point of there being one reader.
  cp "$scripts_dir/lib/git-memory-lib.sh" "$1/scripts/lib/"
  chmod +x "$1"/scripts/*.sh
}

# The generated block of specs/README.md, derived here from the spec.md files
# rather than by asking the script under test — otherwise a broken --fix would
# write the fixture it is then measured against.
sync_specs_table() { # repo
  local repo=$1 d slug status stage rows=""
  for d in "$repo"/specs/[0-9][0-9][0-9]-*/; do
    [ -f "$d/spec.md" ] || continue
    slug=$(basename "$d")
    status=$(sed -n 's/^Status: *//p' "$d/spec.md" | head -1)
    stage=$(sed -n 's/^Stage: *//p' "$d/spec.md" | head -1)
    rows="$rows| [\`$slug\`]($slug/) | $stage | $status |$nl"
  done
  {
    printf '# Specs\n\n'
    printf 'One directory per feature. The table below is generated; regenerate it\n'
    printf 'with scripts/check-memory.sh --fix.\n\n'
    printf '<!-- BEGIN generated:specs-table -->\n'
    printf '| Spec | Stage | Status |\n|------|-------|--------|\n'
    printf '%s' "$rows"
    printf '<!-- END generated:specs-table -->\n'
  } > "$repo/specs/README.md"
}

# Everything both shapes share: the prose layers, the rules, the commands the
# Slice layer quotes, and the glossary heading TERM: resolves against.
write_common() { # repo
  local d=$1
  install_scripts "$d"

  write "$d/README.md" <<'EOF'
# Auth service

A fixture repository for the git-memory script layer. It exists to be checked,
resolved, graphed and packeted, and holds no code.
EOF

  write "$d/AGENTS.md" <<'EOF'
# Agents

Read docs/memory.md first. The delivery stage of a feature lives in its spec.

## Before finishing

```bash
./scripts/check-memory.sh
```
EOF

  write "$d/CONTEXT.md" <<'EOF'
# Context

The domain vocabulary of the auth service.

## Event envelope

The signed wrapper every outbound event travels in. The producer signs it; the
consumer verifies the signature before reading a field.

## Consumer

Any service that reads the outbound event stream.
EOF

  write "$d/active-context.md" <<'EOF'
# Active context

## Direction

Finish the envelope before touching key rotation.

## Active goal

Sign every outbound event.
EOF

  write "$d/docs/memory.md" <<'EOF'
# Memory map

Stable layers at the top, volatile at the bottom. A fact has one home; every
other file links to it.
EOF

  write "$d/rules/README.md" <<'EOF'
# Rules

Short, checkable constraints. One file per topic, one constraint per heading.
EOF

  write "$d/rules/events.md" <<'EOF'
# Event rules

## Every outbound event is signed

Signing happens in the envelope signer and nowhere else.
EOF

  write "$d/specs/007-auth-envelope/design.md" <<'EOF'
# Design

## Seam: envelope signer

The producer builds an envelope and hands it to the signer. Nothing else builds
a signature.
EOF

  write "$d/specs/007-auth-envelope/acceptance.md" <<'EOF'
# Acceptance

## Scenario: a consumer rejects an unsigned event

Given an event with no signature
When the consumer reads it
Then it is rejected and counted.
EOF

  write "$d/specs/007-auth-envelope/decisions.md" <<'EOF'
# Decisions

Local to this feature. Anything the rest of the project must obey moves to an ADR.

## The signer owns the clock

Timestamps come from the signer so a replayed envelope is detectable.
EOF
}

make_v1_repo() { clone_template build_v1_repo v1 "$1"; }
make_v2_repo() { clone_template build_v2_repo v2 "$1"; }

build_v1_repo() { # repo
  local d=$1
  write_common "$d"

  # No ID:, no Type:, no Parent: — this is the shape the backward-compatibility
  # contract is written about (docs/memory.md, "Node headers").
  write "$d/specs/007-auth-envelope/spec.md" <<'EOF'
# Auth envelope

Status: active
Stage: build

## Outcome

Every outbound event travels in a signed envelope the consumer can verify.

## In scope

- Signing on the producer side.
- Verification on the consumer side.

## Out of scope

- Key rotation.

## Constraints

- No new runtime dependency.
EOF

  # The bold form a ticket written before the header existed carries.
  write "$d/.scratch/auth-envelope/issues/01-envelope-schema.md" <<'EOF'
# Agree the envelope schema

**Status:** done

The producer and the consumer agree on the field set before either is built.
EOF

  write "$d/.scratch/auth-envelope/issues/03-envelope-signing.md" <<'EOF'
# Sign the envelope on the producer side

**Status:** ready-for-agent

Sign in the envelope signer. Nothing else builds a signature.
EOF

  sync_specs_table "$d"
}

build_v2_repo() { # repo
  local d=$1
  write_common "$d"

  write "$d/specs/007-auth-envelope/spec.md" <<'EOF'
# Auth envelope

ID: F:007-auth-envelope
Type: feature
Status: active
Stage: build
Parent: none
Children: T:007/01, T:007/03
Refs: ADR:0012, TERM:event-envelope, M:gate-approval

## Outcome

Every outbound event travels in a signed envelope the consumer can verify.

## In scope

- Signing on the producer side.
- Verification on the consumer side.

## Out of scope

- Key rotation.

## Constraints

- No new runtime dependency.
EOF

  write "$d/.scratch/auth-envelope/issues/01-envelope-schema.md" <<'EOF'
# Agree the envelope schema

ID: T:007/01
Type: interface
Status: done
Parent: F:007-auth-envelope
Refs: TERM:event-envelope

The producer and the consumer agree on the field set before either is built.

## Answer

Six fields, listed in the ADR.
EOF

  write "$d/.scratch/auth-envelope/issues/03-envelope-signing.md" <<'EOF'
# Sign the envelope on the producer side

ID: T:007/03
Type: implementation
Status: ready-for-agent
Parent: F:007-auth-envelope
Blocked by: T:007/01
Refs: ADR:0012

Sign in the envelope signer. Nothing else builds a signature.
EOF

  write "$d/spikes/auth-envelope/proto-a/README.md" <<'EOF'
# Can we sign an envelope in under a millisecond?

ID: S:007/proto-a
Type: prototype
Parent: F:007-auth-envelope

Timeboxed to one afternoon. Throwaway.
EOF

  write "$d/docs/adr/0012-signed-auth-envelope.md" <<'EOF'
# Sign the auth envelope rather than the transport

Transport signing would have tied verification to one deployment topology, so the
envelope carries its own signature and travels unchanged through any hop.
EOF

  write "$d/docs/method/gates.md" <<'EOF'
# Gates

A gate is a named moment where a stage transition is blocked until specific
evidence exists.

## `M:gate-approval`

Blocks the move into plan. The four approval files are present and a human has
read them.

## `M:gate-review`

Blocks the move into ci. A review artifact exists in the templates/review.md shape.
EOF

  sync_specs_table "$d"
}

# --- 6. mutators ---------------------------------------------------------------
# Each one turns a clean v2 fixture into the one repository that fails exactly one
# check. They take the repository first so a case can pass extra arguments.

set_field() { # repo, relative path, key, value
  local f="$1/$2" key=$3 val=$4
  if grep -q "^$key:" "$f" 2>/dev/null; then
    awk -v key="$key" -v val="$val" '
      !done && index($0, key ":") == 1 { print key ": " val; done = 1; next }
      { print }
    ' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  else
    { printf '%s: %s\n' "$key" "$val"; cat "$f"; } > "$f.tmp" && mv "$f.tmp" "$f"
  fi
}

spec_md=specs/007-auth-envelope/spec.md
ticket_md=.scratch/auth-envelope/issues/03-envelope-signing.md

set_stage() { # repo, stage, status
  set_field "$1" "$spec_md" Stage "$2"
  set_field "$1" "$spec_md" Status "$3"
  sync_specs_table "$1"
}

add_review_artifact() { # repo
  # The two severities the artifact's Severity: line cites, declared at heading
  # level 1 in their own files — the resolver reads a method heading at any level,
  # and an M: address nothing declares is a failure of its own.
  write "$1/docs/method/boilerplates/review-blocking.md" <<'EOF'
# `M:review-blocking`

The change ships a defect, violates a documented rule, or contradicts an ADR.
EOF

  write "$1/docs/method/boilerplates/review-nonblocking.md" <<'EOF'
# `M:review-nonblocking`

Worth saying, not worth holding the change for. It becomes a ticket.
EOF

  write "$1/.scratch/auth-envelope/reviews/01-auth-envelope.md" <<'EOF'
# Review — the envelope signer, first pass

Node: F:007-auth-envelope
Range: main...HEAD, 4 commits
Reviewer: a second pair of eyes
Severity: M:review-blocking | M:review-nonblocking

## Blocking issues

None.
EOF
}

mut_unknown_type()      { set_field "$1" "$ticket_md" Type grilling; }
mut_illegal_type()      { set_field "$1" "$spec_md" Type implementation; }
mut_id_mismatch()       { set_field "$1" "$ticket_md" ID T:007/09; }
mut_stage_on_ticket()   { set_field "$1" "$ticket_md" Stage build; }
mut_dangling_address()  { set_field "$1" "$ticket_md" "Blocked by" T:007/99; }
mut_undeclared_method() { set_field "$1" "$ticket_md" Refs M:ticket-nonexistent; }
mut_root_context()      { printf '# Direction\n\nWork on the envelope.\n' > "$1/context.md"; }

# Two tickets waiting on each other. Not a slow queue — a frontier that can
# never open, and until now nothing in the system reported it.
mut_blocking_cycle() {
  write "$1/.scratch/auth-envelope/issues/01-envelope-schema.md" <<'EOF'
# Envelope schema

ID: T:007/01
Type: interface
Status: needs-triage
Parent: F:007-auth-envelope
Blocked by: T:007/03
EOF
  write "$1/.scratch/auth-envelope/issues/03-envelope-signing.md" <<'EOF'
# Sign the envelope

ID: T:007/03
Type: implementation
Status: needs-triage
Parent: F:007-auth-envelope
Blocked by: T:007/01
EOF
}

# A ticket folder whose feature spec was renamed or never created. This check
# was dead for the whole of v1: shopt -s nullglob erased the non-matching glob,
# bare `ls -d` listed the current directory and exited 0, so the `if !` branch
# was unreachable and every orphan was reported as fine.
mut_scratch_orphan() {
  mkdir -p "$1/.scratch/ghost-feature/issues"
  write "$1/.scratch/ghost-feature/issues/01-question.md" <<'EOF'
# A ticket whose feature does not exist

ID: T:404/01
Type: research
Status: needs-triage
Parent: F:404-ghost-feature
EOF
}

mut_duplicate_method() {
  write "$1/docs/method/gates-again.md" <<'EOF'
# Gates, declared a second time

## `M:gate-approval`

The same address, declared in a second file. One of the two must go.
EOF
}

mut_duplicate_ticket_number() {
  write "$1/.scratch/auth-envelope/issues/03-envelope-signature.md" <<'EOF'
# Sign the envelope, again

ID: T:007/03
Type: implementation
Status: needs-triage
Parent: F:007-auth-envelope

A second ticket numbered 03, added on another branch.
EOF
}

mut_stale_specs_table() {
  awk '{ sub(/\| build \| active \|/, "| plan | draft |"); print }' \
    "$1/specs/README.md" > "$1/specs/README.md.tmp" &&
    mv "$1/specs/README.md.tmp" "$1/specs/README.md"
}

# --- 7. the resolver -----------------------------------------------------------
# One round trip per family, both failure modes the docs name, and the two
# interfaces every other script reads: --all and --check.

test_resolver() {
  local repo out
  repo=$(new_repo)
  make_v2_repo "$repo"

  run "$repo" git-memory-resolve.sh --help
  expect_status 0 "resolver: --help exits 0"

  expect_has "$RUN_OUT" "usage: git-memory-resolve.sh" "resolver: --help prints a usage block"

  # --- --print: the section, not the file that contains it ---
  run "$repo" git-memory-resolve.sh --print M:gate-approval
  expect_status 0 "resolver: --print exits 0 on a method address"
  expect_has "$RUN_OUT" 'M:gate-approval' "resolver: --print opens with the heading it was asked for"
  expect_lacks "$RUN_OUT" 'M:gate-review' "resolver: --print stops before the next gate"
  out=$(wc -c < "$repo/docs/method/gates.md")
  if [ "${#RUN_OUT}" -lt "$out" ]; then
    pass "resolver: --print returns less than the whole file"
  else
    fail "resolver: --print returns less than the whole file" "fewer than $out bytes" "${#RUN_OUT}"
  fi

  # A sub-heading belongs to its section; a sibling at the same level does not.
  write "$repo/CONTEXT.md" <<'EOF'
# Glossary

## Event envelope

A signed wrapper around one domain event.

### Fields

Header, payload, signature.

## Replay window

A different term entirely.
EOF
  run "$repo" git-memory-resolve.sh --print TERM:event-envelope
  expect_status 0 "resolver: --print exits 0 on a term address"
  expect_has "$RUN_OUT" "signed wrapper" "resolver: --print carries the term's body"
  expect_has "$RUN_OUT" "Header, payload" "resolver: --print carries a sub-heading of the section"
  expect_lacks "$RUN_OUT" "different term entirely" "resolver: --print stops at the next term"

  # A directory address has no section to cut out.
  run "$repo" git-memory-resolve.sh --print F:007-auth-envelope
  expect_status 0 "resolver: --print exits 0 on a feature address"
  expect_has "$RUN_OUT" "specs/007-auth-envelope/" "resolver: --print names the path for a directory address"

  run "$repo" git-memory-resolve.sh --print M:nonexistent-gate
  expect_status 1 "resolver: --print exits 1 on an address that resolves to nothing"
  run "$repo" git-memory-resolve.sh --print M:gate-approval M:gate-review
  expect_status 1 "resolver: --print refuses two addresses"

  # F: — the address the operator types, slug and all.
  run "$repo" git-memory-resolve.sh resolve F:007-auth-envelope
  expect_status 0 "resolver: F:007-auth-envelope resolves"
  expect_equal "$RUN_OUT" "specs/007-auth-envelope/" "resolver: F: prints the feature directory"

  # T: — the number, not the slug, so the .scratch folder is found by lookup.
  run "$repo" git-memory-resolve.sh resolve T:007/03
  expect_status 0 "resolver: T:007/03 resolves"
  expect_equal "$RUN_OUT" ".scratch/auth-envelope/issues/03-envelope-signing.md" \
    "resolver: T: prints the ticket file"

  run "$repo" git-memory-resolve.sh resolve S:007/proto-a
  expect_status 0 "resolver: S:007/proto-a resolves"
  expect_equal "$RUN_OUT" "spikes/auth-envelope/proto-a/" "resolver: S: prints the spike directory"

  run "$repo" git-memory-resolve.sh resolve ADR:0012
  expect_status 0 "resolver: ADR:0012 resolves"
  expect_equal "$RUN_OUT" "docs/adr/0012-signed-auth-envelope.md" "resolver: ADR: prints the decision file"

  run "$repo" git-memory-resolve.sh resolve TERM:event-envelope
  expect_status 0 "resolver: TERM:event-envelope resolves"
  expect_equal "$RUN_OUT" "CONTEXT.md#event-envelope" "resolver: TERM: prints the glossary anchor"

  run "$repo" git-memory-resolve.sh resolve M:gate-approval
  expect_status 0 "resolver: M:gate-approval resolves"
  expect_equal "$RUN_OUT" "docs/method/gates.md#mgate-approval" "resolver: M: prints the method anchor"

  # The bare form is the same call as `resolve`, and both work from any directory.
  run_from_elsewhere "$repo" git-memory-resolve.sh F:007-auth-envelope
  expect_status 0 "resolver: the bare form resolves from an unrelated working directory"
  expect_equal "$RUN_OUT" "specs/007-auth-envelope/" "resolver: the path is repo-relative wherever it ran"

  # An unresolvable address exits 1 and says which glob came back empty.
  run "$repo" git-memory-resolve.sh resolve T:007/99
  expect_status 1 "resolver: an unresolvable address exits 1"
  expect_has "$RUN_ERR" "no file matches .scratch/auth-envelope/issues/99-*.md" \
    "resolver: the diagnostic names the glob that came back empty"
  expect_empty "$RUN_OUT" "resolver: an unresolvable address prints nothing on stdout"

  run "$repo" git-memory-resolve.sh resolve NODE:007
  expect_status 1 "resolver: an unknown family exits 1"
  expect_has "$RUN_ERR" "expected one of F: T: S: ADR: TERM: M:" "resolver: it lists the six families"

  # Two headings declaring one M: address is a failure, not a tie to break.
  run "$repo" git-memory-resolve.sh resolve M:gate-approval
  expect_status 0 "resolver: M:gate-approval resolves while declared once"
  mut_duplicate_method "$repo"
  run "$repo" git-memory-resolve.sh resolve M:gate-approval
  expect_status 1 "resolver: a twice-declared M: address exits 1"
  expect_has "$RUN_ERR" "declared 2 times" "resolver: it names both declarations"
  rm -f "$repo/docs/method/gates-again.md"

  # --all is the address index every other script reads instead of parsing.
  run "$repo" git-memory-resolve.sh --all
  expect_status 0 "resolver: --all exits 0"
  out=$RUN_OUT
  expect_line "$out" "F:007-auth-envelope${tab}specs/007-auth-envelope/" "resolver: --all lists the feature"
  expect_line "$out" "T:007/01${tab}.scratch/auth-envelope/issues/01-envelope-schema.md" "resolver: --all lists ticket 01"
  expect_line "$out" "T:007/03${tab}.scratch/auth-envelope/issues/03-envelope-signing.md" "resolver: --all lists ticket 03"
  expect_line "$out" "S:007/proto-a${tab}spikes/auth-envelope/proto-a/" "resolver: --all lists the spike"
  expect_line "$out" "ADR:0012${tab}docs/adr/0012-signed-auth-envelope.md" "resolver: --all lists the ADR"
  expect_line "$out" "TERM:event-envelope${tab}CONTEXT.md#event-envelope" "resolver: --all lists the term"
  expect_line "$out" "M:gate-approval${tab}docs/method/gates.md#mgate-approval" "resolver: --all lists the method ref"

  # --check wants a yes or a no, and prints neither.
  run "$repo" git-memory-resolve.sh --check T:007/03
  expect_status 0 "resolver: --check exits 0 on an address that resolves"
  expect_empty "$RUN_BOTH" "resolver: --check prints nothing at all"
  run "$repo" git-memory-resolve.sh --check T:007/99
  expect_status 1 "resolver: --check exits 1 on an address that does not"
  expect_empty "$RUN_BOTH" "resolver: --check stays silent about the reason"
}

# --- 8. the graph --------------------------------------------------------------

test_graph() {
  local repo empty count

  repo=$(new_repo)
  make_v2_repo "$repo"

  run "$repo" git-memory-graph.sh --help
  expect_status 0 "graph: --help exits 0"
  expect_has "$RUN_OUT" "usage: git-memory-graph.sh" "graph: --help prints a usage block"

  # ndjson, the default format: one object per node, and the node set is the
  # resolver's — one feature, two tickets, one spike.
  run "$repo" git-memory-graph.sh
  expect_status 0 "graph: the default format exits 0"
  count=$(printf '%s\n' "$RUN_OUT" | grep -c '^{')
  expect_equal "$count" "4" "graph: a feature with two tickets and a spike is four nodes"
  expect_has "$RUN_OUT" '"id":"T:007/03"' "graph: ndjson carries the ticket address"
  expect_has "$RUN_OUT" '"blocked_by":["T:007/01"]' "graph: ndjson carries the blocked-by edge as an array"
  expect_has "$RUN_OUT" '"stage":"build"' "graph: ndjson carries the feature's stage"
  expect_has "$RUN_OUT" '"parent":null' "graph: Parent: none reads as null, not as the string none"

  if have_python3; then
    printf '%s\n' "$RUN_OUT" | python3 -c '
import json, sys
n = 0
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    obj = json.loads(line)
    if not isinstance(obj, dict):
        raise SystemExit("line %d is not an object" % (n + 1))
    n += 1
raise SystemExit(0 if n == 4 else "parsed %d objects, wanted 4" % n)
' >"$tmproot/py.out" 2>&1
    if [ $? -eq 0 ]; then
      pass "graph: every ndjson line parses as one JSON object"
    else
      fail "graph: every ndjson line parses as one JSON object" "valid JSON, one object per line" "$(cat "$tmproot/py.out")"
    fi
  else
    skip "graph: every ndjson line parses as one JSON object" "python3 is not installed"
  fi

  run "$repo" git-memory-graph.sh --format md
  expect_status 0 "graph: --format md exits 0"
  expect_has "$RUN_OUT" "# Work graph" "graph: md opens with a title"
  expect_has "$RUN_OUT" "**F:007-auth-envelope**" "graph: md lists the feature"
  expect_has "$RUN_OUT" "blocked by T:007/01" "graph: md spells out the blocker the indentation cannot show"
  expect_line "$RUN_OUT" "1 feature, 2 tickets, 1 spike" "graph: md ends with the count"

  run "$repo" git-memory-graph.sh --format dot
  expect_status 0 "graph: --format dot exits 0"
  expect_has "$RUN_OUT" "digraph work_graph {" "graph: dot opens a digraph"
  expect_has "$RUN_OUT" '"F:007-auth-envelope" -> "T:007/03" [color="#334155", style=solid]' \
    "graph: dot draws the parent edge solid"
  expect_has "$RUN_OUT" '"T:007/03" -> "T:007/01" [color="#b91c1c", style=dashed' \
    "graph: dot draws the blocked-by edge dashed"

  run "$repo" git-memory-graph.sh --format yaml
  expect_status 1 "graph: an unknown format exits 1"
  expect_has "$RUN_ERR" "expected ndjson, md or dot" "graph: it names the three formats"

  run "$repo" git-memory-graph.sh --oops
  expect_status 1 "graph: an unknown argument exits 1"

  # Rule 4 of the script layer: every script cd's to its own repository root, so
  # the working directory it was called from changes nothing.
  run_from_elsewhere "$repo" git-memory-graph.sh --format md
  expect_status 0 "graph: it runs from an unrelated working directory"
  expect_has "$RUN_OUT" "**F:007-auth-envelope**" "graph: the same graph comes out wherever it ran"

  # A scaffold installed yesterday has no work in it. That is an empty graph.
  empty=$(new_repo)
  install_scripts "$empty"
  run "$empty" git-memory-graph.sh
  expect_status 0 "graph: a repository with no specs exits 0"
  expect_empty "$RUN_OUT" "graph: an empty graph prints nothing"
  run "$empty" git-memory-graph.sh --format dot
  expect_status 0 "graph: an empty repository exits 0 in dot too"
  expect_empty "$RUN_OUT" "graph: an empty repository prints no digraph"

  # The v1 shape still projects: real statuses and stages, nulls where the header
  # lines do not exist yet.
  repo=$(new_repo)
  make_v1_repo "$repo"
  run "$repo" git-memory-graph.sh
  expect_status 0 "graph: a v1 repository exits 0"
  expect_has "$RUN_OUT" '"type":null' "graph: a v1 node with no Type: line reads as null"
  expect_has "$RUN_OUT" '"status":"active"' "graph: a v1 spec still carries its status"
}

# --- 9. packets ----------------------------------------------------------------
# The profile matrix in docs/method/packet-profiles.md is the specification; this
# table is the test's own copy of it, written from the doc rather than from the
# script, so the two disagreeing is a failure rather than a coincidence.

profile_included() { # stage
  case "$1" in
    research)   printf 'Route, Objective, Memory\n' ;;
    spec)       printf 'Route, Objective, Contract (draft), Memory\n' ;;
    approval)   printf 'Route, Objective, Contract, Memory\n' ;;
    plan)       printf 'Route, Objective, Contract, Slice\n' ;;
    build)      printf 'Route, Contract, Slice\n' ;;
    checks)     printf 'Route, Contract, Slice, Evidence\n' ;;
    review)     printf 'Route, Contract, Memory, Slice, Evidence\n' ;;
    rework)     printf 'Route, Contract, Slice, Evidence\n' ;;
    acceptance) printf 'Route, Objective, Contract, Evidence\n' ;;
    memory)     printf 'Route, Memory, Evidence\n' ;;
  esac
}

profile_omitted() { # stage
  case "$1" in
    research)   printf 'Contract, Slice, Evidence\n' ;;
    spec)       printf 'Slice, Evidence\n' ;;
    approval)   printf 'Slice, Evidence\n' ;;
    plan)       printf 'Memory, Evidence\n' ;;
    build)      printf 'Objective, Memory, Evidence\n' ;;
    checks)     printf 'Objective, Memory\n' ;;
    review)     printf 'Objective\n' ;;
    rework)     printf 'Objective, Memory\n' ;;
    acceptance) printf 'Memory, Slice\n' ;;
    memory)     printf 'Objective, Contract, Slice\n' ;;
  esac
}

# "Route, Objective, Memory" as one title per line, so a caller can loop.
split_titles() { printf '%s\n' "$1" | tr ',' "$nl" | sed 's/^ *//; s/ *$//' | grep -v '^$'; }

test_packet() {
  local repo stage want title body missing out

  repo=$(new_repo)
  make_v2_repo "$repo"

  run "$repo" git-memory-packet.sh --help
  expect_status 0 "packet: --help exits 0"
  expect_has "$RUN_OUT" "usage: git-memory-packet.sh" "packet: --help prints a usage block"

  # --- the address index survives resolve_node ---
  # It is walked once and read again by the ticket-queue and Memory builders.
  # Declaring it local emptied it on return, and set -u turned every later read
  # into a stderr diagnostic the render survived: the packet stayed well-formed
  # and quietly reported an empty queue. Nothing else in the suite noticed.
  run "$repo" git-memory-packet.sh F:007-auth-envelope build
  expect_status 0 "packet: a build packet exits 0"
  expect_empty "$RUN_ERR" "packet: a build packet writes nothing to stderr"
  expect_has "$RUN_OUT" "T:007/03" "packet: the Slice layer lists the feature's tickets"

  run "$repo" git-memory-packet.sh F:007-auth-envelope review
  expect_empty "$RUN_ERR" "packet: a review packet writes nothing to stderr"
  expect_has "$RUN_OUT" "TERM:" "packet: the Memory layer carries the glossary family"

  # One assertion set per stage: the profile's layers are carried, the rest are
  # named as omitted rather than left out silently.
  for stage in research spec approval plan build checks review rework acceptance memory; do
    run "$repo" git-memory-packet.sh F:007-auth-envelope "$stage"
    out=$RUN_OUT
    expect_status 0 "packet: stage $stage exits 0"
    expect_line "$out" "- Included layers: $(profile_included "$stage")" \
      "packet: stage $stage carries the layers M:packet-$stage requires"
    expect_line "$out" "- Omitted layers: $(profile_omitted "$stage")" \
      "packet: stage $stage names the layers M:packet-$stage omits"

    missing=""
    while IFS= read -r title; do
      case "$nl$out" in
        *"$nl## $title$nl"*) ;;
        *) missing="$missing $title(no heading)" ;;
      esac
      case "$out" in
        *"$title: omitted"*) missing="$missing $title(marked omitted)" ;;
      esac
    done < <(split_titles "$(profile_included "$stage")")
    while IFS= read -r title; do
      case "$out" in
        *"$title: omitted ($stage profile)"*) ;;
        *) missing="$missing $title(not marked omitted)" ;;
      esac
    done < <(split_titles "$(profile_omitted "$stage")")
    if [ -z "$missing" ]; then
      pass "packet: stage $stage prints a section for all six layers, carried or omitted"
    else
      fail "packet: stage $stage prints a section for all six layers, carried or omitted" \
        "six sections, the omitted ones saying so" "wrong:$missing"
    fi
  done

  # The stage is a property of the feature, so omitting it reads the spec.
  run "$repo" git-memory-packet.sh T:007/03
  expect_status 0 "packet: a ticket with no stage argument exits 0"
  expect_has "$RUN_OUT" "Stage: build, read from the Stage: line of specs/007-auth-envelope/spec.md" \
    "packet: the stage comes from the spec when the command line omits it"
  expect_has "$RUN_OUT" "- Address: T:007/03" "packet: the Route layer names the node"
  expect_has "$RUN_OUT" "- Branch: (not a git repository)" \
    "packet: a fixture that is not a git repository says so rather than failing"

  # request and ci have no agent turn to assemble a packet for.
  run "$repo" git-memory-packet.sh F:007-auth-envelope ci
  expect_status 1 "packet: stage ci exits 1"
  expect_has "$RUN_ERR" "has no packet profile" "packet: it says why ci has none"
  run "$repo" git-memory-packet.sh F:007-auth-envelope request
  expect_status 1 "packet: stage request exits 1"

  run "$repo" git-memory-packet.sh F:007-auth-envelope nonsense
  expect_status 1 "packet: an unknown stage exits 1"
  expect_has "$RUN_ERR" "unknown stage 'nonsense'" "packet: it names the unknown stage"

  run "$repo" git-memory-packet.sh F:009-does-not-exist build
  expect_status 1 "packet: an unresolvable address exits 1"
  expect_has "$RUN_ERR" "does not resolve" "packet: it says the address did not resolve"

  # ADR:, TERM: and M: are references, not nodes.
  run "$repo" git-memory-packet.sh ADR:0012 build
  expect_status 1 "packet: an ADR address is not a node"
  expect_has "$RUN_ERR" "is not a node" "packet: it says an ADR is a reference, not a node"

  run "$repo" git-memory-packet.sh F:007-auth-envelope build --format toml
  expect_status 1 "packet: an unknown format exits 1"
  run "$repo" git-memory-packet.sh F:007-auth-envelope build --budget nine
  expect_status 1 "packet: a non-numeric budget exits 1"

  # json: every layer keyed by name, omission recorded rather than dropped.
  run "$repo" git-memory-packet.sh F:007-auth-envelope build --format json
  expect_status 0 "packet: --format json exits 0"
  expect_has "$RUN_OUT" '"omitted": "build profile"' "packet: json records an omitted layer as omitted"
  expect_has "$RUN_OUT" '"profile": "M:packet-build"' "packet: json names the profile address"
  if have_python3; then
    printf '%s\n' "$RUN_OUT" | python3 -c '
import json, sys
p = json.load(sys.stdin)
for want in ("address", "stage", "profile", "layers"):
    if want not in p:
        raise SystemExit("no %s key" % want)
if set(p["layers"]) != {"route", "objective", "contract", "memory", "slice", "evidence"}:
    raise SystemExit("layers are %s" % sorted(p["layers"]))
if "text" not in p["layers"]["route"]:
    raise SystemExit("the route layer carries no text")
' >"$tmproot/py.out" 2>&1
    if [ $? -eq 0 ]; then
      pass "packet: --format json parses and carries all six layers"
    else
      fail "packet: --format json parses and carries all six layers" "valid JSON, six layers" "$(cat "$tmproot/py.out")"
    fi
  else
    skip "packet: --format json parses and carries all six layers" "python3 is not installed"
  fi

  # A budget that binds shortens a layer within itself and says by how much.
  run "$repo" git-memory-packet.sh F:007-auth-envelope build
  expect_lacks "$RUN_OUT" "Truncated to fit" "packet: an uncapped packet is not truncated"
  expect_has "$RUN_OUT" "no --budget" "packet: an uncapped packet says the size is uncapped"
  run "$repo" git-memory-packet.sh F:007-auth-envelope build --budget 200
  expect_status 0 "packet: a binding --budget still exits 0"
  expect_has "$RUN_OUT" "Truncated to fit --budget 200" "packet: truncation says so, in the layer it cut"
  expect_has "$RUN_OUT" "## Route" "packet: Route survives the budget"
  expect_has "$RUN_OUT" "against --budget 200" "packet: the size line reports the budget it was measured against"
}

# --- 10. the checker -----------------------------------------------------------
# The most important test in this file is the first one: a v1-shaped repository
# exits 0 on a default run. Everything the v2 header added is behind --strict, and
# a default run that fails on a repository installed last year is a broken
# upgrade, not a caught inconsistency (docs/memory.md, and check-memory.sh's own
# header comment).

# One failing fixture: mutate a clean v2 repository, run, assert the status and the
# message. The matching passing fixture is the clean run at the top of the section,
# which asserts the ok line each of these checks prints when it holds.
case_fail() { # description, needle, mutator, extra args...
  local desc=$1 needle=$2 mut=$3
  shift 3
  local repo
  repo=$(new_repo)
  make_v2_repo "$repo"
  "$mut" "$repo" "$@"
  run "$repo" check-memory.sh
  expect_status 1 "checker: $desc exits 1"
  expect_has "$RUN_OUT" "$needle" "checker: $desc is reported with the offending value"
}

test_checker() {
  local repo out

  # --- the backward-compatibility contract ---
  repo=$(new_repo)
  make_v1_repo "$repo"
  run "$repo" check-memory.sh
  expect_status 0 "checker: a v1 repository passes a default run"
  expect_has "$RUN_OUT" "memory is consistent" "checker: a v1 repository is reported consistent"
  expect_lacks "$RUN_OUT" "FAIL" "checker: a v1 repository produces no FAIL line"

  # ...and --strict is where the v2 header becomes a requirement.
  run "$repo" check-memory.sh --strict
  expect_status 1 "checker: --strict fails the same v1 repository"
  expect_has "$RUN_OUT" "has no ID: line" "checker: --strict names the missing ID: line"
  expect_has "$RUN_OUT" "has no Type: line" "checker: --strict names the missing Type: line"

  # --- the clean v2 fixture: one passing assertion per check ---
  repo=$(new_repo)
  make_v2_repo "$repo"
  run "$repo" check-memory.sh
  expect_status 0 "checker: a v2 repository passes a default run"
  out=$RUN_OUT
  expect_line "$out" "ok    every Type: line uses a value legal for its node kind" \
    "checker: the work-type check passes on a clean repository"
  expect_line "$out" "ok    every ID: line matches the address its own path implies" \
    "checker: the ID checksum passes on a clean repository"
  expect_line "$out" "ok    delivery stage lives only in specs/<NN>-<slug>/spec.md" \
    "checker: the one-home stage check passes on a clean repository"
  expect_line "$out" "ok    every Parent:, Children:, Blocked by: and Refs: address resolves" \
    "checker: every node address resolves on a clean repository"
  expect_line "$out" "ok    every M: address referenced is declared exactly once under docs/method/" \
    "checker: the method-ref check passes on a clean repository"
  expect_line "$out" "ok    no root context.md (human direction lives in active-context.md)" \
    "checker: the context.md rename check passes on a clean repository"
  expect_line "$out" "ok    ticket numbers are unique within each feature" \
    "checker: ticket numbering passes on a clean repository"
  expect_line "$out" "ok    specs/README.md table matches spec.md statuses" \
    "checker: the generated specs table passes on a clean repository"

  run "$repo" check-memory.sh --strict
  expect_status 0 "checker: a v2 repository passes --strict"
  out=$RUN_OUT
  expect_line "$out" "ok    --strict: every node file carries ID:, Type: and Parent:" \
    "checker: --strict node headers pass on a clean repository"
  expect_line "$out" "ok    --strict: every spec at ci, acceptance or memory has a review artifact" \
    "checker: --strict review artifacts pass on a clean repository"
  expect_line "$out" "ok    --strict: every implemented spec at stage memory names what shipped it" \
    "checker: --strict implemented-in passes on a clean repository"

  run "$repo" check-memory.sh --help
  expect_status 0 "checker: --help exits 0"
  expect_has "$RUN_OUT" "usage: check-memory.sh" "checker: --help prints a usage block"

  run "$repo" check-memory.sh --stricked
  expect_status 2 "checker: an unknown flag exits 2, not 1"
  expect_has "$RUN_ERR" "unknown option --stricked" "checker: it names the flag it did not understand"

  # --- one failing fixture per check ---
  case_fail "an unknown Type: value" "unknown work type 'grilling'" mut_unknown_type
  case_fail "a Type: illegal for the node kind" "is not legal on a spec" mut_illegal_type
  case_fail "an ID: that disagrees with its path" "but its path implies T:007/03" mut_id_mismatch
  case_fail "a Stage: line on a ticket" "delivery stage on a ticket" mut_stage_on_ticket
  case_fail "a Blocked by: address that resolves to nothing" "does not resolve" mut_dangling_address
  case_fail "an M: address nothing declares" "M:ticket-nonexistent is referenced" mut_undeclared_method
  case_fail "an M: address declared twice" "is declared twice" mut_duplicate_method
  case_fail "a root context.md" "git mv context.md active-context.md" mut_root_context
  case_fail "two tickets numbered 03" "duplicate ticket number 03" mut_duplicate_ticket_number
  case_fail "a .scratch folder with no canonical spec" "ticket folder without canonical spec" mut_scratch_orphan
  case_fail "two tickets blocking each other" "Blocked by: cycle" mut_blocking_cycle

  # A blocking chain that is deep but acyclic must not be mistaken for a cycle.
  repo=$(new_repo)
  make_v2_repo "$repo"
  write "$repo/.scratch/auth-envelope/issues/03-envelope-signing.md" <<'EOF'
# Sign the envelope

ID: T:007/03
Type: implementation
Status: needs-triage
Parent: F:007-auth-envelope
Blocked by: T:007/01
EOF
  run "$repo" check-memory.sh
  expect_status 0 "checker: an acyclic blocking chain is not reported as a cycle"
  expect_has "$RUN_OUT" "no ticket waits on itself" "checker: it says the blocking edges are acyclic"

  # --- --fix regenerates the specs table ---
  repo=$(new_repo)
  make_v2_repo "$repo"
  mut_stale_specs_table "$repo"
  run "$repo" check-memory.sh
  expect_status 1 "checker: a stale specs table fails a default run"
  expect_has "$RUN_OUT" "specs/README.md table is stale" "checker: it says the table is stale"
  run "$repo" check-memory.sh --fix
  expect_status 0 "checker: --fix exits 0"
  expect_has "$RUN_OUT" "specs/README.md table regenerated" "checker: --fix says what it regenerated"
  expect_has "$(cat "$repo/specs/README.md")" '| [`007-auth-envelope`](007-auth-envelope/) | build | active |' \
    "checker: --fix wrote the row the spec.md files imply"
  run "$repo" check-memory.sh
  expect_status 0 "checker: the repository is clean after --fix"
  expect_lacks "$(cat "$repo/specs/README.md")" "| plan | draft |" "checker: --fix removed the stale row"

  # --- --strict: a spec past review has a review artifact ---
  repo=$(new_repo)
  make_v2_repo "$repo"
  set_stage "$repo" ci active
  run "$repo" check-memory.sh
  expect_status 0 "checker: a spec at ci with no review artifact passes a default run"
  run "$repo" check-memory.sh --strict
  expect_status 1 "checker: --strict fails a spec at ci with no review artifact"
  expect_has "$RUN_OUT" "with no review artifact" "checker: it names the missing evidence"
  add_review_artifact "$repo"
  run "$repo" check-memory.sh --strict
  expect_status 0 "checker: --strict passes once the review artifact exists"

  # --- --strict: an implemented spec names what shipped it ---
  repo=$(new_repo)
  make_v2_repo "$repo"
  set_stage "$repo" memory implemented
  add_review_artifact "$repo"
  run "$repo" check-memory.sh
  expect_status 0 "checker: an implemented spec with no Implemented in: line passes a default run"
  run "$repo" check-memory.sh --strict
  expect_status 1 "checker: --strict fails an implemented spec with no Implemented in: line"
  expect_has "$RUN_OUT" "no 'Implemented in:' line" "checker: it names the missing line"
  set_field "$repo" "$spec_md" "Implemented in" "PR #42"
  run "$repo" check-memory.sh --strict
  expect_status 0 "checker: --strict passes once the spec names what shipped it"

  # --- the rest of the v1 checks still bite ---
  repo=$(new_repo)
  make_v2_repo "$repo"
  rm -f "$repo/specs/007-auth-envelope/acceptance.md"
  run "$repo" check-memory.sh
  expect_status 1 "checker: an active spec missing acceptance.md fails"
  expect_has "$RUN_OUT" "is missing acceptance.md" "checker: it names the missing file"
}

# --- 11. the shared header reader ----------------------------------------------
# One reader, in scripts/lib/git-memory-lib.sh. Four separate implementations
# existed before and only one skipped fenced blocks, so every case below was a
# live defect in at least three of the four consumers.

test_headers() {
  local repo out

  # --- a fenced example header must not be read as the real one ---
  repo=$(new_repo)
  make_v2_repo "$repo"
  write "$repo/specs/007-auth-envelope/spec.md" <<'EOF'
# Signed auth envelope

The header of a spec looks like this:

```
ID: F:999-worked-example
Type: bug
Status: draft
Stage: request
```

ID: F:007-auth-envelope
Type: feature
Status: active
Stage: build
Parent: none

## Outcome

A caller can prove an event came from the service that claims to have sent it.
EOF
  sync_specs_table "$repo"
  run "$repo" git-memory-graph.sh --format ndjson
  expect_has "$RUN_OUT" '"status":"active"' "headers: a fenced example does not fool the graph's status"
  expect_has "$RUN_OUT" '"stage":"build"' "headers: a fenced example does not fool the graph's stage"
  expect_lacks "$RUN_OUT" 'F:999-worked-example' "headers: the fenced example's ID never reaches the graph"
  run "$repo" check-memory.sh
  expect_status 0 "headers: a spec carrying a fenced example header still passes"

  # --- a CRLF checkout reads identically to an LF one ---
  repo=$(new_repo)
  make_v2_repo "$repo"
  find "$repo/docs" "$repo/specs" "$repo/.scratch" -name '*.md' -exec sed -e 's/$/\r/' -i.bak {} \; 2>/dev/null
  find "$repo" -name '*.md.bak' -exec rm -f {} \; 2>/dev/null
  run "$repo" git-memory-resolve.sh --all
  expect_status 0 "headers: --all still exits 0 on a CRLF checkout"
  expect_has "$RUN_OUT" "M:gate-approval" "headers: the M: family survives a CRLF checkout"
  run "$repo" git-memory-resolve.sh M:gate-approval
  expect_status 0 "headers: an M: address still resolves on a CRLF checkout"
  run "$repo" git-memory-graph.sh --format ndjson
  expect_has "$RUN_OUT" '"type":"feature"' "headers: a header value carries no trailing CR into the graph"
  expect_lacks "$RUN_OUT" '\r' "headers: no carriage return reaches the ndjson projection"

  # --- the legacy bold form reads the same as the plain one ---
  repo=$(new_repo)
  make_v2_repo "$repo"
  write "$repo/.scratch/auth-envelope/issues/03-envelope-signing.md" <<'EOF'
# Sign the envelope

ID: T:007/03
Type: implementation
**Status:** ready-for-agent
Parent: F:007-auth-envelope
EOF
  run "$repo" git-memory-graph.sh --format ndjson
  expect_has "$RUN_OUT" '"status":"ready-for-agent"' "headers: the bold **Status:** form reaches the graph"
  run "$repo" check-memory.sh
  expect_status 0 "headers: a ticket using the bold form still passes the checker"

  # --- a title is a level-one heading, not any heading and not a fence ---
  repo=$(new_repo)
  make_v2_repo "$repo"
  write "$repo/specs/007-auth-envelope/spec.md" <<'EOF'
```sh
# not a title, a shell comment inside a fence
```

### Not a title either, it is a level-three heading

# Signed auth envelope

ID: F:007-auth-envelope
Type: feature
Status: active
Stage: build
Parent: none

## Outcome

A caller can prove an event came from the service that claims to have sent it.
EOF
  sync_specs_table "$repo"
  # gm_title is asserted against directly: the md projection does not print a
  # title, so going through a consumer would prove nothing either way.
  out=$(. "$scripts_dir/lib/git-memory-lib.sh" && gm_title "$repo/specs/007-auth-envelope/spec.md")
  expect_equal "$out" "Signed auth envelope" "headers: the title is the level-one heading"
  expect_lacks "$out" "shell comment inside a fence" "headers: a fenced comment is never a title"
  expect_lacks "$out" "level-three heading" "headers: a sub-heading is never a title"

  # --- the reported size is the size of the packet you are holding ---
  # The size line is inside what it measures, so it was reporting the length of
  # a render still carrying the "(measuring)" placeholder — and --budget was
  # enforced against that under-count.
  repo=$(new_repo)
  make_v2_repo "$repo"
  run "$repo" git-memory-packet.sh F:007-auth-envelope build
  expect_status 0 "headers: a build packet prints"
  local claimed actual
  claimed=$(printf '%s' "$RUN_OUT" | sed -n 's/^- Size: \([0-9][0-9]*\) bytes.*/\1/p' | head -1)
  actual=$(printf '%s\n' "$RUN_OUT" | wc -c | tr -d ' ')
  expect_equal "$claimed" "$actual" "headers: the packet's reported size equals its real size"

  # --- a stable-layer file whose name contains a space is still checked ---
  repo=$(new_repo)
  make_v2_repo "$repo"
  mkdir -p "$repo/docs/domain"
  write "$repo/docs/domain/event envelope.md" <<'EOF'
# Event envelope

A stable layer must not link down into [a spec](../../specs/007-auth-envelope/).
EOF
  run "$repo" check-memory.sh
  expect_status 1 "headers: a doc whose filename contains a space is not skipped"
  expect_has "$RUN_OUT" "stable layer links into volatile layer" \
    "headers: the space-named file is the one reported"
}

# --- 12. dispatch ---------------------------------------------------------------

for section in $SECTIONS; do
  case "$section" in
    resolver) test_resolver ;;
    graph)    test_graph ;;
    packet)   test_packet ;;
    checker)  test_checker ;;
    headers)  test_headers ;;
  esac
done

printf '1..%d\n' "$tests"
if [ "$failures" -gt 0 ]; then
  printf '# %d of %d assertions failed (%d skipped)\n' "$failures" "$tests" "$skips"
  exit 1
fi
printf '# %d assertions passed (%d skipped)\n' "$tests" "$skips"
