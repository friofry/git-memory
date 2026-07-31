#!/usr/bin/env bash
#
# Consistency checks for the layered project memory (see docs/memory.md).
#
#   scripts/check-memory.sh           report violations, non-zero exit on failure
#   scripts/check-memory.sh --fix     regenerate derived blocks, then report
#   scripts/check-memory.sh --strict  also require the v2 node header and the
#                                     late-stage evidence a gate demands
#   scripts/check-memory.sh --help    usage, exit 0
#
# --fix and --strict compose in either order. An unknown flag exits 2 without
# running a check, so a typo never reads as a clean repository.
#
# The default run is the backward-compatibility contract: a repository written
# before ID:/Type:/Parent: existed carries neither, and must still exit 0. Every
# structural requirement added by that header is behind --strict; everything the
# default run reports is a correctness failure that was always a failure.
#
set -uo pipefail
shopt -s nullglob

cd "$(dirname "$0")/.." || exit 1

# The one header reader and the one hashing shim. Sourcing rather than forking
# keeps each check cheap: the old inline readers cost four processes per field.
if [ -r scripts/lib/git-memory-lib.sh ]; then
  . scripts/lib/git-memory-lib.sh
else
  printf '%s: missing scripts/lib/git-memory-lib.sh\n' "$(basename "$0")" >&2
  exit 2
fi

self=$(basename "$0")
nl=$'\n'

# The only address parser in the system (docs/method/addressing.md, "One
# resolver"). Absent in a repository installed before v2, which is why every
# caller checks for it rather than assuming it.
resolver=scripts/git-memory-resolve.sh

usage() {
  cat <<'EOF'
usage: check-memory.sh [--fix] [--strict]
       check-memory.sh --help

Check the layered project memory for the inconsistencies that no single file can
see on its own: broken links, a status or a stage with two homes, a stale
generated table, an address that resolves to nothing. The rules live in
docs/memory.md and docs/method/; this script only enforces them.

  --fix      regenerate the derived blocks this script owns — the specs table in
             specs/README.md and .agents/skills.sha256 — then report. It writes
             nothing else, and never touches a file a human authored.
  --strict   additionally require what the v2 node header and the late gates
             demand: ID:, Type: and Parent: on every node file, a review artifact
             for a spec at ci or later, and an Implemented in: line on a spec
             that reached memory as implemented.
  --help     print this and exit 0.

Exit status: 0 clean, 1 one or more consistency failures, 2 a usage error.

A default run stays green on a repository that predates the node header. Pass
--strict in CI once the header has been backfilled — .github/workflows/memory.yml
ships with both runs and the strict one marked as the gate.
EOF
}

FIX=0
STRICT=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --fix)     FIX=1 ;;
    --strict)  STRICT=1 ;;
    -h|--help) usage; exit 0 ;;
    *)
      printf '%s: unknown option %s\n\n' "$self" "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

failures=0
err() {
  printf 'FAIL  %s\n' "$1"
  failures=$((failures + 1))
}
ok() { printf 'ok    %s\n' "$1"; }

# .agents/skills is vendored from upstream (see skills-lock.json) and is not
# checked here: its links are upstream's problem and change on every update.
roots=""
for r in README.md AGENTS.md CONTEXT.md docs specs rules .cursor/skills templates spikes .scratch; do
  [ -e "$r" ] && roots="$roots $r"
done

doc_files() {
  # An empty $roots would leave "find -name '*.md'", which GNU find silently
  # treats as "find ." while BSD find rejects outright — the same repository
  # then passes on Linux and fails on macOS. Nothing to search is not an error.
  [ -n "$roots" ] || return 0
  # shellcheck disable=SC2086
  find $roots -name '*.md' -not -path '*/node_modules/*' 2>/dev/null | sort
}

# Prose only: a fenced block may legitimately show a line form that a one-home
# check would otherwise read as a real status. An unclosed fence would hide the
# rest of the file from those checks, so check_fences fails on one first.
without_fences() {
  awk '/^```/ { fenced = !fenced; next } !fenced' "$1"
}

check_fences() {
  local bad=0 f count
  while IFS= read -r f; do
    count=$(grep -c '^```' "$f" 2>/dev/null)
    if [ $((count % 2)) -ne 0 ]; then
      err "unbalanced code fence in $f (it would hide the rest of the file from the one-home checks)"
      bad=$((bad + 1))
    fi
  done < <(doc_files)
  [ "$bad" -eq 0 ] && ok "every code fence is closed"
}

files_with_line() {
  local pattern=$1 f
  while IFS= read -r f; do
    without_fences "$f" | grep -q "$pattern" && printf '%s\n' "$f"
  done < <(doc_files)
}

