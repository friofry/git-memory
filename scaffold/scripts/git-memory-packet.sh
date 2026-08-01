#!/usr/bin/env bash
#
# The stage-aware context envelope (see docs/method/packet-profiles.md).
#
#   scripts/git-memory-packet.sh F:007-auth-envelope build    print the build packet
#   scripts/git-memory-packet.sh T:007/03                     stage read from the spec
#   scripts/git-memory-packet.sh F:007-auth-envelope review --format json
#   scripts/git-memory-packet.sh T:007/03 build --budget 8000
#   scripts/git-memory-packet.sh --help                       usage, exit 0
#
set -uo pipefail
shopt -s nullglob

cd "$(dirname "$0")/.." || exit 1

if [ -r scripts/lib/git-memory-lib.sh ]; then
  . scripts/lib/git-memory-lib.sh
else
  printf '%s: missing scripts/lib/git-memory-lib.sh\n' "$(basename "$0")" >&2
  exit 2
fi

self=$(basename "$0")

# The address index is tab-separated; a literal tab in a pattern is the kind of
# byte an editor silently rewrites, so it is named once here.
tab=$(printf '\t')

# One resolver: address to path is git-memory-resolve.sh and nothing else, here
# included (docs/method/addressing.md, "One resolver"). Called through bash so a
# checkout that lost the executable bit still works.
resolver="scripts/git-memory-resolve.sh"

format=md
budget=""
address=""
stage=""
stage_source="the command line"

# The order layers are printed in, and the order the budget eats them in. Least
# important first for truncation: a packet that loses its Route is a wall of text
# with no answer to "which node, which stage, what am I being asked to do".
layer_order="route objective contract memory slice evidence"
layer_priority="memory evidence objective slice contract route"

# A diagnostic names what was wrong and what the valid values are, on stderr, then
# stops. A packet assembled around a guess looks complete, which is worse than none.
die() {
  printf '%s: %s\n' "$self" "$1" >&2
  shift
  while [ "$#" -gt 0 ]; do
    printf '  %s\n' "$1" >&2
    shift
  done
  exit 1
}

usage() {
  cat <<'EOF'
usage: git-memory-packet.sh <address> [stage] [--format md|json] [--budget N]
       git-memory-packet.sh --help

Assemble the context envelope for one node at one stage and print it to stdout.
Nothing is written into the repository: a packet is a projection of files that
change on every commit, so it is generated per turn and never committed
(docs/method/packet-profiles.md, "Rejected framings").

  <address>   the node the turn is about: F:007-auth-envelope, T:007/03,
              S:007/proto-a. ADR:, TERM: and M: addresses are references, not
              nodes, and no packet is assembled for one.
  [stage]     the delivery stage whose profile picks the layers. Omit it and the
              Stage: line of the feature's spec.md is used, which is where the
              stage lives (docs/agents/delivery-workflow.md).
  --format    md (default) or json.
  --budget N  cap the packet at roughly N tokens, estimated as bytes / 4. When
              the cap binds, the lowest-priority included layer is truncated
              within itself and says so, by how much; a layer the profile marks
              required is never dropped.

Layers, in print order: Route, Objective, Contract, Memory, Slice, Evidence.
Budget order, lowest priority first: Memory, Evidence, Objective, Slice,
Contract, Route.

Every layer is named in the output whether or not it is carried. An omitted layer
prints "Memory: omitted (build profile)" in md and {"omitted": "build profile"}
in json, so a reader can tell a layer that is empty from a layer that was never
requested.

Stages with a profile: research, spec, approval, plan, build, checks, review,
rework, acceptance, memory. The other two stages, request and ci, have no agent
turn to assemble a packet for — one is a human writing a sentence, the other is
GitHub Actions running a workflow. Asking for one is an error, not an empty
packet.

Exit status: 0 packet printed, 1 unresolvable address, unknown stage, a stage
with no profile, or a bad option.
EOF
}

# --- 1. the profile matrix -----------------------------------------------------
# docs/method/packet-profiles.md owns this table; this is its executable copy and
# the doc wins on any disagreement.

# The twelve stages live in scripts/lib/git-memory-lib.sh, once.
stage_is_known() { gm_stage_is_known "$1"; }

# Prints the layers this stage carries; exit 1 for a stage with no profile.
profile_layers() {
  case "$1" in
    research)   printf 'route objective memory\n' ;;
    spec)       printf 'route objective contract memory\n' ;;
    approval)   printf 'route objective contract memory\n' ;;
    plan)       printf 'route objective contract slice\n' ;;
    build)      printf 'route contract slice\n' ;;
    checks)     printf 'route contract slice evidence\n' ;;
    review)     printf 'route contract memory slice evidence\n' ;;
    rework)     printf 'route contract slice evidence\n' ;;
    acceptance) printf 'route objective contract evidence\n' ;;
    memory)     printf 'route memory evidence\n' ;;
    *) return 1 ;;
  esac
}

