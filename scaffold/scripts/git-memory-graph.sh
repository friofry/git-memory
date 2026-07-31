#!/usr/bin/env bash
#
# The work graph, projected from specs/, .scratch/ and spikes/ (see docs/method/addressing.md).
#
#   scripts/git-memory-graph.sh                one JSON object per node, on stdout
#   scripts/git-memory-graph.sh --format md    a tree grouped by feature
#   scripts/git-memory-graph.sh --format dot   a graphviz digraph
#   scripts/git-memory-graph.sh --help         usage, exit 0
#
set -uo pipefail

here=$(cd "$(dirname "$0")" && pwd) || exit 1
cd "$here/.." || exit 1

self=$(basename "$0")
resolver="$here/git-memory-resolve.sh"

# Field separator for the internal node table. Not a tab: bash treats tab as IFS
# whitespace, so "a<tab><tab>b" would read back as two fields and every absent
# header value would shift the record one column left. US (0x1F) is not IFS
# whitespace, so an empty column stays an empty column.
us=$(printf '\037')
tab=$(printf '\t')
cr=$(printf '\r')

format=ndjson

usage() {
  cat <<'EOF'
usage: git-memory-graph.sh [--format ndjson|md|dot]
       git-memory-graph.sh --help

Print the work graph — every feature, ticket and spike the repository declares,
with the edges between them — on stdout. Nothing is written: the graph is a
projection of files that change on every commit, so it is computed on demand and
never committed (see docs/method/addressing.md).

  --format ndjson   one JSON object per line, fields id, type, status, stage,
                    parent, children, blocked_by, refs, path. An absent header
                    line is null, never "" and never []. Default.
  --format md       a tree grouped by feature: the feature, then its tickets and
                    spikes indented under it, then a one-line count.
  --format dot      a graphviz digraph. Parent edges are solid; blocked-by edges
                    are dashed and red. Fill colour is the node's Type:.
                    Render with: git-memory-graph.sh --format dot | dot -Tsvg

Addresses come from scripts/git-memory-resolve.sh --all, which is the only
address parser in the system; this script parses none itself. Node order is the
resolver's: each feature followed by its own tickets and spikes.

A repository with no specs prints nothing and exits 0. That is an empty graph,
not an error — a scaffold installed yesterday has no work in it yet.

Header values are read as written. A ticket carrying a Stage: line, a Type:
outside the closed set, or a Blocked by: address that resolves to nothing all
appear here unchanged; reporting them is scripts/check-memory.sh's job, and a
graph that silently repaired them would hide the failure it exists to expose.
EOF
}

# --- 1. reading a node header --------------------------------------------------
# Plain `Key: value` lines at the top of the file, extracted with the same sed
# idiom the rest of the scaffold uses (docs/memory.md). First match wins, so a
# `Refs:` line quoted later in the body cannot displace the real header.
#
# The bold form `**Key:** value` is read too, because tickets written before this
# version of the scaffold use it and check-memory.sh already accepts it for
# labels. A v1 repository has no ID:, Type: or Parent: lines at all; it projects
# as a graph of nulls with real statuses and stages, which is what it is.

header_value() {
  local file=$1 key=$2
  [ -f "$file" ] || return 0
  sed -n -e "s/^$key:[[:space:]]*//p" -e "s/^\\*\\*$key:\\*\\*[[:space:]]*//p" \
    "$file" 2>/dev/null |
    head -1 |
    tr "$tab$cr$us" '   ' |
    sed -e 's/[[:space:]]*$//'
}

# A comma-separated header line, one item per output line, trimmed, empties
# dropped. An empty `Refs:` line and a missing one mean the same thing — nothing
# to say — and both come back empty here.
split_list() {
  printf '%s\n' "$1" |
    tr ',' '\n' |
    sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' |
    grep -v '^[[:space:]]*$'
}

# --- 2. JSON escaping ----------------------------------------------------------
# Every emitted string goes through this. A ticket title or a Refs: line holding
# a double quote must not corrupt the line it sits on, and a consumer reading the
# stream with a real JSON parser is the point of the format.

