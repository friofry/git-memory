#!/usr/bin/env bash
#
# The twelve-stage checklist for a feature, with a box per stage.
#
#   scripts/git-memory-progress.sh                  every unfinished feature
#   scripts/git-memory-progress.sh F:012-transfers  one feature
#   scripts/git-memory-progress.sh --all            include implemented features
#   scripts/git-memory-progress.sh --format json
#   scripts/git-memory-progress.sh --strict         exit 1 on a claimed-but-unproven stage
#   scripts/git-memory-progress.sh --cheatsheet     one line per stage: what drives it
#   scripts/git-memory-progress.sh --help           usage, exit 0
#
# Two independent signals per stage, and the point of the script is where they
# disagree:
#
#   position  is this stage before the Stage: line?   — what the repository CLAIMS
#   evidence  is there an artifact proving it?         — what the repository PROVES
#
# A stage the feature has walked past with nothing to show for it prints [!].
# That is the only line here worth reading twice: every other box restates
# something you could have seen by opening the folder.
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

format=text
want_all=0
strict=0
sheet=0
address=""

# The twelve stages in order. docs/agents/delivery-workflow.md owns the
# vocabulary; gm_stage_is_known is its executable copy and this is the ordering
# the table implies.
stages="request research spec approval plan build checks review rework ci acceptance memory"

usage() {
  cat <<'EOF'
usage: git-memory-progress.sh [address] [--all] [--format text|md|json] [--strict]
       git-memory-progress.sh --help

Print the twelve delivery stages for a feature with a box per stage, filled from
evidence in the repository rather than from the Stage: line alone.

  [address]   a feature address (F:012-internal-transfers) or a slug. Omit it and
              every feature that has not reached stage memory is printed.
  --all       include features already at stage memory.
  --format    text (default), md for a task list you can paste into an issue, or
              json for another tool to read.
  --strict    exit 1 if any stage is claimed but unproven. Use it in CI.
  --cheatsheet  one line per stage — the skill that drives it, or the action
              expected of you where no skill applies — and what "done" means
              there. Combine with an address to mark the stage you are on. The
              table is read out of docs/agents/delivery-workflow.md, so it can
              never disagree with the workflow it describes.

Boxes:

  [x]  passed, and an artifact proves it
  [!]  passed by position, but nothing in the repository proves it
  [>]  the current stage
  [ ]  not reached yet
  [-]  optional, and this feature did not need it
  [?]  the evidence lives outside the repository (an issue, a CI run)

What counts as evidence, per stage:

  request     a non-empty "## Outcome" section in spec.md
  research    a spike under spikes/<slug>/ — optional, and skipped cleanly
  spec        all four files present and none of them empty
  approval    an "Approved:" line in decisions.md
  plan        at least one ticket under .scratch/<slug>/issues/
  build       a ticket at Status: done, or an Implemented in: line
  checks      a non-empty "## Commands run" section in a review artifact
  review      a review artifact under .scratch/<slug>/reviews/
  rework      that artifact's "## Blocking issues" section is empty or says none
  ci          an Implemented in: line naming the pull request or commit
  acceptance  a "Verdict:" line in acceptance.md
  memory      Status: implemented together with an Implemented in: line

Three of those — the "Approved:", "Verdict:" and "## Commands run" lines — are
conventions this script reads and nothing else enforces. A project that does not
write them sees [!] on those stages and is not wrong, only unproven.

Exit status: 0 printed, 1 --strict found a claimed-but-unproven stage, 2 a usage
error or an address that resolves to nothing.
EOF
}

die() {
  printf '%s: %s\n' "$self" "$1" >&2
  [ "$#" -gt 1 ] && printf '  %s\n' "$2" >&2
  exit 2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --all)     want_all=1 ;;
    --strict)  strict=1 ;;
    --cheatsheet) sheet=1 ;;
    --format)
      [ "$#" -ge 2 ] || die "--format needs a value" "expected: --format text|md|json"
      format=$2; shift ;;
    --format=*) format=${1#--format=} ;;
    -*) die "unknown option $1" "try --help" ;;
    *)
      [ -z "$address" ] || die "more than one address given" "one feature at a time, or none for all"
      address=$1 ;;
  esac
  shift
done

case "$format" in
  text|md|json) ;;
  *) die "unknown format '$format'" "expected: text, md or json" ;;
esac

# --- colour --------------------------------------------------------------------
# Only when stdout is a terminal: a redirected run feeds a file or another tool,
# and escape sequences in it are noise that shows up much later as a mystery.