# The Route layer's "requested action": what this stage's owner is being asked to
# do, one line, from the stage table in docs/agents/delivery-workflow.md.
stage_action() {
  case "$1" in
    research)   printf 'inventory what is already known and name the unknowns\n' ;;
    spec)       printf 'write the outcome, the design and the draft acceptance scenarios\n' ;;
    approval)   printf 'read the four approval files and decide (M:gate-approval)\n' ;;
    plan)       printf 'cut the work into implementable tickets against the acceptance scenarios\n' ;;
    build)      printf 'implement the current slice against its acceptance scenarios\n' ;;
    checks)     printf 'run the commands in AGENTS.md until they pass, and keep the output (M:gate-checks)\n' ;;
    review)     printf 'independently try to find defects and record them in templates/review.md shape (M:gate-review)\n' ;;
    rework)     printf 'answer every blocking finding, and nothing else\n' ;;
    acceptance) printf 'verify each acceptance scenario against a demonstration and record a verdict (M:gate-acceptance)\n' ;;
    memory)     printf 'write the facts and decisions that changed back into the memory layer (M:gate-memory)\n' ;;
    *)          printf 'unknown\n' ;;
  esac
}

layer_title() {
  case "$1" in
    route) printf 'Route\n' ;;
    objective) printf 'Objective\n' ;;
    contract) [ "$stage" = spec ] && printf 'Contract (draft)\n' || printf 'Contract\n' ;;
    memory) printf 'Memory\n' ;;
    slice) printf 'Slice\n' ;;
    evidence) printf 'Evidence\n' ;;
  esac
}

# --- 2. arguments ---------------------------------------------------------------

parse_args() {
  local seen=0
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -h|--help)
        usage
        exit 0
        ;;
      --format)
        [ "$#" -ge 2 ] || die "--format needs a value" "expected: --format md|json"
        format=$2
        shift
        ;;
      --format=*) format=${1#--format=} ;;
      --budget)
        [ "$#" -ge 2 ] || die "--budget needs a value" "expected: --budget N, a token count"
        budget=$2
        shift
        ;;
      --budget=*) budget=${1#--budget=} ;;
      -*)
        die "unknown option $1" "try --help"
        ;;
      *)
        if [ "$seen" -eq 0 ]; then
          address=$1
          seen=1
        elif [ "$seen" -eq 1 ]; then
          stage=$1
          seen=2
        else
          die "unexpected argument '$1'" "usage: git-memory-packet.sh <address> [stage] [--format md|json] [--budget N]"
        fi
        ;;
    esac
    shift
  done

  [ -n "$address" ] || { usage >&2; exit 1; }

  case "$format" in
    md|json) ;;
    *) die "unknown format '$format'" "expected: md or json" ;;
  esac

  if [ -n "$budget" ]; then
    case "$budget" in
      ''|*[!0-9]*) die "--budget takes a whole number of tokens, not '$budget'" "the estimate is bytes / 4, so --budget 8000 is about 32000 bytes" ;;
    esac
    [ "$budget" -gt 0 ] || die "--budget must be greater than zero" "omit --budget for an uncapped packet"
  fi
}

# --- 3. the node, its feature, and the stage ------------------------------------
# Resolution goes through the resolver, and so does the feature lookup: the
# address index (--all) prints a feature followed by its own tickets and spikes,
# so walking it answers "which feature does this node belong to" without this
# script learning what an address looks like.