# --- 1. relative links resolve -------------------------------------------------

check_links() {
  local broken=0 f target dir raw
  while IFS= read -r f; do
    dir=$(dirname "$f")
    while IFS= read -r raw; do
      raw=${raw#](}
      raw=${raw%)}
      raw=${raw%% *}
      case "$raw" in
        http://*|https://*|mailto:*|"#"*|"") continue ;;
        /*) continue ;;
      esac
      target=${raw%%#*}
      [ -z "$target" ] && continue
      if [ ! -e "$dir/$target" ]; then
        err "broken link: $f -> $raw"
        broken=$((broken + 1))
      fi
    done < <(grep -oE '\]\([^)]+\)' "$f" 2>/dev/null)
  done < <(doc_files)
  [ "$broken" -eq 0 ] && ok "all relative doc links resolve"
}

# --- 2. feature status has exactly one home ------------------------------------

check_status_home() {
  local bad=0 f value
  while IFS= read -r f; do
    f=${f#./}
    case "$f" in
      specs/[0-9][0-9][0-9]-*/spec.md)
        value=$(sed -n 's/^Status: *//p' "$f" | head -1)
        case "$value" in
          draft|active|implemented) ;;
          *)
            err "unknown status '$value' in $f (expected draft|active|implemented)"
            bad=$((bad + 1))
            ;;
        esac
        ;;
      .scratch/*/issues/*.md) ;; # triage labels on tickets are a separate vocabulary
      templates/*.md) ;;         # placeholder text, not a real status
      *)
        err "feature status outside its home: $f (status belongs in specs/<NN>-<slug>/spec.md)"
        bad=$((bad + 1))
        ;;
    esac
  done < <(files_with_line '^Status:')
  [ "$bad" -eq 0 ] && ok "feature status lives only in specs/<NN>-<slug>/spec.md"
}

# --- 2b. delivery stage has one home and a known value -------------------------
# Vocabulary and stage/status mapping: docs/agents/delivery-workflow.md

# The twelve stages live in scripts/lib/git-memory-lib.sh, once.
stage_is_known() { gm_stage_is_known "$1"; }

check_stage_home() {
  local bad=0 f value
  while IFS= read -r f; do
    f=${f#./}
    case "$f" in
      specs/[0-9][0-9][0-9]-*/spec.md)
        value=$(sed -n 's/^Stage: *//p' "$f" | head -1)
        if ! stage_is_known "$value"; then
          err "unknown stage '$value' in $f (see docs/agents/delivery-workflow.md)"
          bad=$((bad + 1))
        fi
        ;;
      templates/*.md) ;; # placeholder text, not a real stage
      # A ticket and a spike are node files, so they are the two places a Stage:
      # line looks plausible and is worst: it records how far one slice has got in
      # a vocabulary that describes the whole feature, and then disagrees with
      # spec.md. Named separately from the fallback so the message can say which
      # node kind is at fault — docs/agents/issue-tracker.md.
      .scratch/*/issues/*.md)
        err "delivery stage on a ticket: $f (a ticket carries no Stage: line; stage belongs in specs/<NN>-<slug>/spec.md)"
        bad=$((bad + 1))
        ;;
      spikes/*/*/README.md)
        err "delivery stage on a spike: $f (a spike carries no Stage: line; stage belongs in specs/<NN>-<slug>/spec.md)"
        bad=$((bad + 1))
        ;;
      *)
        err "delivery stage outside its home: $f (stage belongs in specs/<NN>-<slug>/spec.md)"
        bad=$((bad + 1))
        ;;
    esac
  done < <(files_with_line '^Stage:')
  [ "$bad" -eq 0 ] && ok "delivery stage lives only in specs/<NN>-<slug>/spec.md"
}

check_stage_status() {
  local bad=0 d status stage allowed
  for d in specs/[0-9][0-9][0-9]-*/; do
    [ -f "$d/spec.md" ] || continue
    status=$(sed -n 's/^Status: *//p' "$d/spec.md" | head -1)
    stage=$(sed -n 's/^Stage: *//p' "$d/spec.md" | head -1)
    if [ -z "$stage" ]; then
      err "missing Stage: line in ${d%/}/spec.md (see docs/agents/delivery-workflow.md)"
      bad=$((bad + 1))
      continue
    fi
    case "$stage" in
      request|research|spec|approval) allowed="draft" ;;
      plan|build|checks|review|rework|ci|acceptance) allowed="active" ;;
      memory) allowed="active implemented" ;;
      *) continue ;; # unknown value already reported by check_stage_home
    esac
    case " $allowed " in
      *" $status "*) ;;
      *)
        err "stage '$stage' needs status $allowed, found '$status' in ${d%/}/spec.md"
        bad=$((bad + 1))
        ;;
    esac
  done
  [ "$bad" -eq 0 ] && ok "every spec carries a stage that agrees with its status"
}