json_string() {
  case "$1" in
    *\\*|*\"*|*[[:cntrl:]]*)
      # The slow path forks awk. It is reached only by a value that actually
      # holds a backslash, a quote or a control character.
      printf '%s\n' "$1" | awk '
        BEGIN { for (i = 1; i < 256; i++) ord[sprintf("%c", i)] = i; out = "" }
        {
          if (NR > 1) out = out "\\n"
          n = length($0)
          for (i = 1; i <= n; i++) {
            c = substr($0, i, 1)
            k = ord[c]
            if (c == "\\")            { out = out "\\\\"; continue }
            if (c == "\"")            { out = out "\\\""; continue }
            # k is empty for a multibyte character in a character-aware awk, and
            # such a character needs no escape; pass it through untouched.
            if (k == 0 || k >= 32)    { out = out c; continue }
            if (c == "\b")            { out = out "\\b"; continue }
            if (c == "\f")            { out = out "\\f"; continue }
            if (c == "\r")            { out = out "\\r"; continue }
            if (c == "\t")            { out = out "\\t"; continue }
            out = out sprintf("\\u%04x", k)
          }
        }
        END { printf "\"%s\"", out }
      '
      ;;
    *) printf '"%s"' "$1" ;;
  esac
}

json_or_null() {
  if [ -z "$1" ]; then printf 'null'; else json_string "$1"; fi
}

# A comma-separated header line as a JSON array. Absent means null, so a consumer
# can tell "this node declares no blockers" from "this node was never asked".
json_array_or_null() {
  local items first=1 item
  items=$(split_list "$1")
  if [ -z "$items" ]; then
    printf 'null'
    return
  fi
  printf '['
  while IFS= read -r item; do
    [ "$first" -eq 1 ] || printf ','
    first=0
    json_string "$item"
  done <<EOF
$items
EOF
  printf ']'
}

# --- 3. the node table ---------------------------------------------------------
# One record per node, in the resolver's own order: each feature followed by its
# tickets and its spikes. The family prefix picks the node file inside the path
# the resolver already returned; no address is taken apart here.
#
# Columns: id, kind, feature, type, status, stage, parent, children, blocked_by,
# refs, path.

collect_nodes() {
  local addr path file kind feature="" type status stage parent children blocked refs
  while IFS="$tab" read -r addr path; do
    [ -n "$addr" ] || continue
    case "$addr" in
      F:*) kind=feature; feature=$addr; file="${path}spec.md" ;;
      T:*) kind=ticket;              file="$path" ;;
      S:*) kind=spike;               file="${path}README.md" ;;
      *)   continue ;; # ADR:, TERM: and M: are things nodes reference, not nodes
    esac
    # A spike directory with no README.md still has an address and still belongs
    # in the graph. It comes out with every field null, which is exactly the
    # shape of the failure — see docs/method/addressing.md, "Globs and failure
    # modes".
    type=$(header_value "$file" 'Type')
    status=$(header_value "$file" 'Status')
    stage=$(header_value "$file" 'Stage')
    parent=$(header_value "$file" 'Parent')
    children=$(header_value "$file" 'Children')
    blocked=$(header_value "$file" 'Blocked by')
    refs=$(header_value "$file" 'Refs')
    # `Parent: none` on a top-level spec is the absence of a parent, spelled out.
    [ "$parent" = "none" ] && parent=""
    printf '%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s\n' \
      "$addr" "$us" "$kind" "$us" "$feature" "$us" "$type" "$us" "$status" "$us" \
      "$stage" "$us" "$parent" "$us" "$children" "$us" "$blocked" "$us" \
      "$refs" "$us" "$path"
  done < <("$resolver" --all)
}

records() {
  [ -n "$NODES" ] && printf '%s\n' "$NODES"
  return 0
}

# Membership test for an edge target. IDS carries every node address wrapped in
# newlines, so a T:007/1 address cannot match a T:007/10 node.
in_graph() {
  case "$IDS" in
    *"
$1
"*) return 0 ;;
  esac
  return 1
}