resolve_node() {
  local index row
  [ -f "$resolver" ] || die \
    "$resolver is missing" \
    "this script resolves every address through it and parses none itself" \
    "install it beside this one, or run scripts/check-memory.sh to see what else the scaffold is missing"

  node_path=$(bash "$resolver" resolve "$address") || die \
    "cannot assemble a packet for '$address': it does not resolve (the resolver's reason is above)" \
    "list what this repository declares with: $resolver --all"

  index=$(bash "$resolver" --all)
  row=$(printf '%s\n' "$index" | awk -F'\t' -v want="$address" '
    $1 ~ /^(ADR|TERM|M):/ { feat = ""; featpath = "" }
    $1 ~ /^F:/            { feat = $1; featpath = $2 }
    $1 == want            { printf "%s\t%s\n", feat, featpath; exit }
  ')
  feature_addr=${row%%"$tab"*}
  feature_dir=${row#*"$tab"}
  feature_dir=${feature_dir%/}

  if [ -z "$feature_addr" ] || [ -z "$feature_dir" ]; then
    die "'$address' resolves to $node_path but is not a node" \
      "a packet is assembled for a feature (F:), a ticket (T:) or a spike (S:)" \
      "ADR:, TERM: and M: addresses are references that layers cite, not nodes with a stage" \
      "a feature directory that holds no spec.md is absent from the index for the same reason"
  fi

  # The node file is what gets quoted. A ticket is its own file; a feature and a
  # spike are directories, and which file inside is the node depends on which —
  # a feature directory that also holds a README.md is still specified by spec.md.
  case "$node_path" in
    */) if [ "${node_path%/}" = "$feature_dir" ]; then
          node_file="$feature_dir/spec.md"
        else
          node_file="${node_path}README.md"
        fi ;;
    *)  node_file=$node_path ;;
  esac

  # .scratch/<slug>/ is the feature slug with no number prefix
  # (docs/method/addressing.md), and that folder holds the reviews as well as the
  # tickets. Derived from the directory name, never from the address.
  slug=${feature_dir##*/}
  slug=${slug#*-}

  spec_file="$feature_dir/spec.md"
}

read_stage() {
  if [ -z "$stage" ]; then
    stage=$(gm_header "$spec_file" Stage)
    stage_source="the Stage: line of $spec_file"
    [ -n "$stage" ] || die \
      "no stage given and $spec_file carries no Stage: line" \
      "pass one: $self $address build" \
      "or record it where it belongs — docs/agents/delivery-workflow.md"
  fi

  if ! stage_is_known "$stage"; then
    die "unknown stage '$stage' (from $stage_source)" \
      "the twelve stages are: request research spec approval plan build checks review rework ci acceptance memory" \
      "see docs/agents/delivery-workflow.md"
  fi

  if ! profile="$(profile_layers "$stage")"; then
    die "stage '$stage' has no packet profile, so asking for one is an error rather than an empty packet" \
      "stages with a profile: research spec approval plan build checks review rework acceptance memory" \
      "request is a human writing a sentence and ci is GitHub Actions running a workflow — docs/method/packet-profiles.md"
  fi
}

current_branch() {
  local b
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf '(not a git repository)\n'
    return 0
  fi
  b=$(git branch --show-current 2>/dev/null)
  # --show-current arrived in git 2.22; older git and a detached HEAD both fall
  # through to the symbolic name, and neither is a reason to fail a packet.
  [ -n "$b" ] || b=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  case "$b" in
    ''|HEAD) printf '(detached HEAD)\n' ;;
    *) printf '%s\n' "$b" ;;
  esac
}

# --- 4. reading fragments of files ----------------------------------------------
# Every layer is quoted from files, so these five helpers are the whole reading
# surface: strip the author-facing HTML comments, pull one section, list headings,
# read a header line, read a title.

strip_comments() {
  awk '
    {
      sub(/\r$/, "")   # a file checked out with CRLF endings is still a file
      s = $0; out = ""
      while (1) {
        if (incomment) {
          i = index(s, "-->")
          if (i == 0) { s = ""; break }
          s = substr(s, i + 3); incomment = 0
        } else {
          i = index(s, "<!--")
          if (i == 0) { out = out s; break }
          out = out substr(s, 1, i - 1)
          s = substr(s, i + 4); incomment = 1
        }
      }
      print out
    }
  '
}

# Comments removed, runs of blank lines squeezed to one, leading and trailing
# blanks dropped. A template's instructions are not content, and blank lines left
# where they stood spend budget on nothing.
tidy() {
  strip_comments | awk '
    { lines[++n] = $0 }
    END {
      start = 1; while (start <= n && lines[start] ~ /^[ \t]*$/) start++
      end = n;   while (end >= start && lines[end] ~ /^[ \t]*$/) end--
      for (i = start; i <= end; i++) {
        if (lines[i] ~ /^[ \t]*$/) { if (blank) continue; blank = 1 } else blank = 0
        print lines[i]
      }
    }
  '
}

quote_file() {
  [ -f "$1" ] || return 1
  tidy < "$1"
}

# Everything quoted out of a file is fenced, because a quoted "## Scenario" is
# indistinguishable from one of this packet's own headings otherwise, and an agent
# reading the outline then treats a file's section as a layer. Four backticks so a
# quoted ```bash block nests inside instead of closing the quotation.
quoted() {
  printf '````\n%s\n````\n' "$1"
}

