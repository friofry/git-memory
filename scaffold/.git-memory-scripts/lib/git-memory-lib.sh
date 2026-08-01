# shellcheck shell=bash
#
# Shared readers for node headers (see docs/method/addressing.md and
# docs/memory.md). Sourced, never executed.
#
# There is one implementation of "read Key: off a node file" and this is it.
# Four separate readers existed before, and only one of them skipped fenced
# code blocks — so a spec.md carrying a fenced *example* header made three of
# the four scripts report the example as the real value. A node header is the
# load-bearing fact in this system; it gets one parser, for the same reason an
# address gets one resolver.
#
# Every caller runs from the repository root, so source this as
#   . .git-memory-scripts/lib/git-memory-lib.sh
# after the usual cd "$(dirname "$0")/..".

# --- 1. one header field -------------------------------------------------------

# gm_header <file> <key>  ->  the first value, or nothing
#
# One awk pass per call rather than a sed|head|tr|sed chain: the old readers
# forked four processes per field and were called seven times per node, which
# is most of a minute on a repository with a few hundred tickets.
#
# It honours, in this order:
#   - a trailing CR, so a CRLF checkout reads the same as an LF one. Without
#     this a Windows or WSL clone silently loses the whole M: family and emits
#     diagnostics that reject a value while naming it as one of the accepted.
#   - fenced code blocks, which is where example headers live.
#   - HTML comments, which is where template guidance lives.
#   - the legacy bold "**Key:** value" form that upstream /to-tickets writes.
gm_header() {
  [ -f "$1" ] || return 0
  awk -v key="$2" '
    { sub(/\r$/, "") }
    /^```/          { fenced = !fenced; next }
    fenced          { next }
    /<!--/          { if (!/-->/) { commented = 1 }; next }
    commented       { if (/-->/) { commented = 0 }; next }
    {
      bold  = "**" key ":**"
      plain = key ":"
      if (substr($0, 1, length(bold)) == bold) {
        v = substr($0, length(bold) + 1)
      } else if (substr($0, 1, length(plain)) == plain) {
        v = substr($0, length(plain) + 1)
      } else {
        next
      }
      gsub(/^[ \t]+/, "", v)
      gsub(/[ \t]+$/, "", v)
      print v
      exit
    }
  ' "$1" 2>/dev/null
}

# --- 2. a comma-separated header field -----------------------------------------

# gm_header_list <file> <key>  ->  one item per line, trimmed, empties dropped
#
# An empty "Refs:" line and a missing one mean the same thing — nothing to say —
# and both come back empty.
gm_header_list() {
  gm_header "$1" "$2" | tr ',' '\n' | awk '
    { gsub(/^[ \t]+/, ""); gsub(/[ \t]+$/, ""); if ($0 != "") print }
  '
}

# --- 3. a document title -------------------------------------------------------

# gm_title <file>  ->  the first level-one heading
#
# Anchored at "# " with exactly one hash: "sed -n 's/^# *//p'" matched an ATX
# heading at any level and did not skip fences, so a title could come back as a
# sub-heading, or as a shell comment quoted inside a code block.
gm_title() {
  [ -f "$1" ] || return 0
  awk '
    { sub(/\r$/, "") }
    /^```/ { fenced = !fenced; next }
    fenced { next }
    /^# /  { sub(/^# */, ""); gsub(/[ \t]+$/, ""); print; exit }
  ' "$1" 2>/dev/null
}

# --- 4. the stage vocabulary ---------------------------------------------------

# gm_stage_is_known <value>  ->  exit 0 if it is one of the twelve stages
#
# docs/agents/delivery-workflow.md owns the vocabulary; this is its executable
# copy and the doc wins on any disagreement. It lives here because it existed
# verbatim in two scripts, and a closed set that is written down twice is a
# closed set that will eventually be written down differently.
gm_stage_is_known() {
  case "$1" in
    request|research|spec|approval|plan|build|checks|review|rework|ci|acceptance|memory) return 0 ;;
    *) return 1 ;;
  esac
}

# --- 5. a content hash ---------------------------------------------------------

# gm_sha256  ->  reads stdin, prints the hex digest, or exits non-zero
#
# macOS ships no sha256sum; it ships shasum. The vendored-skill tamper check
# used sha256sum unconditionally, so on a Mac it produced an empty manifest —
# and then --fix wrote that empty manifest over .agents/skills.sha256,
# destroying the baseline the check exists to compare against.
gm_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256
  elif command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 -r
  else
    return 1
  fi
}

# gm_have_sha256  ->  exit 0 if any hashing tool is available
gm_have_sha256() {
  command -v sha256sum >/dev/null 2>&1 ||
    command -v shasum >/dev/null 2>&1 ||
    command -v openssl >/dev/null 2>&1
}