# --- 4. ndjson -----------------------------------------------------------------

emit_ndjson() {
  local id kind feature type status stage parent children blocked refs path
  while IFS="$us" read -r id kind feature type status stage parent children blocked refs path; do
    [ -n "$id" ] || continue
    printf '{"id":%s,"type":%s,"status":%s,"stage":%s,"parent":%s,"children":%s,"blocked_by":%s,"refs":%s,"path":%s}\n' \
      "$(json_or_null "$id")" \
      "$(json_or_null "$type")" \
      "$(json_or_null "$status")" \
      "$(json_or_null "$stage")" \
      "$(json_or_null "$parent")" \
      "$(json_array_or_null "$children")" \
      "$(json_array_or_null "$blocked")" \
      "$(json_array_or_null "$refs")" \
      "$(json_or_null "$path")"
  done < <(records)
}

# --- 5. md ---------------------------------------------------------------------

# "interface, ready-for-agent" from whatever of the two exists. A v1 node with no
# Type: line reads as its status alone rather than as a comma with a hole in it.
join_meta() {
  local out="" part
  for part in "$@"; do
    [ -n "$part" ] || continue
    if [ -z "$out" ]; then out=$part; else out="$out, $part"; fi
  done
  printf '%s' "$out"
}

plural() {
  if [ "$1" -eq 1 ]; then printf '%d %s' "$1" "$2"; else printf '%d %ss' "$1" "$2"; fi
}

emit_md() {
  local id kind feature type status stage parent children blocked refs path
  local meta open=0 nf=0 nt=0 ns=0 item sep
  printf '# Work graph\n\n'
  while IFS="$us" read -r id kind feature type status stage parent children blocked refs path; do
    [ -n "$id" ] || continue
    case "$kind" in
      feature)
        [ "$open" -eq 1 ] && printf '\n'
        open=1
        nf=$((nf + 1))
        meta=$(join_meta "$type" "$status" "${stage:+stage $stage}")
        printf -- '- **%s**' "$id"
        [ -n "$meta" ] && printf -- ' — %s' "$meta"
        printf -- ' — `%s`\n' "$path"
        ;;
      ticket|spike)
        if [ "$kind" = ticket ]; then nt=$((nt + 1)); else ns=$((ns + 1)); fi
        meta=$(join_meta "$type" "$status")
        printf -- '  - **%s**' "$id"
        [ -n "$meta" ] && printf -- ' — %s' "$meta"
        # Blockers are the one edge a reader of the tree cannot infer from the
        # indentation, so they are the one edge the tree spells out.
        if [ -n "$blocked" ]; then
          printf -- ' — blocked by '
          sep=''
          while IFS= read -r item; do
            printf '%s%s' "$sep" "$item"
            sep=', '
          done < <(split_list "$blocked")
        fi
        printf '\n'
        ;;
    esac
  done < <(records)
  printf '\n%s, %s, %s\n' \
    "$(plural "$nf" feature)" "$(plural "$nt" ticket)" "$(plural "$ns" spike)"
}

# --- 6. dot --------------------------------------------------------------------
# Fill colour is the Type: (docs/method/work-types.md); shape is the node kind.
# A value outside the closed set, or a node with no Type: line at all, comes out
# white — visibly different from all eleven, which is the point.

type_fill() {
  case "$1" in
    feature)        printf '#dbeafe' ;;
    bug)            printf '#fecaca' ;;
    research)       printf '#ddd6fe' ;;
    prototype)      printf '#fde68a' ;;
    architecture)   printf '#a5f3fc' ;;
    interface)      printf '#c7d2fe' ;;
    test)           printf '#bbf7d0' ;;
    implementation) printf '#e2e8f0' ;;
    review)         printf '#fbcfe8' ;;
    rework)         printf '#fed7aa' ;;
    memory)         printf '#f5d0fe' ;;
    *)              printf '#ffffff' ;;
  esac
}

kind_shape() {
  case "$1" in
    feature) printf 'box3d' ;;
    spike)   printf 'note' ;;
    *)       printf 'box' ;;
  esac
}