# --- 3. generated specs table matches the spec.md files ------------------------

generate_specs_table() {
  printf '| Spec | Stage | Status |\n|------|-------|--------|\n'
  local d slug status stage
  for d in specs/[0-9][0-9][0-9]-*/; do
    [ -f "$d/spec.md" ] || continue
    slug=$(basename "$d")
    status=$(sed -n 's/^Status: *//p' "$d/spec.md" | head -1)
    stage=$(sed -n 's/^Stage: *//p' "$d/spec.md" | head -1)
    printf '| [`%s`](%s/) | %s | %s |\n' "$slug" "$slug" "$stage" "$status"
  done
}

check_specs_table() {
  local expected current
  expected=$(generate_specs_table)
  current=$(awk '/BEGIN generated:specs-table/{f=1;next} /END generated:specs-table/{f=0} f' specs/README.md)
  if [ "$expected" = "$current" ]; then
    ok "specs/README.md table matches spec.md statuses"
    return
  fi
  if [ "$FIX" -eq 1 ]; then
    awk -v tbl="$expected" '
      /BEGIN generated:specs-table/ { print; print tbl; skip = 1; next }
      /END generated:specs-table/   { skip = 0 }
      !skip                         { print }
    ' specs/README.md > specs/README.md.tmp && mv specs/README.md.tmp specs/README.md
    ok "specs/README.md table regenerated"
  else
    err "specs/README.md table is stale (run scripts/check-memory.sh --fix)"
  fi
}

# --- 4. required files while a spec is draft/active ----------------------------

check_spec_files() {
  local bad=0 d status required
  for d in specs/[0-9][0-9][0-9]-*/; do
    [ -f "$d/spec.md" ] || { err "missing spec.md in $d"; bad=$((bad + 1)); continue; }
    status=$(sed -n 's/^Status: *//p' "$d/spec.md" | head -1)
    case "$status" in
      draft|active)
        for required in design.md acceptance.md decisions.md; do
          if [ ! -f "$d/$required" ]; then
            err "$status spec $d is missing $required"
            bad=$((bad + 1))
          fi
        done
        ;;
    esac
  done
  [ "$bad" -eq 0 ] && ok "draft/active specs carry design, acceptance and decisions"
}

# --- 5. stable layers must not link down into volatile ones --------------------

check_link_direction() {
  local bad=0 f
  # Read the find output line by line rather than word-splitting an unquoted
  # command substitution: a stable-layer file whose name contains a space was
  # split into non-existent paths and skipped in silence by the [ -f ] guard.
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    if grep -qE '\]\([^)]*(specs/|\.scratch/)' "$f"; then
      err "stable layer links into volatile layer: $f (see docs/memory.md rule 2)"
      bad=$((bad + 1))
    fi
  done < <({ printf 'CONTEXT.md\n'; find docs/domain docs/adr -name '*.md' 2>/dev/null | sort; })
  [ "$bad" -eq 0 ] && ok "CONTEXT.md, docs/domain and docs/adr do not link into specs/ or .scratch/"
}

# --- 6. every .scratch feature folder has a canonical spec ---------------------

# --- 5b. the two harness skill directories hold the same skills ----------------
# Owner: CLAUDE.md. Claude Code reads .claude/skills/, every other harness reads
# .cursor/skills/. The seed ships the first as a symbolic link to the second so
# there is one home; a checkout that could not restore the link leaves a copy,
# and a copy is exactly what drifts.

check_harness_skills() {
  local a b only
  [ -e .claude/skills ] || { ok ".claude/skills absent (Claude Code not set up here)"; return; }
  [ -d .cursor/skills ] || { err ".claude/skills exists but .cursor/skills does not: the link has no target"; return; }
  if [ -L .claude/skills ]; then
    ok ".claude/skills is a link to .cursor/skills (one home for the repo skills)"
    return
  fi
  a=$(cd .cursor/skills && printf '%s\n' */ 2>/dev/null | sort)
  b=$(cd .claude/skills && printf '%s\n' */ 2>/dev/null | sort)
  if [ "$a" = "$b" ]; then
    ok ".claude/skills is a copy of .cursor/skills and holds the same skills"
    return
  fi
  only=$(printf '%s\n%s\n' "$a" "$b" | sort | uniq -u | tr '\n' ' ')
  err ".claude/skills and .cursor/skills disagree (differing: ${only% }): re-link with ln -sfn ../.cursor/skills .claude/skills"
}

