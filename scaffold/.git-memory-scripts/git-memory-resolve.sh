#!/usr/bin/env bash
#
# Address to path — the only address parser in this system (see docs/method/addressing.md).
#
#   .git-memory-scripts/git-memory-resolve.sh F:007-auth-envelope   print the repo-relative path
#   .git-memory-scripts/git-memory-resolve.sh --check T:007/03      silent; exit 0 if it resolves
#   .git-memory-scripts/git-memory-resolve.sh --print M:gate-approval  print only that section
#   .git-memory-scripts/git-memory-resolve.sh --all                 print every address and its path
#   .git-memory-scripts/git-memory-resolve.sh --help                usage, exit 0
#
set -uo pipefail
shopt -s nullglob

cd "$(dirname "$0")/.." || exit 1

self=$(basename "$0")

# --check wants a yes/no, not a reason. Everything else wants the reason.
quiet=0

usage() {
  cat <<'EOF'
usage: git-memory-resolve.sh <address>
       git-memory-resolve.sh resolve <address>
       git-memory-resolve.sh --check <address>
       git-memory-resolve.sh --print <address>
       git-memory-resolve.sh --all
       git-memory-resolve.sh --help

Resolve one address to the repo-relative path it names. The path is the truth and
the address is a projection of it, so every resolution is a directory scan and
never a lookup in a table someone maintains. The rules live in
docs/method/addressing.md; this script only enforces them.

  F:007-auth-envelope   specs/007-auth-envelope/
  T:007/03              .scratch/auth-envelope/issues/03-envelope-schema.md
  S:007/proto-a         spikes/auth-envelope/proto-a/
  ADR:0012              docs/adr/0012-signed-auth-envelope.md
  TERM:event-envelope   CONTEXT.md#event-envelope
  M:gate-approval       docs/method/gates.md#mgate-approval

T: and S: carry the feature number, not its slug, so the resolver reads the slug
off specs/<NN>-*/ on every resolution and a renamed feature invalidates nothing.

  --check    print nothing; exit 0 if the address resolves, 1 if it does not.
  --print    print the section the address names, not the file that contains it.
             An address resolves to "path#anchor" and a reader that then opens
             the whole file pays for the file to quote one heading of it:
             docs/method/gates.md is six times the size of the one gate an
             M: address names. The section runs from its heading to the next
             heading at the same level or higher, so sub-headings come with it.
             An address naming a directory prints the path; one with no anchor
             prints the file.
  --all      print "<address><TAB><path>" for every address the repository
             declares, in all six families, features first and each feature
             followed by its tickets and spikes. This is the address index other
             scripts read instead of parsing addresses themselves.

A TERM: address is a level-2 heading in CONTEXT.md, addressed by its GitHub anchor.
An M: address is a heading anywhere under docs/method/ whose text is the address in
backticks; two declarations of one address is a failure, not a tie to break.
Headings inside a fenced block or an HTML comment are examples, not declarations.

Exit status: 0 resolved, 1 unresolvable or ambiguous. An unresolvable address
prints one diagnostic line on stderr naming the address, its family, and the glob
or file that came back empty.
EOF
}

# One line, on stderr, and never more than one: a caller looping over a Refs: line
# needs to read the failures, not scroll them.
diag() {
  [ "$quiet" -eq 1 ] && return 0
  printf '%s: %s (%s) does not resolve: %s\n' "$self" "$1" "$2" "$3" >&2
}

# --- 1. headings, with the examples stripped out -------------------------------
# TERM: and M: are declared by headings, and templates/, the boilerplates and this
# file's own usage block are full of headings that are illustrations. A heading
# inside a fenced block or an HTML comment declares nothing.