# Truncation cuts whole lines, and cutting inside a quotation leaves its fence
# open — which turns every layer printed after it into code in any renderer. One
# closing fence costs a line and removes the failure mode.
close_open_fence() {
  local body=$1 count
  count=$(printf '%s\n' "$body" | grep -c '^````' 2>/dev/null)
  [ -z "$count" ] && count=0
  if [ $((count % 2)) -ne 0 ]; then
    printf '%s\n````\n' "$body"
  else
    printf '%s\n' "$body"
  fi
}

# The body under one heading, up to the next heading at the same level or higher.
# Headings inside a fenced block are content, not structure.
section_of() {
  [ -f "$1" ] || return 0
  awk -v want="$2" '
    { sub(/\r$/, "") }
    /^```/ { fenced = !fenced }
    !fenced && /^#+[ \t]*[^ \t]/ {
      text = $0
      match($0, /^#+/); lvl = RLENGTH
      sub(/^#+[ \t]*/, "", text); sub(/[ \t]*$/, "", text)
      if (inside && lvl <= want_lvl) inside = 0
      if (text == want) { inside = 1; want_lvl = lvl; next }
    }
    inside { print }
  ' "$1" | tidy
}

# Sub-headings only: a file's level-1 heading is its title, and a rules file
# titled "Event rules" listed beside its own rules reads as a fourth rule.
headings_of() {
  [ -f "$1" ] || return 0
  awk '
    { sub(/\r$/, "") }
    /^```/ { fenced = !fenced; next }
    fenced { next }
    /^#+[ \t]*[^ \t]/ {
      text = $0
      match($0, /^#+/)
      if (RLENGTH < 2) next
      sub(/^#+[ \t]*/, "", text); sub(/[ \t]*$/, "", text)
      if (text !~ /^<!--/) print "  - " text
    }
  ' "$1"
}

# tr -d '\015' rather than an \r inside the sed script: BSD sed does not read
# \r as a carriage return, and a CRLF checkout would leave one inside every
# value the header lines carry.
header_line() { # file, key
  gm_header "$1" "$2"
}

title_of() {
  gm_title "$1"
}

# A Refs:/Children:/Blocked by: line, one address per line, whitespace trimmed.
addresses_in() { # file, key
  header_line "$1" "$2" | tr ',' '\n' | awk '{ gsub(/^[ \t]+|[ \t]+$/, ""); if ($0 != "") print }'
}

resolve_quiet() {
  bash "$resolver" resolve "$1" 2>/dev/null
}

# The tickets and spikes of this feature, read off the address index rather than
# guessed from a glob. Rows are "<address>\t<path>". The index is walked once,
# in resolve_node, and reused: re-running --all per helper meant one packet
# scanned the whole repository five times over.
feature_children() {
  printf '%s\n' "$index" | awk -F'\t' -v feat="$feature_addr" '
    $1 ~ /^(ADR|TERM|M):/ { inside = 0; next }
    $1 ~ /^F:/            { inside = ($1 == feat); next }
    inside                { print }
  '
}

index_family() { # ADR / TERM
  printf '%s\n' "$index" | awk -F'\t' -v fam="$1:" 'index($1, fam) == 1 { print }'
}

# --- 5. the six layers ----------------------------------------------------------
# Each one prints its own body. What each is assembled from is the "Files read"
# paragraph of its M:packet-* section in docs/method/packet-profiles.md.

body_route() {
  printf -- '- Address: %s\n' "$address"
  printf -- '- Path: %s\n' "$node_path"
  printf -- '- Node file: %s\n' "$node_file"
  printf -- '- Feature: %s — %s/\n' "$feature_addr" "$feature_dir"
  printf -- '- Stage: %s, read from %s\n' "$stage" "$stage_source"
  printf -- '- Profile: M:packet-%s — docs/method/packet-profiles.md\n' "$stage"
  printf -- '- Branch: %s\n' "$(current_branch)"
  printf -- '- Action: %s\n' "$(stage_action "$stage")"
}

body_objective() {
  local outcome direction goal
  outcome=$(section_of "$spec_file" 'Outcome')
  if [ -n "$outcome" ]; then
    printf '### Outcome — %s\n\n%s\n' "$spec_file" "$(quoted "$outcome")"
  else
    printf '### Outcome — %s\n\n(no Outcome section with content; M:gate-request is not closed — docs/method/gates.md)\n' "$spec_file"
  fi
  direction=$(section_of active-context.md 'Direction')
  goal=$(section_of active-context.md 'Active goal')
  if [ -n "$direction" ] || [ -n "$goal" ]; then
    printf '\n### Direction — active-context.md\n\n'
    [ -n "$direction" ] && printf '%s\n\n' "$(quoted "$direction")"
    [ -n "$goal" ] && printf '%s\n' "$(quoted "$goal")"
  fi
}

body_contract() {
  local body f addr path n=0
  if body=$(quote_file "$feature_dir/acceptance.md"); then
    if [ "$stage" = spec ]; then
      printf '### Acceptance (draft, under edit this turn) — %s/acceptance.md\n\n%s\n' "$feature_dir" "$(quoted "$body")"
    else
      printf '### Acceptance — %s/acceptance.md\n\n%s\n' "$feature_dir" "$(quoted "$body")"
    fi
  else
    printf '### Acceptance — %s/acceptance.md is absent\n\nThe scenarios the feature is accepted against have no home yet — M:contract-acceptance.\n' "$feature_dir"
  fi

  printf '\n### Scope — %s\n\n' "$spec_file"
  for f in 'In scope' 'Out of scope' 'Constraints'; do
    body=$(section_of "$spec_file" "$f")
    printf '#### %s\n\n' "$f"
    if [ -n "$body" ]; then
      printf '%s\n\n' "$(quoted "$body")"
    else
      printf '(empty — a boundary nobody has drawn yet, not a feature without boundaries)\n\n'
    fi
  done

  # Design and decisions enter whole only at approval, where a human is being
  # asked to read and say yes and a summary would be what gets approved.
  case "$stage" in
    approval)
      for f in design decisions; do
        if body=$(quote_file "$feature_dir/$f.md"); then
          printf '### %s — %s/%s.md\n\n%s\n\n' "$f" "$feature_dir" "$f" "$(quoted "$body")"
        else
          printf '### %s — %s/%s.md is absent, so M:gate-approval does not open\n\n' "$f" "$feature_dir" "$f"
        fi
      done
      ;;
    plan)
      printf '### Design seams — %s/design.md\n\n' "$feature_dir"
      body=$(headings_of "$feature_dir/design.md")
      if [ -n "$body" ]; then
        printf '%s\n\nHeadings only: planning cuts tickets against acceptance, and opens a seam when it needs one.\n\n' "$body"
      else
        printf '(absent)\n\n'
      fi
      ;;
    *)
      printf '### Design and decisions\n\nReferenced, not expanded: %s/design.md, %s/decisions.md.\n\n' "$feature_dir" "$feature_dir"
      ;;
  esac

  printf '### Rules — rules/\n\n'
  for f in rules/*.md; do
    [ "$f" = "rules/README.md" ] && continue
    printf -- '- %s\n' "$f"
    headings_of "$f"
    n=$((n + 1))
  done
  [ "$n" -eq 0 ] && printf '(no rule files beyond rules/README.md)\n'

  printf '\n### Decisions this feature obeys — Refs: on %s\n\n' "$spec_file"
  n=0
  while IFS= read -r addr; do
    [ -n "$addr" ] || continue
    path=$(resolve_quiet "$addr")
    if [ -n "$path" ]; then
      printf -- '- %s → %s' "$addr" "$path"
      case "$path" in
        *.md) printf ' — %s' "$(title_of "${path%%#*}")" ;;
      esac
      printf '\n'
    else
      printf -- '- %s → does not resolve (check-memory.sh reports it)\n' "$addr"
    fi
    n=$((n + 1))
  done < <(addresses_in "$spec_file" 'Refs')
  [ "$n" -eq 0 ] && printf '(the spec carries no Refs: line)\n'
}

body_memory() {
  local n=0 addr path row
  printf '### Glossary — CONTEXT.md\n\n'
  if [ "$stage" = memory ]; then
    # The memory stage edits these entries, and an edit needs the current wording
    # rather than an address to look up — M:packet-memory.
    if row=$(quote_file CONTEXT.md); then
      printf '%s\n' "$(quoted "$row")"
    else
      printf '(CONTEXT.md is absent)\n'
    fi
  else
    while IFS= read -r row; do
      printf -- '- %s\n' "$(printf '%s\n' "$row" | tr '\t' ' ')"
      n=$((n + 1))
    done < <(index_family TERM)
    [ "$n" -eq 0 ] && printf '(no level-2 headings in CONTEXT.md, so no terms are addressable)\n'
    printf '\nEntries enter by address; quote one in full only when the turn is about it.\n'
  fi

  printf '\n### Architecture — docs/architecture/\n\n'
  n=0
  for path in docs/architecture/*.md; do
    printf -- '- %s — %s\n' "$path" "$(title_of "$path")"
    n=$((n + 1))
  done
  [ "$n" -eq 0 ] && printf '(empty)\n'

  printf '\n### Domain — docs/domain/\n\n'
  n=0
  for path in docs/domain/*.md; do
    printf -- '- %s — %s\n' "$path" "$(title_of "$path")"
    n=$((n + 1))
  done
  [ "$n" -eq 0 ] && printf '(empty)\n'

  printf '\n### Decisions — docs/adr/\n\n'
  n=0
  while IFS= read -r row; do
    addr=${row%%"$tab"*}
    path=${row#*"$tab"}
    printf -- '- %s — %s (%s)\n' "$addr" "$(title_of "$path")" "$path"
    n=$((n + 1))
  done < <(index_family ADR)
  if [ "$n" -eq 0 ]; then
    printf '(no ADRs)\n'
  else
    printf '\nAddress plus title only. An ADR body enters the packet when the turn names it.\n'
  fi
}

body_slice() {
  local row addr path status title n=0 changed
  printf '### Node under work — %s\n\n' "$node_file"
  if [ "$address" = "$feature_addr" ]; then
    printf 'The address names the feature, so the slice is its ticket queue rather than one ticket.\n'
  elif row=$(quote_file "$node_file"); then
    printf '%s\n' "$(quoted "$row")"
  else
    printf '(%s does not exist; the address resolved to a directory with no node file)\n' "$node_file"
  fi

  printf '\n### Ticket queue — .scratch/%s/issues/\n\n' "$slug"
  while IFS= read -r row; do
    addr=${row%%"$tab"*}
    path=${row#*"$tab"}
    case "$path" in
      */issues/*)
        status=$(gm_header "$path" Status)
        title=$(title_of "$path")
        printf -- '- %s — %s [%s]\n' "$addr" "$title" "${status:-no status}"
        n=$((n + 1))
        ;;
    esac
  done < <(feature_children)
  if [ "$n" -eq 0 ]; then
    printf '(no tickets)\n'
  else
    printf '\nAddresses and titles only: a builder holding nine other tickets writes code for slices that are not theirs.\n'
  fi

  printf '\n### Commands — AGENTS.md\n\n'
  row=$(section_of AGENTS.md 'Before finishing')
  if [ -n "$row" ]; then
    printf '%s\n' "$(quoted "$row")"
  else
    printf '(AGENTS.md has no "Before finishing" section; M:gate-checks has no commands to demand)\n'
  fi

  printf '\n### Changed paths — git status --porcelain\n\n'
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    changed=$(git status --porcelain 2>/dev/null | head -40)
    if [ -n "$changed" ]; then
      printf '%s\n' "$(quoted "$changed")"
    else
      printf '(working tree clean)\n'
    fi
  else
    printf '(not a git repository)\n'
  fi
}

body_evidence() {
  local f n=0 row addr path body blocked
  printf '### Review artifacts — .scratch/%s/reviews/\n\n' "$slug"
  for f in ".scratch/$slug/reviews/"*.md; do
    printf -- '- %s — %s\n' "$f" "$(title_of "$f")"
    printf '  Severity vocabulary: %s\n' "$(header_line "$f" 'Severity')"
    body=$(section_of "$f" 'Blocking issues')
    if [ -n "$body" ]; then
      printf '\n#### Blocking issues, from %s\n\n%s\n' "$f" "$(quoted "$body")"
    else
      printf '  (no blocking issues recorded)\n'
    fi
    n=$((n + 1))
  done
  if [ "$n" -eq 0 ]; then
    printf '(none — M:gate-review is not closed, so the feature does not move into ci)\n'
  fi

  printf '\n### Answers and blockers — .scratch/%s/issues/\n\n' "$slug"
  n=0
  while IFS= read -r row; do
    addr=${row%%"$tab"*}
    path=${row#*"$tab"}
    case "$path" in
      */issues/*) ;;
      *) continue ;;
    esac
    blocked=$(header_line "$path" 'Blocked by')
    if [ -n "$blocked" ]; then
      printf -- '- %s is blocked by %s\n' "$addr" "$blocked"
      n=$((n + 1))
    fi
    body=$(section_of "$path" 'Answer')
    if [ -n "$body" ]; then
      printf -- '- %s answered:\n\n%s\n' "$addr" "$(quoted "$body")"
      n=$((n + 1))
    fi
  done < <(feature_children)
  [ "$n" -eq 0 ] && printf '(no ticket records an answer or a blocker)\n'

  printf '\n### Checks and CI\n\n'
  printf 'Local command output is not stored in the repository: run the commands in AGENTS.md and paste the run into the PR body, which is the evidence M:gate-checks demands.\n'
  printf 'CI results are not readable from the working tree either — read the run under .github/workflows/ on the head commit, which is what M:gate-ci demands (docs/method/gates.md).\n'
}

# --- 6. layer state -------------------------------------------------------------
# bash 3.2 has no associative arrays, so the six layers live in variables named
# after them and are reached with eval. The names come from layer_order above and
# never from an argument, so nothing user-supplied is evaluated.

put() { eval "$1=\$2"; }
get() { eval "printf '%s\\n' \"\${$1-}\""; }

is_included() {
  case " $profile " in
    *" $1 "*) return 0 ;;
    *) return 1 ;;
  esac
}

assemble() {
  local layer
  for layer in $layer_order; do
    put "trunc_$layer" ""
    if is_included "$layer"; then
      put "body_$layer" "$(body_"$layer")"
    else
      put "body_$layer" ""
    fi
  done
}

included_titles() {
  local layer out=""
  for layer in $layer_order; do
    is_included "$layer" && out="$out, $(layer_title "$layer")"
  done
  printf '%s\n' "${out#, }"
}

omitted_titles() {
  local layer out=""
  for layer in $layer_order; do
    is_included "$layer" || out="$out, $(layer_title "$layer")"
  done
  printf '%s\n' "${out#, }"
}

# --- 7. the budget --------------------------------------------------------------
# Tokens are estimated as bytes / 4 — an estimate, said so in --help and in the
# packet. When it binds, one layer is shortened within itself and says by how
# much; a layer the profile marks required is never dropped, because a packet
# missing a required layer is worse than a long one: the agent cannot tell.

byte_len() { printf '%s\n' "$1" | LC_ALL=C wc -c | tr -d '[:space:]'; }

keep_bytes() { # max bytes on stdin, whole lines only
  # LC_ALL=C so length() counts bytes: the budget is a byte budget, and a packet
  # holding Cyrillic or an em dash would otherwise be measured short.
  LC_ALL=C awk -v max="$1" '{ n = length($0) + 1; if (used + n > max) exit; used += n; print }'
}

# Room for the truncation notice the shortened layer is about to carry.
notice_allowance=140

# No included layer is cut below this many bytes. A layer shortened to nothing is
# indistinguishable from a layer that had nothing in it, and the reader cannot
# see what they are not being shown; a few opening lines keep the layer legible
# and keep the notice honest about the rest.
layer_floor=240

truncate_lowest() {
  local over=$1 layer body size keep shorter newsize dropped before
  for layer in $layer_priority; do
    is_included "$layer" || continue
    body=$(get "body_$layer")
    size=$(byte_len "$body")
    [ "$size" -le "$layer_floor" ] && continue
    keep=$((size - over - notice_allowance))
    [ "$keep" -lt "$layer_floor" ] && keep=$layer_floor
    shorter=$(printf '%s\n' "$body" | keep_bytes "$keep")
    shorter=$(close_open_fence "$shorter")
    newsize=$(byte_len "$shorter")
    dropped=$((size - newsize))
    [ "$dropped" -le 0 ] && continue
    put "body_$layer" "$shorter"
    before=$(get "trunc_$layer")
    if [ -n "$before" ]; then
      dropped=$((dropped + ${before%% *}))
      size=${before#* }
    fi
    put "trunc_$layer" "$dropped $size"
    return 0
  done
  return 1
}

truncation_note() { # layer
  local t dropped original
  t=$(get "trunc_$1")
  [ -n "$t" ] || return 1
  dropped=${t%% *}
  original=${t#* }
  printf 'Truncated to fit --budget %s: %s of %s bytes dropped (~%s of ~%s tokens), lowest-priority layer first.\n' \
    "$budget" "$dropped" "$original" "$((dropped / 4))" "$((original / 4))"
}

# --- 8. rendering ---------------------------------------------------------------

size_note="(measuring)"

render_md() {
  local layer body note
  printf '# Packet — %s at stage %s\n\n' "$address" "$stage"
  printf 'Profile M:packet-%s, from docs/method/packet-profiles.md. Assembled per turn by scripts/%s; nothing is written into the repository.\n\n' "$stage" "$self"
  printf -- '- Included layers: %s\n' "$(included_titles)"
  printf -- '- Omitted layers: %s\n' "$(omitted_titles)"
  printf -- '- Size: %s\n' "$size_note"

  for layer in $layer_order; do
    printf '\n## %s\n\n' "$(layer_title "$layer")"
    if ! is_included "$layer"; then
      printf '%s: omitted (%s profile). The layer is not missing — the profile leaves it out to buy the reader'"'"'s attention for the layers above (M:packet-%s).\n' \
        "$(layer_title "$layer")" "$stage" "$stage"
      continue
    fi
    if note=$(truncation_note "$layer"); then
      printf '_%s_\n\n' "$note"
    fi
    body=$(get "body_$layer")
    if [ -n "$body" ]; then
      printf '%s\n' "$body"
    elif [ -n "$(get "trunc_$layer")" ]; then
      printf '(the whole of this layer was dropped to fit the budget; the profile still requires it, so it is named rather than removed)\n'
    else
      printf '(this layer is included by the %s profile and came back empty — the files it reads exist but hold nothing)\n' "$stage"
    fi
  done
}

# JSON strings are escaped a character at a time on purpose: gsub replacement
# text treats backslashes as magic and does it differently in different awks,
# which is exactly the portability trap this script cannot afford.
json_escape() {
  awk '
    function esc(s,   out, c, i) {
      out = ""
      for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (c == "\\") out = out "\\\\"
        else if (c == "\"") out = out "\\\""
        else if (c == "\t") out = out "\\t"
        else if (c < " ") out = out " "
        else out = out c
      }
      return out
    }
    NR > 1 { printf "%s", "\\n" }
    { printf "%s", esc($0) }
  '
}

json_str() { printf '%s' "$1" | json_escape; }

render_json() {
  local layer body note first=1
  printf '{\n'
  printf '  "address": "%s",\n' "$(json_str "$address")"
  printf '  "path": "%s",\n' "$(json_str "$node_path")"
  printf '  "node_file": "%s",\n' "$(json_str "$node_file")"
  printf '  "feature": "%s",\n' "$(json_str "$feature_addr")"
  printf '  "feature_path": "%s",\n' "$(json_str "$feature_dir/")"
  printf '  "stage": "%s",\n' "$(json_str "$stage")"
  printf '  "stage_source": "%s",\n' "$(json_str "$stage_source")"
  printf '  "profile": "M:packet-%s",\n' "$(json_str "$stage")"
  printf '  "branch": "%s",\n' "$(json_str "$(current_branch)")"
  printf '  "action": "%s",\n' "$(json_str "$(stage_action "$stage")")"
  printf '  "budget_tokens": %s,\n' "${budget:-null}"
  printf '  "estimated_tokens": %s,\n' "$estimated_tokens"
  printf '  "estimate": "bytes / 4",\n'
  printf '  "layers": {\n'
  for layer in $layer_order; do
    [ "$first" -eq 1 ] || printf ',\n'
    first=0
    printf '    "%s": {' "$layer"
    if ! is_included "$layer"; then
      printf '"omitted": "%s profile"}' "$(json_str "$stage")"
      continue
    fi
    body=$(get "body_$layer")
    printf '"text": "%s"' "$(json_str "$body")"
    if note=$(truncation_note "$layer"); then
      printf ', "truncated": "%s"' "$(json_str "$note")"
    fi
    printf '}'
  done
  printf '\n  }\n}\n'
}

render() {
  case "$format" in
    json) render_json ;;
    *) render_md ;;
  esac
}

estimated_tokens=0

# Measure the rendered packet, shorten the lowest-priority layer while the
# estimate is over budget, then print. The size line reports the measurement of
# the render it is printed in, because only its own digits change between the
# two.
set_size_note() { # bytes
  estimated_tokens=$(($1 / 4))
  if [ -n "$budget" ]; then
    size_note=$(printf '%s bytes, ~%s tokens (estimated as bytes / 4), against --budget %s' "$1" "$estimated_tokens" "$budget")
  else
    size_note=$(printf '%s bytes, ~%s tokens (estimated as bytes / 4), no --budget' "$1" "$estimated_tokens")
  fi
}

# The size line is inside the thing it measures, so writing it changes the
# answer. Measuring once reported the length of a render still carrying the
# "(measuring)" placeholder — eleven characters standing in for about seventy —
# which under-reported every packet and, worse, enforced --budget against that
# wrong number. Iterate to a fixed point instead: stop when the render's real
# length equals the length its own size line claims. Only digits move between
# passes, so it settles in two or three.
measure() {
  local bytes claimed k
  for k in 1 2 3 4; do
    bytes=$(byte_len "$(render)")
    claimed=${size_note%% *}
    [ "$claimed" = "$bytes" ] && break
    set_size_note "$bytes"
  done
  estimated_tokens=$((bytes / 4))
}

emit() {
  local over i
  for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
    measure
    if [ -n "$budget" ] && [ "$estimated_tokens" -gt "$budget" ]; then
      over=$(( (estimated_tokens - budget) * 4 ))
      truncate_lowest "$over" && continue
      # Nothing left that may be cut: Route is the last layer standing and the
      # profile's required layers are not droppable.
      printf '%s: --budget %s cannot be met without dropping a required layer; printing the smallest packet the %s profile allows (~%s tokens)\n' \
        "$self" "$budget" "$stage" "$estimated_tokens" >&2
    fi
    break
  done
  render
}

# --- 9. dispatch ----------------------------------------------------------------

parse_args "$@"
resolve_node
read_stage
assemble
emit