check_scratch_orphans() {
  local bad=0 d slug match
  [ -d .scratch ] || { ok ".scratch/ absent (nothing to check)"; return; }
  for d in .scratch/*/; do
    [ -d "$d" ] || continue
    slug=$(basename "$d")
    # A glob collected into a variable, not `ls -d <glob>`: shopt -s nullglob
    # erases a non-matching glob, so `ls -d` ran with no arguments at all,
    # listed the current directory and exited 0. The check could never fail.
    match=$(printf '%s' specs/[0-9][0-9][0-9]-"$slug"/)
    if [ -z "$match" ] || [ ! -d "$match" ]; then
      err "ticket folder without canonical spec: $d (expected specs/<NN>-$slug/)"
      bad=$((bad + 1))
    fi
  done
  [ "$bad" -eq 0 ] && ok "every .scratch feature folder maps to a spec"
}

# --- 7. vendored skills are locked and unmodified ------------------------------
# Provenance and the no-local-edits rule: docs/agents/vendored-skills.md

lock_skill_names() {
  sed -n 's/^[[:space:]]*"\([^"]*\)": {$/\1/p' skills-lock.json | grep -v '^skills$'
}

generate_skills_manifest() {
  # No xargs -r (not POSIX; BSD xargs runs the command once with no arguments
  # instead of skipping it) and no bare sha256sum (macOS ships shasum only).
  # An empty file list must produce empty output, not a hash of stdin.
  local p h
  find .agents/skills -type f 2>/dev/null | sort | while IFS= read -r p; do
    [ -n "$p" ] || continue
    h=$(gm_sha256 < "$p" | awk '{ print $1; exit }')
    [ -n "$h" ] || return 1
    printf '%s  %s\n' "$h" "$p"
  done
}

check_vendored_skills() {
  local bad=0 d name expected current
  [ -d .agents/skills ] || { ok ".agents/skills absent (nothing to check)"; return; }
  if [ ! -f skills-lock.json ]; then
    err "missing skills-lock.json while .agents/skills exists"
    return
  fi

  for d in .agents/skills/*/; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    if [ ! -f "$d/SKILL.md" ]; then
      err "vendored skill without SKILL.md: $d"
      bad=$((bad + 1))
      continue
    fi
    if ! lock_skill_names | grep -qx "$name"; then
      err "vendored skill missing from skills-lock.json: $name (add it with npx skills, do not hand-write the hash)"
      bad=$((bad + 1))
    fi
  done
  while IFS= read -r name; do
    if [ ! -f ".agents/skills/$name/SKILL.md" ]; then
      err "skills-lock.json lists '$name' but .agents/skills/$name/SKILL.md is absent"
      bad=$((bad + 1))
    fi
  done < <(lock_skill_names)

  # skills-lock.json records the CLI's own hash, which we cannot recompute, so
  # the bytes we vendored are pinned here instead — an edit to a vendored file
  # has to show up as a deliberate manifest change in the diff.
  expected=$(generate_skills_manifest)
  current=$(cat .agents/skills.sha256 2>/dev/null)
  if [ "$expected" = "$current" ]; then
    [ "$bad" -eq 0 ] && ok "vendored skills are locked and match .agents/skills.sha256"
    return
  fi
  if [ "$FIX" -eq 1 ]; then
    # Never write an empty manifest. Without a hashing tool the generator
    # returns nothing, and --fix would overwrite the tamper baseline with it —
    # turning a missing dependency into silent, permanent loss of the thing the
    # check exists to compare against.
    if ! gm_have_sha256; then
      err "no sha256 tool available (sha256sum, shasum or openssl); refusing to overwrite .agents/skills.sha256 with an empty manifest"
      return
    fi
    if [ -z "$expected" ] && [ -n "$(find .agents/skills -type f 2>/dev/null)" ]; then
      err "skills manifest came back empty while .agents/skills holds files; refusing to overwrite .agents/skills.sha256"
      return
    fi
    printf '%s\n' "$expected" > .agents/skills.sha256
    ok ".agents/skills.sha256 regenerated"
  else
    err "vendored skill bytes differ from .agents/skills.sha256 (upstream copies carry no local edits; after npx skills add/update run scripts/check-memory.sh --fix)"
  fi
}

# --- 8. ticket labels use the documented vocabulary ----------------------------
# Vocabulary: docs/agents/triage-labels.md

label_is_known() {
  case "$1" in
    needs-triage|needs-info|ready-for-agent|ready-for-human|wontfix|claimed|resolved|done) return 0 ;;
    *) return 1 ;;
  esac
}