headings() {
  awk '
    # Strip the CR first. Without this a CRLF checkout leaves one inside every
    # heading, the backtick-anchored M: match fails, and the entire M: family
    # silently disappears from the index — on Windows, WSL, or any clone with
    # core.autocrlf=true.
    { sub(/\r$/, "") }
    /^```/    { fenced = !fenced; next }
    fenced    { next }
    # A comment that opens and closes on one line must not swallow the lines
    # after it, and a heading carrying a trailing comment is still a heading.
    /<!--/    { if (!/-->/) { commented = 1 }; next }
    commented { if (/-->/) { commented = 0 }; next }
    /^#+[ \t]*[^ \t]/ {
      match($0, /^#+/)
      level = RLENGTH
      text = $0
      sub(/^#+[ \t]*/, "", text)
      sub(/[ \t]*$/, "", text)
      # GitHub anchor: lower-case, drop everything that is not alphanumeric,
      # space, underscore or hyphen, then spaces become hyphens. That is what
      # turns `M:gate-approval` into mgate-approval.
      anchor = tolower(text)
      gsub(/[^a-z0-9 _-]/, "", anchor)
      gsub(/ /, "-", anchor)
      if (anchor != "") printf "%s\t%s\t%s\n", level, text, anchor
    }
  ' "$1"
}

# "<anchor>\t<path#anchor>" for every term. Level 2 only: the file title is not a
# term, and a glossary whose H1 answered to TERM: would put "TERM:glossary" in the
# address index of every repository.
term_declarations() {
  [ -f CONTEXT.md ] || return 0
  headings CONTEXT.md | awk -F'\t' '$1 == 2 { printf "%s\tCONTEXT.md#%s\n", $3, $3 }'
}

# "<address>\t<path#anchor>" for every method ref, at any heading level: gates.md
# declares at level 2, each boilerplate declares at level 1 in its own file.
method_declarations() {
  local f
  [ -d docs/method ] || return 0
  while IFS= read -r f; do
    headings "$f" | awk -F'\t' -v path="$f" '
      $2 ~ /^`M:[^`]+`$/ {
        addr = substr($2, 2, length($2) - 2)
        printf "%s\t%s#%s\n", addr, path, $3
      }'
  done < <(find docs/method -type f -name '*.md' 2>/dev/null | sort)
}

# --- 2. the feature lookup every T: and S: address goes through ----------------
# Rule 2 of docs/method/addressing.md: a ticket and spike address carries the
# feature's number, so the slug is read off the filesystem on every resolution.

feature_dir() {
  local num=$1 addr=$2 family=$3
  local d hits="" n=0
  for d in specs/"$num"-*/; do
    hits="$hits$d"$'\n'
    n=$((n + 1))
  done
  if [ "$n" -eq 0 ]; then
    diag "$addr" "$family" "no directory matches specs/$num-*/"
    return 1
  fi
  if [ "$n" -gt 1 ]; then
    diag "$addr" "$family" "specs/$num-*/ matches $n directories ($(printf '%s' "$hits" | tr '\n' ' ' | sed 's/ $//')); two features cannot share a number"
    return 1
  fi
  printf '%s\n' "${hits%$'\n'}"
}

# The slug is whatever follows the number in the matched directory name.
slug_of() {
  local dir=$1 num=$2 slug
  slug=${dir#specs/$num-}
  printf '%s\n' "${slug%/}"
}

# --- 3. one resolver per family ------------------------------------------------

resolve_feature() {
  local addr=$1 body num want dir have
  body=${addr#F:}
  num=${body%%-*}
  want=${body#*-}
  case "$num" in
    ''|*[!0-9]*) diag "$addr" feature "expected F:<NN>-<slug> with a numeric number"; return 1 ;;
  esac
  if [ "$want" = "$body" ] || [ -z "$want" ]; then
    diag "$addr" feature "expected F:<NN>-<slug>, for example F:007-auth-envelope"
    return 1
  fi
  dir=$(feature_dir "$num" "$addr" feature) || return 1
  have=$(slug_of "$dir" "$num")
  # A slug disagreement means the feature was renamed and this reference was not.
  # Report both strings; guessing which one is current is how a reference silently
  # starts pointing at the wrong feature.
  if [ "$have" != "$want" ]; then
    diag "$addr" feature "feature $num is '$have', not '$want' ($dir)"
    return 1
  fi
  printf '%s\n' "$dir"
}

resolve_ticket() {
  local addr=$1 body num mm dir slug f hits="" n=0
  body=${addr#T:}
  num=${body%%/*}
  mm=${body#*/}
  if [ "$mm" = "$body" ]; then
    diag "$addr" ticket "expected T:<NN>/<MM>, for example T:007/03"
    return 1
  fi
  case "$num" in ''|*[!0-9]*) diag "$addr" ticket "feature number '$num' is not numeric"; return 1 ;; esac
  case "$mm" in ''|*[!0-9]*) diag "$addr" ticket "ticket number '$mm' is not numeric"; return 1 ;; esac
  dir=$(feature_dir "$num" "$addr" ticket) || return 1
  slug=$(slug_of "$dir" "$num")
  for f in ".scratch/$slug/issues/$mm"-*.md; do
    hits="$hits$f"$'\n'
    n=$((n + 1))
  done
  if [ "$n" -eq 0 ]; then
    diag "$addr" ticket "no file matches .scratch/$slug/issues/$mm-*.md"
    return 1
  fi
  if [ "$n" -gt 1 ]; then
    diag "$addr" ticket "two tickets are numbered $mm ($(printf '%s' "$hits" | tr '\n' ' ' | sed 's/ $//')); renumber the later one and fix its ID: line"
    return 1
  fi
  printf '%s\n' "${hits%$'\n'}"
}

resolve_spike() {
  local addr=$1 body num name dir slug
  body=${addr#S:}
  num=${body%%/*}
  name=${body#*/}
  if [ "$name" = "$body" ]; then
    diag "$addr" spike "expected S:<NN>/<name>, for example S:007/proto-a"
    return 1
  fi
  case "$num" in ''|*[!0-9]*) diag "$addr" spike "feature number '$num' is not numeric"; return 1 ;; esac
  case "$name" in ''|*/*) diag "$addr" spike "spike name '$name' is empty or holds a slash"; return 1 ;; esac
  dir=$(feature_dir "$num" "$addr" spike) || return 1
  slug=$(slug_of "$dir" "$num")
  # The address names the directory. A directory with no README.md still resolves;
  # the missing node file is a check-memory.sh failure, not a resolution failure.
  if [ ! -d "spikes/$slug/$name" ]; then
    diag "$addr" spike "spikes/$slug/$name/ is not a directory"
    return 1
  fi
  printf '%s\n' "spikes/$slug/$name/"
}

resolve_adr() {
  local addr=$1 num f hits="" n=0
  num=${addr#ADR:}
  # Zero padding is not cosmetic: it is what makes docs/adr/<NNNN>-*.md a single
  # unambiguous glob, so ADR:12 is rejected rather than guessed at.
  case "$num" in
    [0-9][0-9][0-9][0-9]) ;;
    *) diag "$addr" adr "expected four zero-padded digits, for example ADR:0012"; return 1 ;;
  esac
  for f in docs/adr/"$num"-*.md; do
    hits="$hits$f"$'\n'
    n=$((n + 1))
  done
  if [ "$n" -eq 0 ]; then
    diag "$addr" adr "no file matches docs/adr/$num-*.md"
    return 1
  fi
  if [ "$n" -gt 1 ]; then
    diag "$addr" adr "docs/adr/$num-*.md matches $n files ($(printf '%s' "$hits" | tr '\n' ' ' | sed 's/ $//')); an ADR number is never reused"
    return 1
  fi
  printf '%s\n' "${hits%$'\n'}"
}

resolve_term() {
  local addr=$1 want hit
  want=${addr#TERM:}
  if [ ! -f CONTEXT.md ]; then
    diag "$addr" term "CONTEXT.md does not exist"
    return 1
  fi
  # First match wins, because GitHub anchors the first heading and suffixes every
  # later collision; picking any other one would link somewhere the reader's
  # browser does not go.
  hit=$(term_declarations | awk -F'\t' -v a="$want" '$1 == a { print $2; exit }')
  if [ -z "$hit" ]; then
    diag "$addr" term "no level-2 heading in CONTEXT.md has the anchor '$want'"
    return 1
  fi
  printf '%s\n' "$hit"
}

resolve_method() {
  local addr=$1 hits n
  if [ ! -d docs/method ]; then
    diag "$addr" method "docs/method/ does not exist"
    return 1
  fi
  hits=$(method_declarations | awk -F'\t' -v a="$addr" '$1 == a { print $2 }')
  n=$(printf '%s' "$hits" | grep -c . )
  if [ "$n" -eq 0 ]; then
    diag "$addr" method "no heading under docs/method/ reads \`$addr\`"
    return 1
  fi
  # Two declarations is a failure, not a tie to break: keeping two copies in sync
  # is the duplication the method layer exists to remove.
  if [ "$n" -gt 1 ]; then
    diag "$addr" method "declared $n times ($(printf '%s' "$hits" | tr '\n' ' ' | sed 's/ $//')); delete one, do not keep both in sync"
    return 1
  fi
  printf '%s\n' "$hits"
}

resolve_address() {
  local addr=$1
  case "$addr" in
    F:*)    resolve_feature "$addr" ;;
    T:*)    resolve_ticket  "$addr" ;;
    S:*)    resolve_spike   "$addr" ;;
    ADR:*)  resolve_adr     "$addr" ;;
    TERM:*) resolve_term    "$addr" ;;
    M:*)    resolve_method  "$addr" ;;
    *)
      diag "$addr" unknown "no family prefix; expected one of F: T: S: ADR: TERM: M:"
      return 1
      ;;
  esac
}

# --- 4. the address index ------------------------------------------------------
# Derived from the filesystem in one pass, because the path is the truth. Features
# first, each followed by its own tickets and spikes, then ADRs, terms and method
# refs — so a caller reading this stream sees a parent before its children.

list_all() {
  local d num slug f mm n s name
  for d in specs/[0-9]*-*/; do
    [ -f "$d/spec.md" ] || continue
    num=${d#specs/}
    num=${num%%-*}
    case "$num" in ''|*[!0-9]*) continue ;; esac
    slug=$(slug_of "$d" "$num")
    printf 'F:%s-%s\t%s\n' "$num" "$slug" "$d"
    for f in ".scratch/$slug/issues/"[0-9]*-*.md; do
      mm=${f##*/}
      mm=${mm%%-*}
      case "$mm" in ''|*[!0-9]*) continue ;; esac
      printf 'T:%s/%s\t%s\n' "$num" "$mm" "$f"
    done
    for s in "spikes/$slug/"*/; do
      name=${s#spikes/$slug/}
      name=${name%/}
      printf 'S:%s/%s\t%s\n' "$num" "$name" "$s"
    done
  done
  for f in docs/adr/[0-9][0-9][0-9][0-9]-*.md; do
    n=${f#docs/adr/}
    n=${n%%-*}
    printf 'ADR:%s\t%s\n' "$n" "$f"
  done
  term_declarations | while IFS= read -r n; do printf 'TERM:%s\n' "$n"; done
  method_declarations
}

# --- 4b. printing what an address points at ------------------------------------

# An address resolves to "path#anchor", and a reader that then opens the whole
# file pays for the file to quote one section of it. docs/method/gates.md is
# 2.7k tokens; M:gate-approval is 0.5k of that. Ten citations a session is the
# difference between 5k and 27k spent on the same content.
#
# The anchor rule is not restated here: the heading is matched by running the
# same headings() pass that built the index, so a change to how an anchor is
# computed cannot make --print and resolve disagree.
print_address() { # address
  local target file anchor level found
  target=$(resolve_address "$1") || return 1
  file=${target%%#*}
  case "$target" in
    *\#*) anchor=${target#*\#} ;;
    *)    anchor="" ;;
  esac

  # A directory address (a feature, a spike) has no section to cut out; naming
  # the path is the whole answer, and printing a folder is not.
  if [ -d "$file" ]; then
    printf '%s\n' "$target"
    return 0
  fi
  if [ -z "$anchor" ]; then
    cat "$file"
    return 0
  fi

  # The level of the heading that owns this anchor, from the same index.
  level=$(headings "$file" | awk -F'\t' -v a="$anchor" '$3 == a { print $1; exit }')
  if [ -z "$level" ]; then
    diag "anchor '$anchor' is not a heading in $file" \
      "the index and the file disagree; re-run --check on this address"
    return 1
  fi

  awk -v want="$anchor" -v lvl="$level" '
    { sub(/\r$/, "") }
    /^```/ { fenced = !fenced; if (inside) print; next }
    fenced { if (inside) print; next }
    /^#+[ \t]*[^ \t]/ {
      match($0, /^#+/)
      here = RLENGTH
      text = $0
      sub(/^#+[ \t]*/, "", text)
      sub(/[ \t]*$/, "", text)
      anchor = tolower(text)
      gsub(/[^a-z0-9 _-]/, "", anchor)
      gsub(/ /, "-", anchor)
      if (anchor == want) { inside = 1; print; next }
      # Stop at the next heading at the same level or higher: a sub-heading
      # belongs to the section, a sibling starts a different one.
      if (inside && here <= lvl) { exit }
    }
    inside { print }
  ' "$file"
}

# --- 5. dispatch ---------------------------------------------------------------

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  '')
    usage >&2
    exit 1
    ;;
  --all)
    if [ "$#" -ne 1 ]; then
      printf '%s: --all takes no further arguments\n' "$self" >&2
      exit 1
    fi
    list_all
    exit 0
    ;;
  --print)
    shift
    if [ "$#" -ne 1 ]; then
      printf '%s: --print takes exactly one address\n' "$self" >&2
      exit 1
    fi
    print_address "$1"
    exit $?
    ;;
  --check)
    shift
    quiet=1
    if [ "$#" -ne 1 ]; then
      printf '%s: --check takes exactly one address\n' "$self" >&2
      exit 1
    fi
    resolve_address "$1" >/dev/null
    exit $?
    ;;
  resolve)
    # The documented long form. Every skill and template in the scaffold writes
    # `git-memory-resolve.sh resolve <address>`; the bare form is the same call.
    shift
    if [ "$#" -ne 1 ]; then
      printf '%s: resolve takes exactly one address\n' "$self" >&2
      exit 1
    fi
    resolve_address "$1"
    exit $?
    ;;
  -*)
    printf '%s: unknown option %s (try --help)\n' "$self" "$1" >&2
    exit 1
    ;;
  *)
    if [ "$#" -ne 1 ]; then
      printf '%s: takes exactly one address\n' "$self" >&2
      exit 1
    fi
    resolve_address "$1"
    exit $?
    ;;
esac