if [ -t 1 ] && [ "$format" = text ] && [ -z "${NO_COLOR:-}" ]; then
  c_done=$(printf '\033[32m'); c_gap=$(printf '\033[31m')
  c_now=$(printf '\033[36m');  c_dim=$(printf '\033[90m')
  c_hd=$(printf '\033[1m');    c_off=$(printf '\033[0m')
else
  c_done=""; c_gap=""; c_now=""; c_dim=""; c_hd=""; c_off=""
fi

# --- helpers -------------------------------------------------------------------

# The 0-based index of a stage in the ordered list, or -1 when it is not a stage.
stage_index() {
  local i=0 s
  for s in $stages; do
    [ "$s" = "$1" ] && { printf '%s' "$i"; return 0; }
    i=$((i + 1))
  done
  printf '%s' -1
}

# A markdown section's body, fences and HTML comments dropped, so a template
# whose guidance is still in place does not read as filled in.
section_body() { # file, heading
  [ -f "$1" ] || return 0
  awk -v want="$2" '
    { sub(/\r$/, "") }
    /^```/ { fenced = !fenced; next }
    fenced { next }
    /^## / {
      line = $0
      sub(/^## */, "", line)
      gsub(/[ \t]+$/, "", line)
      inside = (line == want)
      next
    }
    !inside { next }
    /<!--/  { if (!/-->/) { commented = 1 }; next }
    commented { if (/-->/) { commented = 0 }; next }
    { print }
  ' "$1" 2>/dev/null
}

# Non-blank, non-placeholder text in a section?
section_filled() {
  local body
  body=$(section_body "$1" "$2" | awk '{ gsub(/^[ \t]+|[ \t]+$/, ""); if ($0 != "" && $0 !~ /^(TODO|TBD|\.\.\.|—|-)$/) print }')
  [ -n "$body" ]
}

file_filled() {
  [ -f "$1" ] || return 1
  awk '
    { sub(/\r$/, "") }
    /^```/ { fenced = !fenced; next }
    fenced { next }
    /<!--/ { if (!/-->/) { commented = 1 }; next }
    commented { if (/-->/) { commented = 0 }; next }
    /^#/ { next }
    { gsub(/^[ \t]+|[ \t]+$/, ""); if ($0 != "") { found = 1; exit } }
    END { exit (found ? 0 : 1) }
  ' "$1" 2>/dev/null
}

count_glob() { # any number of paths
  local n=0 p
  for p in "$@"; do [ -e "$p" ] && n=$((n + 1)); done
  printf '%s' "$n"
}

json_escape() {
  printf '%s' "$1" | awk '
    BEGIN { RS = "\0" }
    { gsub(/\\/, "\\\\"); gsub(/"/, "\\\""); gsub(/\n/, "\\n"); gsub(/\t/, "\\t"); printf "%s", $0 }
  '
}

# --- the cheatsheet ------------------------------------------------------------
# One line per stage: what drives it, and what "done" means there.
#
# Parsed out of docs/agents/delivery-workflow.md rather than written here. That
# doc owns both tables — "Stages" and "Which skill performs which stage" — and a
# copy of them inside a script is a second home that goes stale the first time a
# stage's entry point changes. If the parse finds nothing, that is a real failure
# and it says so rather than printing a plausible table from memory.