check_ticket_labels() {
  local bad=0 f value
  [ -d .scratch ] || { ok ".scratch/ absent (no ticket labels to check)"; return; }
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    value=$(sed -n -e 's/^\*\*Status:\*\* *//p' -e 's/^Status: *//p' "$f" | head -1)
    [ -z "$value" ] && continue
    if ! label_is_known "$value"; then
      err "unknown ticket label '$value' in $f (see docs/agents/triage-labels.md)"
      bad=$((bad + 1))
    fi
  done < <(find .scratch -path '*/issues/*.md' 2>/dev/null | sort)
  [ "$bad" -eq 0 ] && ok "ticket labels come from docs/agents/triage-labels.md"
}

# --- 9. node files, and the address each path implies --------------------------
# A node file is a spec, a ticket or a spike README — docs/memory.md, "Node
# headers". These three helpers are the only place this script decides what a node
# is and what its path means; every check below reads them rather than globbing
# again, so adding a node kind is one edit.
#
# The address a path implies is derived here and nowhere else, and only for the
# ID: checksum in check_node_ids. Resolution in the other direction — address to
# path — is the resolver's job and is never re-implemented here
# (docs/method/addressing.md, "One resolver").

# "<kind><TAB><path>". Tickets are matched on the numbered form only: a file in
# issues/ without a leading number carries no T: address, so it is not a node.
node_files() {
  local f
  for f in specs/[0-9][0-9][0-9]-*/spec.md; do
    printf 'spec\t%s\n' "$f"
  done
  for f in .scratch/*/issues/[0-9]*-*.md; do
    printf 'ticket\t%s\n' "$f"
  done
  for f in spikes/*/*/README.md; do
    printf 'spike\t%s\n' "$f"
  done
}