# A dot string literal escapes backslash and double quote and nothing else. The
# label separator is a literal backslash-n, appended after escaping so it is not
# escaped in turn.
dot_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

emit_dot() {
  local id kind feature type status stage parent children blocked refs path
  local label target item

  printf 'digraph work_graph {\n'
  printf '  graph [rankdir=LR];\n'
  printf '  node [shape=box, style=filled, fillcolor="#ffffff", fontsize=10];\n'
  printf '  edge [fontsize=9];\n\n'

  printf '  // nodes: fill colour is Type:, shape is feature / ticket / spike\n'
  while IFS="$us" read -r id kind feature type status stage parent children blocked refs path; do
    [ -n "$id" ] || continue
    label=$(dot_escape "$id")
    [ -n "$type" ] && label="$label\\n$(dot_escape "$type")"
    [ -n "$status" ] && label="$label\\n$(dot_escape "$status")"
    [ -n "$stage" ] && label="$label\\nstage $(dot_escape "$stage")"
    printf '  "%s" [label="%s", shape=%s, fillcolor="%s"];\n' \
      "$(dot_escape "$id")" "$label" "$(kind_shape "$kind")" "$(type_fill "$type")"
  done < <(records)

  printf '\n  // parent edges: solid, dark grey\n'
  while IFS="$us" read -r id kind feature type status stage parent children blocked refs path; do
    [ -n "$id" ] || continue
    # The header is the declaration and the path is the truth. When Parent: names
    # a node in this graph, draw that; otherwise fall back to the feature whose
    # folders this node lives in, so a missing or dangling Parent: line loses a
    # claim, not an edge.
    target=$parent
    if [ -z "$target" ] || ! in_graph "$target"; then
      target=$feature
    fi
    [ -n "$target" ] || continue
    [ "$target" = "$id" ] && continue
    in_graph "$target" || continue
    printf '  "%s" -> "%s" [color="#334155", style=solid];\n' \
      "$(dot_escape "$target")" "$(dot_escape "$id")"
  done < <(records)

  printf '\n  // blocked-by edges: dashed, red, and out of the ranking so a\n'
  printf '  // blocker does not drag its dependent across the page\n'
  while IFS="$us" read -r id kind feature type status stage parent children blocked refs path; do
    [ -n "$id" ] || continue
    [ -n "$blocked" ] || continue
    while IFS= read -r item; do
      in_graph "$item" || continue
      printf '  "%s" -> "%s" [color="#b91c1c", style=dashed, arrowhead=empty, constraint=false];\n' \
        "$(dot_escape "$id")" "$(dot_escape "$item")"
    done < <(split_list "$blocked")
  done < <(records)

  printf '}\n'
}

# --- 7. dispatch ---------------------------------------------------------------

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --format)
      shift
      if [ "$#" -eq 0 ]; then
        printf '%s: --format needs a value (ndjson, md or dot)\n' "$self" >&2
        exit 1
      fi
      format=$1
      ;;
    --format=*)
      format=${1#--format=}
      ;;
    *)
      printf '%s: unknown argument %s (try --help)\n' "$self" "$1" >&2
      exit 1
      ;;
  esac
  shift
done

case "$format" in
  ndjson|md|dot) ;;
  *)
    printf '%s: unknown format %s (expected ndjson, md or dot)\n' "$self" "$format" >&2
    exit 1
    ;;
esac

if [ ! -x "$resolver" ]; then
  printf '%s: %s is missing or not executable; it is the only address parser\n' \
    "$self" "$resolver" >&2
  exit 1
fi

NODES=$(collect_nodes)
IDS=$(records | cut -d"$us" -f1)
IDS="
$IDS
"

# No specs at all is an empty graph, not a failure: printing a header, an empty
# digraph or a "0 features" line would make a fresh scaffold look broken.
if [ -z "$NODES" ]; then
  exit 0
fi

case "$format" in
  ndjson) emit_ndjson ;;
  md)     emit_md ;;
  dot)    emit_dot ;;
esac