cheatsheet() { # optional: the stage to mark as current
  local doc=docs/agents/delivery-workflow.md current=${1:-} out
  [ -r "$doc" ] || die "cannot read $doc" \
    "the cheatsheet is a projection of that file's tables, not a second copy of them"

  out=$(awk -v order="$stages" -v current="$current" -v mark="$c_now" -v dim="$c_dim" -v off="$c_off" '
    function trim(s) { gsub(/^[ \t]+/, "", s); gsub(/[ \t]+$/, "", s); return s }
    function unbacktick(s) { gsub(/`/, "", s); return trim(s) }

    # Prose out of a table cell: link targets dropped, backticks and relative
    # path noise removed. The doc writes "[`../../AGENTS.md`](../../AGENTS.md)"
    # because it is a document; a terminal wants "AGENTS.md".
    function prose(s) {
      gsub(/\]\([^)]*\)/, "", s)
      gsub(/[][]/, "", s)
      gsub(/`/, "", s)
      gsub(/\.\.\//, "", s)
      return trim(s)
    }

    # A cell like "[`../../.cursor/skills/review-change/`](…), [`…/review-architecture/`](…)"
    # becomes "/review-change, /review-architecture". A cell with no skill path is
    # prose and is kept as written, minus the markdown.
    function shorten(s,   res, n, name) {
      gsub(/\]\([^)]*\)/, "", s)          # drop link targets, keep link text
      gsub(/\[/, "", s)
      s = trim(s)
      sub(/ +[-—] .*$/, "", s)            # drop the trailing " — explanation"
      res = ""
      while (match(s, /skills\/[A-Za-z0-9_-]+\//)) {
        name = substr(s, RSTART + 7, RLENGTH - 8)
        res = res (res == "" ? "" : ", ") "/" name
        s = substr(s, RSTART + RLENGTH)
      }
      if (res != "") return res
      s = prose(s)
      if (s == "Human") return "you (human gate)"
      if (s == "GitHub Actions") return "GitHub Actions"
      if (s ~ /^The commands in /) return "AGENTS.md commands"
      if (s ~ /^The skill that changed/) return "whichever skill changed it"
      return s
    }

    BEGIN { FS = "|" }
    /^\| *# *\| *.Stage:. *\| *Owner *\| *Done when/ { t = 1; next }
    /^\| *Stage *\| *Entry point *\| *Craft/         { t = 2; next }
    /^\|[ :|-]+\|$/                                  { next }
    /^ *$/                                           { t = 0 }
    t == 1 && NF >= 6 { done[unbacktick($3)] = prose($5) }
    t == 2 && NF >= 4 { entry[unbacktick($2)] = shorten($3) }

    END {
      n = split(order, st, " ")
      for (i = 1; i <= n; i++) {
        s = st[i]
        if (!(s in entry) && !(s in done)) continue
        found++
        pre = (s == current) ? mark "->" : "  "
        suf = (s == current) ? off : ""
        printf "%s %-11s %-26s %s%s%s\n", pre, s, (s in entry ? entry[s] : "?"), dim, (s in done ? done[s] : ""), off suf
      }
      exit (found ? 0 : 1)
    }
  ' "$doc") || die "found no stage table in $doc" \
    "expected the 'Stages' and 'Which skill performs which stage' tables; has the file been reshaped?"

  printf '%sSTAGE       ENTRY POINT                DONE WHEN%s\n' "$c_hd" "$c_off"
  printf '%s\n' "$out"
  printf '\n%sBefore any long turn, at any stage: /prepare-packet%s\n' "$c_dim" "$c_off"
  printf '%sSource: %s — edit the tables there, never this output.%s\n' "$c_dim" "$doc" "$c_off"
}

# --- evidence per stage --------------------------------------------------------
# Sets ev_state (done|none|skip|external) and ev_note. One function so the twelve
# rules sit together and can be read as a table; splitting them across the
# printer would hide the shape.

evidence_for() { # stage, dir, slug
  local st=$1 d=$2 slug=$3 n body
  ev_state=none
  ev_note=""

  case "$st" in
    request)
      if section_filled "$d/spec.md" Outcome; then
        ev_state=done; ev_note="outcome written in spec.md"
      else
        ev_note="spec.md has an empty ## Outcome section"
      fi
      ;;
    research)
      n=$(count_glob "spikes/$slug"/*/)
      if [ "$n" -gt 0 ]; then
        ev_state=done; ev_note="spikes: $n"
      elif section_filled "$d/spec.md" Unknown; then
        ev_note="spec.md still lists Unknowns and there is no spike"
      else
        ev_state=skip; ev_note="no unknowns left, stage not needed"
      fi
      ;;
    spec)
      n=0
      for f in spec design acceptance decisions; do
        file_filled "$d/$f.md" && n=$((n + 1))
      done
      if [ "$n" -eq 4 ]; then
        ev_state=done; ev_note="all four files filled in"
      else
        ev_note="files filled in: $n of 4"
      fi
      ;;
    approval)
      if [ -n "$(gm_header "$d/decisions.md" Approved)" ]; then
        ev_state=done; ev_note="Approved: $(gm_header "$d/decisions.md" Approved)"
      else
        ev_note="no Approved: line in decisions.md"
      fi
      ;;
    plan)
      n=$(count_glob ".scratch/$slug/issues"/*.md)
      if [ "$n" -gt 0 ]; then
        ev_state=done; ev_note="tickets: $n"
      else
        ev_note="no tickets under .scratch/$slug/issues/"
      fi
      ;;
    build)
      n=0
      for f in ".scratch/$slug/issues"/*.md; do
        [ "$(gm_header "$f" Status)" = done ] && n=$((n + 1))
      done
      if [ "$n" -gt 0 ]; then
        ev_state=done; ev_note="tickets at Status: done: $n"
      elif [ -n "$(gm_header "$d/spec.md" "Implemented in")" ]; then
        ev_state=done; ev_note="an Implemented in: line is present"
      else
        ev_note="no ticket is at Status: done"
      fi
      ;;
    checks)
      for f in ".scratch/$slug/reviews"/*.md; do
        if section_filled "$f" "Commands run"; then
          ev_state=done; ev_note="command output kept in $(basename "$f")"
          break
        fi
      done
      [ "$ev_state" = done ] || ev_note="no review artifact fills in ## Commands run"
      ;;
    review)
      n=$(count_glob ".scratch/$slug/reviews"/*.md)
      if [ "$n" -gt 0 ]; then
        ev_state=done; ev_note="review artifacts: $n"
      else
        ev_note=".scratch/$slug/reviews/ is empty"
      fi
      ;;
    rework)
      n=0
      for f in ".scratch/$slug/reviews"/*.md; do
        body=$(section_body "$f" "Blocking issues" |
          awk '{ gsub(/^[ \t]+|[ \t]+$/, "");
                 if ($0 != "" && $0 !~ /^([Nn]one|[Нн]ет|—|-)$/ && $0 !~ /^<!--/) print }')
        [ -n "$body" ] && n=$((n + 1))
      done
      if [ "$(count_glob ".scratch/$slug/reviews"/*.md)" -eq 0 ]; then
        ev_note="no review yet"
      elif [ "$n" -eq 0 ]; then
        ev_state=done; ev_note="no blocking findings left open"
      else
        ev_note="reviews with open blocking findings: $n"
      fi
      ;;
    ci)
      if [ -n "$(gm_header "$d/spec.md" "Implemented in")" ]; then
        ev_state=external; ev_note="Implemented in: $(gm_header "$d/spec.md" "Implemented in") — the run status lives outside the repository"
      else
        ev_note="no Implemented in:, nothing to name the run"
      fi
      ;;
    acceptance)
      if [ -n "$(gm_header "$d/acceptance.md" Verdict)" ]; then
        ev_state=done; ev_note="Verdict: $(gm_header "$d/acceptance.md" Verdict)"
      else
        ev_note="no Verdict: line in acceptance.md"
      fi
      ;;
    memory)
      if [ "$(gm_header "$d/spec.md" Status)" = implemented ] &&
         [ -n "$(gm_header "$d/spec.md" "Implemented in")" ]; then
        ev_state=done; ev_note="implemented, $(gm_header "$d/spec.md" "Implemented in")"
      else
        ev_note="not yet Status: implemented with an Implemented in: line"
      fi
      ;;
  esac
}

# --- one feature ---------------------------------------------------------------

gaps=0

report_feature() { # dir
  local d=${1%/} slug num addr title stage status here i st box colour note
  slug=$(basename "$d")
  num=${slug%%-*}
  slug=${slug#*-}
  addr="F:$(basename "$d")"
  title=$(gm_title "$d/spec.md")
  stage=$(gm_header "$d/spec.md" Stage)
  status=$(gm_header "$d/spec.md" Status)
  here=$(stage_index "$stage")

  case "$format" in
    text)
      printf '%s%s%s  %s\n' "$c_hd" "$addr" "$c_off" "${title:-untitled}"
      printf '%sStage: %s · Status: %s · %s%s\n\n' \
        "$c_dim" "${stage:-—}" "${status:-—}" "$d/" "$c_off"
      ;;
    md)
      printf '### %s — %s\n\n' "$addr" "${title:-untitled}"
      printf '`Stage: %s` · `Status: %s`\n\n' "${stage:-—}" "${status:-—}"
      ;;
  esac

  [ "$format" = json ] && printf '  {"address":"%s","title":"%s","stage":"%s","status":"%s","stages":[' \
    "$(json_escape "$addr")" "$(json_escape "$title")" \
    "$(json_escape "$stage")" "$(json_escape "$status")"

  i=0
  for st in $stages; do
    evidence_for "$st" "$d" "$slug"
    note=$ev_note

    # position vs evidence — the whole point of the script
    if [ "$here" -lt 0 ]; then
      box="?"; colour=$c_dim
      note="stage '$stage' is not in the vocabulary; evidence not matched"
    elif [ "$i" -eq "$here" ]; then
      box=">"; colour=$c_now
    elif [ "$i" -gt "$here" ]; then
      box=" "; colour=$c_dim
      note=""
    elif [ "$ev_state" = done ]; then
      box="x"; colour=$c_done
    elif [ "$ev_state" = skip ]; then
      box="-"; colour=$c_dim
    elif [ "$ev_state" = external ]; then
      box="?"; colour=$c_dim
    else
      box="!"; colour=$c_gap
      gaps=$((gaps + 1))
    fi

    case "$format" in
      text)
        if [ -n "$note" ]; then
          printf '  %s[%s]%s %-11s %s%s%s\n' "$colour" "$box" "$c_off" "$st" "$c_dim" "$note" "$c_off"
        else
          printf '  %s[%s]%s %-11s\n' "$colour" "$box" "$c_off" "$st"
        fi
        ;;
      md)
        case "$box" in
          x) printf -- '- [x] **%s** — %s\n' "$st" "$note" ;;
          '!') printf -- '- [ ] **%s** ⚠️ passed with no evidence — %s\n' "$st" "$note" ;;
          '>') printf -- '- [ ] **%s** <- current%s\n' "$st" "${note:+ — $note}" ;;
          -) printf -- '- [x] ~~%s~~ — %s\n' "$st" "$note" ;;
          # Quoted: a bare ? in a case pattern is a single-character glob and
          # would swallow every other box, including the empty one.
          '?') printf -- '- [ ] **%s** — %s\n' "$st" "$note" ;;
          *) printf -- '- [ ] %s\n' "$st" ;;
        esac
        ;;
      json)
        [ "$i" -gt 0 ] && printf ','
        printf '{"stage":"%s","box":"%s","evidence":"%s"}' \
          "$st" "$box" "$(json_escape "$note")"
        ;;
    esac
    i=$((i + 1))
  done

  case "$format" in
    text) printf '\n' ;;
    md)   printf '\n' ;;
    json) printf ']}' ;;
  esac
}

# --- cheatsheet, alone or above the checklist ----------------------------------

if [ "$sheet" -eq 1 ] && [ -z "$address" ]; then
  cheatsheet
  exit 0
fi

# --- selection -----------------------------------------------------------------

dirs=""
if [ -n "$address" ]; then
  # One resolver: address to path is git-memory-resolve.sh and nothing else
  # (docs/method/addressing.md). A bare slug is accepted as a convenience and
  # resolved by glob, not by parsing it as an address.
  resolved=""
  case "$address" in
    F:*)
      if [ -x scripts/git-memory-resolve.sh ] || [ -r scripts/git-memory-resolve.sh ]; then
        resolved=$(bash scripts/git-memory-resolve.sh "$address" 2>/dev/null)
      fi
      [ -n "$resolved" ] || die "address does not resolve: $address" "try scripts/git-memory-resolve.sh --all"
      ;;
    *)
      for d in specs/[0-9][0-9][0-9]-*/; do
        case "$(basename "$d")" in
          *"$address"*) resolved=$d; break ;;
        esac
      done
      [ -n "$resolved" ] || die "no feature matches '$address'" "give a slug fragment or an F: address"
      ;;
  esac
  dirs=$resolved
else
  for d in specs/[0-9][0-9][0-9]-*/; do
    [ -f "$d/spec.md" ] || continue
    if [ "$want_all" -eq 0 ]; then
      [ "$(gm_header "$d/spec.md" Stage)" = memory ] &&
        [ "$(gm_header "$d/spec.md" Status)" = implemented ] && continue
    fi
    dirs="$dirs $d"
  done
fi

if [ -z "${dirs// /}" ]; then
  case "$format" in
    json) printf '{"features":[]}\n' ;;
    *)    printf 'No unfinished features. Everything in specs/ has reached stage memory.\n' ;;
  esac
  exit 0
fi

# --- print ---------------------------------------------------------------------

# --cheatsheet with an address: the same table, with an arrow on the stage that
# feature is actually on. Documented in --help, so it has to behave that way.
if [ "$sheet" -eq 1 ]; then
  cur=""
  for d in $dirs; do
    cur=$(gm_header "${d%/}/spec.md" Stage)
    break
  done
  cheatsheet "$cur"
  exit 0
fi

[ "$format" = json ] && printf '{"features":[\n'
first=1
for d in $dirs; do
  if [ "$format" = json ]; then
    [ "$first" -eq 0 ] && printf ',\n'
    first=0
  fi
  report_feature "$d"
done
[ "$format" = json ] && printf '\n]}\n'

if [ "$format" = text ] && [ "$gaps" -gt 0 ]; then
  printf '%s%d stage(s) passed with no evidence - the [!] lines%s\n' "$c_gap" "$gaps" "$c_off"
fi

[ "$strict" -eq 1 ] && [ "$gaps" -gt 0 ] && exit 1
exit 0