# A ticket and spike address carries the feature's number, not its slug
# (docs/method/addressing.md, rule 2), so turning one of their paths back into an
# address costs this lookup. Empty exit 1 when the slug names no feature — that is
# check_scratch_orphans' failure to report, not this one's.
feature_number() {
  local slug=$1 d num="" n=0
  for d in specs/[0-9][0-9][0-9]-"$slug"/; do
    num=${d#specs/}
    num=${num%%-*}
    n=$((n + 1))
  done
  [ "$n" -eq 1 ] || return 1
  printf '%s\n' "$num"
}

implied_address() {
  local kind=$1 f=$2 slug num rest
  case "$kind" in
    spec)
      slug=${f#specs/}
      printf 'F:%s\n' "${slug%/spec.md}"
      ;;
    ticket)
      slug=${f#.scratch/}
      slug=${slug%%/*}
      num=$(feature_number "$slug") || return 1
      rest=${f##*/}
      printf 'T:%s/%s\n' "$num" "${rest%%-*}"
      ;;
    spike)
      slug=${f#spikes/}
      slug=${slug%%/*}
      num=$(feature_number "$slug") || return 1
      rest=${f#spikes/$slug/}
      printf 'S:%s/%s\n' "$num" "${rest%/README.md}"
      ;;
  esac
}

# One header field, prose only, first occurrence. Plain "Key: value" lines are
# load-bearing — docs/memory.md forbids YAML front matter precisely so this stays
# a sed expression — and the key may hold a space ("Blocked by", "Implemented in").
header_value() {
  gm_header "$2" "$1"
}

# --- 10. the root context.md rename --------------------------------------------
# Owner: docs/memory.md, "active-context.md vs CONTEXT.md".

check_root_context() {
  local f
  # The glob, not [ -e context.md ]: on a case-insensitive filesystem — the macOS
  # and Windows defaults, which is the whole reason for the rename — that test
  # matches CONTEXT.md and would fail every repository. A glob returns names as
  # the directory stores them, so the comparison below is genuinely case-sensitive.
  for f in *.md; do
    if [ "$f" = "context.md" ]; then
      err "root context.md still exists and collides with CONTEXT.md on a case-insensitive filesystem (see docs/memory.md): git mv context.md active-context.md"
      return
    fi
  done
  ok "no root context.md (human direction lives in active-context.md)"
}

# --- 11. every M: address is declared exactly once ------------------------------
# Owner: docs/method/README.md, "How a method ref is declared".

# "<address><TAB><path#anchor>", one line per declaration, duplicates included —
# which is what makes the duplicate report below possible. The resolver reads the
# headings; this script does not.
method_declarations() {
  bash "$resolver" --all 2>/dev/null | grep '^M:'
}

# Every M: address mentioned in the repository's prose. The family wildcards the
# method docs write — M:gate-*, M:packet-<stage> — are excluded by requiring at
# least one hyphen-separated name part made of the characters an address may hold;
# a trailing hyphen therefore matches nothing. The leading (^|[^A-Za-z]) guard
# stops TERM:event-envelope from reading as M:event-envelope.
method_references() {
  local f
  while IFS= read -r f; do
    without_fences "$f" | grep -oE '(^|[^A-Za-z])M:[a-z][a-z0-9]*(-[a-z0-9]+)+'
  done < <(doc_files) | sed 's/^[^M]*//' | sort -u
}

check_method_refs() {
  local bad=0 decls addr paths count
  if [ ! -f "$resolver" ]; then
    ok "$resolver absent (M: declarations not checked)"
    return
  fi
  decls=$(method_declarations)

  # Two declarations is a failure, not a tie to break, so both files are named:
  # the fix is to delete one, and you cannot pick which without seeing both.
  while IFS= read -r addr; do
    [ -z "$addr" ] && continue
    paths=$(printf '%s\n' "$decls" | awk -F'\t' -v a="$addr" '$1 == a { print $2 }' | tr '\n' ' ')
    err "method ref $addr is declared twice (${paths% }); delete one, do not keep both in sync (see docs/method/README.md)"
    bad=$((bad + 1))
  done < <(printf '%s\n' "$decls" | awk -F'\t' 'NF { print $1 }' | sort | uniq -d)

  while IFS= read -r addr; do
    [ -z "$addr" ] && continue
    count=$(printf '%s\n' "$decls" | awk -F'\t' -v a="$addr" '$1 == a' | grep -c .)
    if [ "$count" -eq 0 ]; then
      err "method ref $addr is referenced but no heading under docs/method/ declares it (see docs/method/README.md)"
      bad=$((bad + 1))
    fi
  done < <(method_references)

  [ "$bad" -eq 0 ] && ok "every M: address referenced is declared exactly once under docs/method/"
}

# --- 12. ticket numbering is unique within a feature ---------------------------
# Owner: docs/agents/issue-tracker.md, "Tickets (.scratch/)".

ticket_numbers() {
  local f n
  for f in "$1"[0-9]*-*.md; do
    n=${f##*/}
    n=${n%%-*}
    case "$n" in ''|*[!0-9]*) continue ;; esac
    printf '%s\n' "$n"
  done
}

check_ticket_numbers() {
  local bad=0 d n hits
  [ -d .scratch ] || { ok ".scratch/ absent (no ticket numbering to check)"; return; }
  for d in .scratch/*/issues/; do
    while IFS= read -r n; do
      [ -z "$n" ] && continue
      hits=$(printf '%s ' "$d$n"-*.md)
      err "duplicate ticket number $n in $d (${hits% }); two tickets numbered $n make that address ambiguous — renumber the later one and fix its ID: line (see docs/agents/issue-tracker.md)"
      bad=$((bad + 1))
    done < <(ticket_numbers "$d" | sort | uniq -d)
  done
  [ "$bad" -eq 0 ] && ok "ticket numbers are unique within each feature"
}

# --- 13. Type: is in the closed set and legal for the node kind ----------------
# Vocabulary: docs/method/work-types.md. A node with no Type: line is a --strict
# matter, not this one's: a repository written before the header existed carries
# none, and a default run stays green on it.

type_is_known() {
  case "$1" in
    feature|bug|research|prototype|architecture|interface|test|implementation|review|rework|memory) return 0 ;;
    *) return 1 ;;
  esac
}

# The legal values for a node kind, as a string, so the failure can print them.
legal_types_for() {
  case "$1" in
    spec)   printf 'feature|bug|architecture\n' ;;
    ticket) printf 'all eleven\n' ;;
    spike)  printf 'research|prototype\n' ;;
  esac
}

type_is_legal() {
  case "$1" in
    spec)   case "$2" in feature|bug|architecture) return 0 ;; esac ;;
    ticket) type_is_known "$2" && return 0 ;;
    spike)  case "$2" in research|prototype) return 0 ;; esac ;;
  esac
  return 1
}

check_node_types() {
  local bad=0 kind f value
  while IFS=$'\t' read -r kind f; do
    value=$(header_value Type "$f")
    [ -z "$value" ] && continue
    if ! type_is_known "$value"; then
      err "unknown work type '$value' in $f (see docs/method/work-types.md for the eleven values)"
      bad=$((bad + 1))
      continue
    fi
    if ! type_is_legal "$kind" "$value"; then
      err "work type '$value' is not legal on a $kind: $f (a $kind takes $(legal_types_for "$kind") — see docs/method/work-types.md)"
      bad=$((bad + 1))
    fi
  done < <(node_files)
  [ "$bad" -eq 0 ] && ok "every Type: line uses a value legal for its node kind"
}

# --- 14. ID: matches the address its own path implies --------------------------
# Owner: docs/method/addressing.md, "The ID: line is a checksum, not a store".

check_node_ids() {
  local bad=0 kind f declared implied
  while IFS=$'\t' read -r kind f; do
    declared=$(header_value ID "$f")
    [ -z "$declared" ] && continue
    implied=$(implied_address "$kind" "$f") || continue
    [ -z "$implied" ] && continue
    if [ "$declared" != "$implied" ]; then
      err "ID: $declared in $f but its path implies $implied (a mismatch means the file was copied rather than created — see docs/method/addressing.md)"
      bad=$((bad + 1))
    fi
  done < <(node_files)
  [ "$bad" -eq 0 ] && ok "every ID: line matches the address its own path implies"
}

# --- 15b. no ticket waits on itself --------------------------------------------
# Owner: docs/agents/issue-tracker.md, "Blocking". A ticket is unblocked when
# every address it names is finished, so a cycle is not a slow queue — it is a
# frontier that can never open, and nothing else in the system reports it. The
# graph draws the edges and says naming the problem belongs here.

# Every "<from><TAB><to>" blocking edge, ticket addresses only.
blocking_edges() {
  local kind f id value a
  while IFS=$'\t' read -r kind f; do
    [ "$kind" = ticket ] || continue
    id=$(header_value ID "$f")
    [ -n "$id" ] || continue
    value=$(header_value "Blocked by" "$f")
    [ -z "$value" ] && continue
    printf '%s\n' "$value" | tr ',' "$nl" | while IFS= read -r a; do
      a=$(printf '%s' "$a" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
      [ -n "$a" ] && printf '%s\t%s\n' "$id" "$a"
    done
  done < <(node_files)
}

check_blocked_by_cycles() {
  local edges cycle
  edges=$(blocking_edges)
  if [ -z "$edges" ]; then
    ok "no Blocked by: edges to check for cycles"
    return
  fi
  # Iterative edge removal: repeatedly drop every ticket that blocks nobody.
  # Whatever survives is exactly the set on a cycle. Kahn's algorithm without
  # the arrays bash 3.2 does not have.
  cycle=$(printf '%s\n' "$edges" | awk -F'\t' '
    { from[NR] = $1; to[NR] = $2; live[NR] = 1; n = NR }
    END {
      changed = 1
      while (changed) {
        changed = 0
        for (i = 1; i <= n; i++) {
          if (!live[i]) continue
          blocks_someone = 0
          for (j = 1; j <= n; j++) {
            if (live[j] && to[j] == from[i]) { blocks_someone = 1; break }
          }
          if (!blocks_someone) { live[i] = 0; changed = 1 }
        }
      }
      for (i = 1; i <= n; i++) if (live[i]) print from[i] " -> " to[i]
    }
  ')
  if [ -n "$cycle" ]; then
    err "Blocked by: cycle — these tickets wait on each other and can never reach the frontier (see docs/agents/issue-tracker.md): $(printf '%s' "$cycle" | tr '\n' ';' | sed 's/;$//')"
    return
  fi
  ok "no ticket waits on itself through Blocked by:"
}

# --- 15. every address on a node file resolves ---------------------------------
# Owner: docs/method/addressing.md. Resolution is the resolver's, in both senses:
# this check never parses an address, it only splits comma-separated lists and
# asks. "none" is the documented value for a top-level Parent:, not an address.

# "<address><TAB><field><TAB><path>" for every address a node file names.
node_addresses() {
  local kind f key value a
  while IFS=$'\t' read -r kind f; do
    for key in Parent Children "Blocked by" Refs; do
      value=$(header_value "$key" "$f")
      [ -z "$value" ] && continue
      printf '%s\n' "$value" | tr ',' "$nl" | while IFS= read -r a; do
        a=$(printf '%s' "$a" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
        [ -z "$a" ] && continue
        [ "$a" = "none" ] && continue
        printf '%s\t%s\t%s\n' "$a" "$key" "$f"
      done
    done
  done < <(node_files)
}

check_node_links() {
  local bad=0 occurrences index unresolved addr key f
  if [ ! -f "$resolver" ]; then
    ok "$resolver absent (node addresses not resolved)"
    return
  fi
  occurrences=$(node_addresses)
  [ -z "$occurrences" ] && { ok "every Parent:, Children:, Blocked by: and Refs: address resolves"; return; }

  # One --all pass is the whole address index, so the common case — an address
  # that resolves — costs no process at all. Only an address the index does not
  # hold is put to --check, which stays the authority on the verdict.
  index="$nl$(bash "$resolver" --all 2>/dev/null | cut -f1 | sort -u)$nl"
  unresolved=$nl
  while IFS= read -r addr; do
    [ -z "$addr" ] && continue
    case "$index" in
      *"$nl$addr$nl"*) continue ;;
    esac
    bash "$resolver" --check "$addr" >/dev/null 2>&1 && continue
    unresolved="$unresolved$addr$nl"
  done < <(printf '%s\n' "$occurrences" | cut -f1 | sort -u)

  while IFS=$'\t' read -r addr key f; do
    [ -z "$addr" ] && continue
    case "$unresolved" in
      *"$nl$addr$nl"*)
        err "$key: $addr in $f does not resolve (ask $resolver resolve $addr for the reason — see docs/method/addressing.md)"
        bad=$((bad + 1))
        ;;
    esac
  done < <(printf '%s\n' "$occurrences")
  [ "$bad" -eq 0 ] && ok "every Parent:, Children:, Blocked by: and Refs: address resolves"
}

# --- 16. --strict: every node file carries the node header ---------------------
# Owner: docs/memory.md, "Node headers". Strict-only on purpose: a spec written
# before the header existed carries Status: and Stage: and nothing else, and a
# default run must stay green on it (docs/memory.md, and the note at the top of
# this file).

check_node_headers() {
  local bad=0 kind f key
  while IFS=$'\t' read -r kind f; do
    for key in ID Type Parent; do
      if [ -z "$(header_value "$key" "$f")" ]; then
        err "--strict: $f has no $key: line (every node file carries ID:, Type: and Parent: — see docs/memory.md)"
        bad=$((bad + 1))
      fi
    done
  done < <(node_files)
  [ "$bad" -eq 0 ] && ok "--strict: every node file carries ID:, Type: and Parent:"
}

# --- 17. --strict: a spec past review has a review artifact --------------------
# Owner: docs/method/gates.md, M:gate-review. The shape is templates/review.md and
# the home is .scratch/<slug>/reviews/; a stage past review with no artifact is
# "reviewed" having degraded into "read".

check_review_artifact() {
  local bad=0 d slug stage f n
  for d in specs/[0-9][0-9][0-9]-*/; do
    [ -f "$d/spec.md" ] || continue
    stage=$(sed -n 's/^Stage: *//p' "$d/spec.md" | head -1)
    case "$stage" in ci|acceptance|memory) ;; *) continue ;; esac
    slug=$(basename "$d")
    slug=${slug#*-}
    n=0
    for f in ".scratch/$slug/reviews/"*.md; do
      n=$((n + 1))
    done
    if [ "$n" -eq 0 ]; then
      err "--strict: ${d%/}/spec.md is at stage '$stage' with no review artifact (expected .scratch/$slug/reviews/<NN>-<slug>.md in the templates/review.md shape — M:gate-review, docs/method/gates.md)"
      bad=$((bad + 1))
    fi
  done
  [ "$bad" -eq 0 ] && ok "--strict: every spec at ci, acceptance or memory has a review artifact"
}

# --- 18. --strict: an implemented spec names what shipped it -------------------
# Owner: docs/method/gates.md, M:gate-acceptance. Status: implemented at
# Stage: memory is the claim that the outcome shipped; the line is the evidence.

check_implemented_in() {
  local bad=0 d stage status
  for d in specs/[0-9][0-9][0-9]-*/; do
    [ -f "$d/spec.md" ] || continue
    stage=$(sed -n 's/^Stage: *//p' "$d/spec.md" | head -1)
    status=$(sed -n 's/^Status: *//p' "$d/spec.md" | head -1)
    [ "$stage" = memory ] || continue
    [ "$status" = implemented ] || continue
    if [ -z "$(header_value "Implemented in" "$d/spec.md")" ]; then
      err "--strict: ${d%/}/spec.md is implemented at stage memory with no 'Implemented in:' line (name the PR or commit that shipped it — M:gate-acceptance, docs/method/gates.md)"
      bad=$((bad + 1))
    fi
  done
  [ "$bad" -eq 0 ] && ok "--strict: every implemented spec at stage memory names what shipped it"
}

check_links
check_fences
check_status_home
check_stage_home
check_stage_status
check_specs_table
check_vendored_skills
check_ticket_labels
check_spec_files
check_link_direction
check_scratch_orphans
check_root_context
check_harness_skills
check_method_refs
check_ticket_numbers
check_node_types
check_node_ids
check_node_links
check_blocked_by_cycles

if [ "$STRICT" -eq 1 ]; then
  check_node_headers
  check_review_artifact
  check_implemented_in
fi

printf '\n'
if [ "$failures" -gt 0 ]; then
  printf '%d memory consistency failure(s)\n' "$failures"
  exit 1
fi
printf 'memory is consistent\n'
