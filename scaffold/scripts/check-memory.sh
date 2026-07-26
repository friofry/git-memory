#!/usr/bin/env bash
#
# Consistency checks for the layered project memory (see docs/memory.md).
#
#   scripts/check-memory.sh         report violations, non-zero exit on failure
#   scripts/check-memory.sh --fix   regenerate derived blocks, then report
#
set -uo pipefail
shopt -s nullglob

cd "$(dirname "$0")/.." || exit 1

FIX=0
[ "${1:-}" = "--fix" ] && FIX=1

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

stage_is_known() {
  case "$1" in
    request|research|spec|approval|plan|build|checks|review|rework|ci|acceptance|memory) return 0 ;;
    *) return 1 ;;
  esac
}

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
  for f in CONTEXT.md $(find docs/domain docs/adr -name '*.md' 2>/dev/null | sort); do
    [ -f "$f" ] || continue
    if grep -qE '\]\([^)]*(specs/|\.scratch/)' "$f"; then
      err "stable layer links into volatile layer: $f (see docs/memory.md rule 2)"
      bad=$((bad + 1))
    fi
  done
  [ "$bad" -eq 0 ] && ok "CONTEXT.md, docs/domain and docs/adr do not link into specs/ or .scratch/"
}

# --- 6. every .scratch feature folder has a canonical spec ---------------------

check_scratch_orphans() {
  local bad=0 d slug
  [ -d .scratch ] || { ok ".scratch/ absent (nothing to check)"; return; }
  for d in .scratch/*/; do
    [ -d "$d" ] || continue
    slug=$(basename "$d")
    if ! ls -d specs/[0-9][0-9][0-9]-"$slug"/ >/dev/null 2>&1; then
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
  find .agents/skills -type f 2>/dev/null | sort | xargs -r sha256sum
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

echo
if [ "$failures" -gt 0 ]; then
  printf '%d memory consistency failure(s)\n' "$failures"
  exit 1
fi
echo 'memory is consistent'
