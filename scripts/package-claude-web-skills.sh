#!/usr/bin/env bash
# Package git-memory + Matt Pocock skills as Claude Web upload zips.
#
# Claude.ai accepts one skill per ZIP:
#   skill-name.zip
#   └── skill-name/
#       └── SKILL.md   (+ optional resources)
#
# Repo skills are discovered from skills/ and scaffold/.cursor/skills/, so adding
# a skill needs no edit here. setup-git-memory additionally embeds scaffold/ —
# Claude Web is the one channel with no clone to copy seed bytes from — and that
# embedded copy is checked for the tool layer before anything is packed.
#
# Usage:
#   ./scripts/package-claude-web-skills.sh              # full Matt set
#   ./scripts/package-claude-web-skills.sh --set minimal
#   ./scripts/package-claude-web-skills.sh --matt-dir /path/to/mattpocock/skills
#   ./scripts/package-claude-web-skills.sh --no-adapt    # raw copies, no Claude rewrites
#   ./scripts/package-claude-web-skills.sh --repo-only   # skip Matt skills
#
# Outputs under dist/claude-web/:
#   skills/<name>.zip          — upload each in Customize → Skills → Upload
#   all-skill-zips.zip         — convenience bag of the individual zips
#   plugin/git-memory-claude/  — Claude Code / org plugin layout (optional)
#   MANIFEST.txt
#
# Requires Bash 3.2+ (macOS /bin/bash is fine), python3, zip, unzip, git.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${ROOT}/dist/claude-web"
SET="full"
MATT_DIR=""
ADAPT=1
INCLUDE_PLUGIN=1
INCLUDE_MATT=1
DESC_MAX=200
VENV="${ROOT}/.venv-pack"
ADAPT_PY="${ROOT}/scripts/_adapt_claude_web_skill.py"
PYTHON=""

die() { echo "error: $*" >&2; exit 1; }
log() { echo "$*" >&2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --set) SET="${2:?}"; shift 2 ;;
    --matt-dir) MATT_DIR="${2:?}"; shift 2 ;;
    --no-adapt) ADAPT=0; shift ;;
    --no-plugin) INCLUDE_PLUGIN=0; shift ;;
    --repo-only) INCLUDE_MATT=0; shift ;;
    -h|--help)
      sed -n '2,27p' "$0"
      exit 0
      ;;
    *)
      die "unknown arg: $1"
      ;;
  esac
done

if [[ "$SET" != "full" && "$SET" != "minimal" ]]; then
  die "--set must be full or minimal"
fi

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing command: $1"
}

need_cmd python3
need_cmd zip
need_cmd unzip
need_cmd git
need_cmd find
need_cmd awk

ensure_python() {
  if [[ -x "${VENV}/bin/python" ]]; then
    PYTHON="${VENV}/bin/python"
  elif [[ -x "${VENV}/bin/python3" ]]; then
    PYTHON="${VENV}/bin/python3"
  else
    log "Creating packaging venv at ${VENV} ..."
    python3 -m venv "$VENV" || die "python3 -m venv failed (install python3-venv)"
    if [[ -x "${VENV}/bin/python" ]]; then
      PYTHON="${VENV}/bin/python"
    else
      PYTHON="${VENV}/bin/python3"
    fi
  fi
  [[ -x "$PYTHON" ]] || die "venv python not executable: $PYTHON"
  "$PYTHON" -c 'import re,sys' || die "venv python cannot import stdlib"
}

read_matt_names() {
  local section="$1"
  awk -v sec="$section" '
    $0 == "## " sec { insec=1; next }
    /^## / { insec=0 }
    insec && /^[a-z0-9-]+$/ { print }
  ' "${ROOT}/matt-skill-sets.txt"
}

# Bash 3.2-safe: no mapfile / associative arrays.
MATT_NAMES=()
if [[ "$INCLUDE_MATT" -eq 1 ]]; then
  while IFS= read -r _name; do
    [[ -n "$_name" ]] || continue
    MATT_NAMES+=("$_name")
  done < <(read_matt_names "$SET")
  if [[ ${#MATT_NAMES[@]} -eq 0 ]]; then
    die "no Matt skill names found for set=$SET in matt-skill-sets.txt"
  fi
fi

resolve_matt_dir() {
  if [[ -n "$MATT_DIR" ]]; then
    [[ -d "$MATT_DIR/skills" || -d "$MATT_DIR" ]] || die "Matt dir not found: $MATT_DIR"
    if [[ -d "$MATT_DIR/skills" ]]; then
      printf '%s\n' "$MATT_DIR"
    else
      # Allow passing the inner skills/ parent incorrectly; normalize.
      printf '%s\n' "$(cd "$MATT_DIR/.." && pwd)"
    fi
    return
  fi
  if [[ -d /tmp/mattpocock-skills/skills ]]; then
    printf '%s\n' /tmp/mattpocock-skills
    return
  fi
  local clone=/tmp/mattpocock-skills
  log "Cloning mattpocock/skills into $clone ..."
  rm -rf "$clone"
  git clone --depth 1 https://github.com/mattpocock/skills.git "$clone" \
    || die "git clone mattpocock/skills failed (pass --matt-dir or --repo-only)"
  printf '%s\n' "$clone"
}

MATT_ROOT=""
if [[ "$INCLUDE_MATT" -eq 1 ]]; then
  MATT_ROOT="$(resolve_matt_dir)"
  [[ -d "${MATT_ROOT}/skills" ]] || die "no skills/ under Matt root: $MATT_ROOT"
fi

find_matt_skill() {
  local name="$1"
  local hit=""
  # Prefer engineering/, then productivity/, then anywhere under skills/.
  for cand in \
    "${MATT_ROOT}/skills/engineering/${name}" \
    "${MATT_ROOT}/skills/productivity/${name}" \
    "${MATT_ROOT}/skills/misc/${name}" \
    "${MATT_ROOT}/skills/personal/${name}"
  do
    if [[ -f "${cand}/SKILL.md" ]]; then
      hit="$cand"
      break
    fi
  done
  if [[ -z "$hit" ]]; then
    hit="$(find "${MATT_ROOT}/skills" -type d -name "$name" 2>/dev/null | head -n 1 || true)"
  fi
  if [[ -z "$hit" || ! -f "${hit}/SKILL.md" ]]; then
    die "Matt skill not found: $name (under ${MATT_ROOT}/skills)"
  fi
  printf '%s\n' "$hit"
}

skill_already_listed() {
  local needle="$1"
  local s
  for s in "${REPO_SKILL_SRCS[@]+"${REPO_SKILL_SRCS[@]}"}"; do
    [[ "$(basename "$s")" == "$needle" ]] && return 0
  done
  return 1
}

REPO_SKILL_SRCS=()

add_repo_skill() {
  local src="$1"
  local name
  name="$(basename "$src")"
  if skill_already_listed "$name"; then
    return 0
  fi
  [[ -d "$src" ]] || die "repo skill directory missing: $src"
  [[ -f "${src}/SKILL.md" ]] || die "repo skill missing SKILL.md: $src"
  REPO_SKILL_SRCS+=("$src")
}

add_repo_skill "${ROOT}/skills/setup-git-memory"
add_repo_skill "${ROOT}/skills/update-git-memory"

shopt -s nullglob
for d in "${ROOT}/scaffold/.cursor/skills"/*; do
  [[ -d "$d" && -f "$d/SKILL.md" ]] || continue
  add_repo_skill "$d"
done
shopt -u nullglob

if [[ ${#REPO_SKILL_SRCS[@]} -eq 0 ]]; then
  die "no repo skills found under skills/ or scaffold/.cursor/skills/"
fi

# setup-git-memory.zip carries scaffold/ inside it, and setup-git-memory's own
# step 5 runs scripts/test/run-tests.sh from that copy. An embedded scaffold
# missing the tool layer ships an installer that cannot prove itself, which is
# discovered by the user rather than here.
for _scaffold_file in \
  scripts/check-memory.sh \
  scripts/git-memory-resolve.sh \
  scripts/git-memory-graph.sh \
  scripts/git-memory-packet.sh \
  scripts/test/run-tests.sh
do
  [[ -f "${ROOT}/scaffold/${_scaffold_file}" ]] \
    || die "scaffold/${_scaffold_file} is missing; setup-git-memory.zip would embed a scaffold whose tool layer cannot run"
done

# Preflight Matt paths before writing any zip.
MATT_SRCS=()
if [[ "$INCLUDE_MATT" -eq 1 ]]; then
  for name in "${MATT_NAMES[@]}"; do
    MATT_SRCS+=("$(find_matt_skill "$name")")
  done
fi

EXPECTED=$(( ${#REPO_SKILL_SRCS[@]} + ${#MATT_SRCS[@]} ))
log "Will pack ${#REPO_SKILL_SRCS[@]} repo + ${#MATT_SRCS[@]} Matt = ${EXPECTED} skill zips"

ensure_python

rm -rf "$OUT"
mkdir -p "$OUT/skills" "$OUT/staging"
if [[ "$INCLUDE_PLUGIN" -eq 1 ]]; then
  mkdir -p "$OUT/plugin/git-memory-claude/skills" \
    "$OUT/plugin/git-memory-claude/.claude-plugin"
fi

stage_copy() {
  local src="$1"
  local dest="$2"
  mkdir -p "$(dirname "$dest")"
  rm -rf "$dest"
  cp -R "$src" "$dest" || die "copy failed: $src → $dest"
  rm -rf "$dest/agents"
}

adapt_skill_md() {
  local skill_md="$1"
  local skill_name="$2"
  local kind="$3"
  local args
  args=("$ADAPT_PY" "$skill_md" "$skill_name" "$kind" --desc-max "$DESC_MAX")
  if [[ "$ADAPT" -eq 1 ]]; then
    args+=(--adapt)
  fi
  "$PYTHON" "${args[@]}" || die "adapt failed for $skill_name"
}

zip_skill() {
  local staged="$1"
  local name
  name="$(basename "$staged")"
  local zip_path="${OUT}/skills/${name}.zip"
  [[ -f "${staged}/SKILL.md" ]] || die "staged skill missing SKILL.md: $staged"
  (
    cd "$(dirname "$staged")"
    rm -f "$zip_path"
    # Zip the folder itself (required Claude Web layout).
    zip -qr "$zip_path" "$name" || die "zip failed for $name"
  )
  if ! unzip -l "$zip_path" 2>/dev/null | grep -E "/${name}/SKILL\.md$| ${name}/SKILL\.md$" >/dev/null; then
    # Fallback: any SKILL.md under the skill folder prefix.
    if ! unzip -l "$zip_path" 2>/dev/null | grep -F "${name}/SKILL.md" >/dev/null; then
      log "Bad zip layout for $name:"
      unzip -l "$zip_path" >&2 || true
      die "zip for $name does not contain ${name}/SKILL.md"
    fi
  fi
  log "  packed ${name}.zip ($(wc -c < "$zip_path" | tr -d ' ') bytes)"
}

log "Packaging Claude Web skills (set=$SET, adapt=$ADAPT, matt=$INCLUDE_MATT) → $OUT"

# --- repo skills ---
for src in "${REPO_SKILL_SRCS[@]}"; do
  name="$(basename "$src")"
  dest="${OUT}/staging/${name}"
  log "→ repo skill: $name"
  stage_copy "$src" "$dest"
  if [[ "$name" == "setup-git-memory" ]]; then
    rm -rf "${dest}/scaffold"
    cp -R "${ROOT}/scaffold" "${dest}/scaffold" || die "failed to embed scaffold/"
    # .claude/skills is a symbolic link to .cursor/skills in the repository, and
    # zip stores what a link points AT unless told otherwise (-y). Shipping it
    # would put a second, full copy of every repo skill in the archive — the two
    # homes the link exists to prevent, and they would drift the first time
    # someone edited one side. zip -y is not the fix either: a symlink in a zip
    # is unreliable on Windows and in whichever extractor a Claude Web user
    # happens to have. The installer recreates the link, which is one command.
    rm -rf "${dest}/scaffold/.claude"
  fi
  adapt_skill_md "${dest}/SKILL.md" "$name" "repo"
  zip_skill "$dest"
  if [[ "$INCLUDE_PLUGIN" -eq 1 ]]; then
    rm -rf "${OUT}/plugin/git-memory-claude/skills/${name}"
    cp -R "$dest" "${OUT}/plugin/git-memory-claude/skills/${name}"
  fi
done

# --- Matt skills ---
i=0
for src in "${MATT_SRCS[@]+"${MATT_SRCS[@]}"}"; do
  name="$(basename "$src")"
  dest="${OUT}/staging/${name}"
  log "→ Matt skill: $name"
  stage_copy "$src" "$dest"
  adapt_skill_md "${dest}/SKILL.md" "$name" "matt"
  zip_skill "$dest"
  if [[ "$INCLUDE_PLUGIN" -eq 1 ]]; then
    rm -rf "${OUT}/plugin/git-memory-claude/skills/${name}"
    cp -R "$dest" "${OUT}/plugin/git-memory-claude/skills/${name}"
  fi
  i=$((i + 1))
done

ZIP_COUNT="$(find "${OUT}/skills" -maxdepth 1 -name '*.zip' | wc -l | tr -d ' ')"
if [[ "$ZIP_COUNT" -ne "$EXPECTED" ]]; then
  log "Zips currently in ${OUT}/skills:"
  ls -la "${OUT}/skills" >&2 || true
  die "expected ${EXPECTED} skill zips, found ${ZIP_COUNT}"
fi

# Convenience bag of individual zips (still one-skill-per-upload).
(
  cd "${OUT}/skills"
  # Avoid a bare glob failing under nullglob-off with no matches (already checked).
  zip -qr "${OUT}/all-skill-zips.zip" ./*.zip
)

if [[ "$INCLUDE_PLUGIN" -eq 1 ]]; then
  cat > "${OUT}/plugin/git-memory-claude/.claude-plugin/plugin.json" <<EOF
{
  "name": "git-memory-claude",
  "version": "0.1.0",
  "description": "git-memory workflow skills plus Matt Pocock craft skills (${SET} set) for Claude",
  "author": {
    "name": "friofry"
  }
}
EOF
  (
    cd "${OUT}/plugin"
    zip -qr "${OUT}/git-memory-claude-plugin.zip" git-memory-claude
  )
fi

{
  echo "git-memory Claude Web package"
  echo "generated: $(date -u +%Y-%m-%dT%H:%MZ)"
  echo "matt set: ${SET}"
  echo "adapt for Claude Web: ${ADAPT}"
  echo "matt source: ${MATT_ROOT:-"(skipped)"}"
  echo "skill zip count: ${ZIP_COUNT}"
  echo
  echo "Upload EACH file in skills/*.zip via Claude → Customize → Skills → Upload a skill."
  echo "setup-git-memory.zip is only the installer (+ embedded scaffold) — the other zips are siblings in the same folder."
  echo "Enable every uploaded skill. Claude composes them; do not rely on .agents/skills/ paths."
  echo
  echo "Repo skills:"
  for src in "${REPO_SKILL_SRCS[@]}"; do
    echo "  - $(basename "$src")"
  done
  echo
  if [[ "$INCLUDE_MATT" -eq 1 ]]; then
    echo "Matt skills (${SET}):"
    for name in "${MATT_NAMES[@]}"; do
      echo "  - ${name}"
    done
  else
    echo "Matt skills: skipped (--repo-only)"
  fi
  echo
  echo "All skill zips:"
  # Portable listing without relying on ls formatting.
  find "${OUT}/skills" -maxdepth 1 -name '*.zip' -print | sort | while IFS= read -r z; do
    echo "  $(basename "$z")"
  done
  echo
  echo "Artifacts:"
  echo "  skills/*.zip                 — Claude Web uploads (one skill each)  [${ZIP_COUNT} files]"
  echo "  all-skill-zips.zip           — bag of those zips for download/share"
  if [[ "$INCLUDE_PLUGIN" -eq 1 ]]; then
    echo "  git-memory-claude-plugin.zip — Claude Code / org plugin layout"
  fi
} | tee "${OUT}/MANIFEST.txt"

log ""
log "Done: ${ZIP_COUNT} skill zips in ${OUT}/skills/"
log "If you only noticed setup-git-memory.zip before: look at the other *.zip files next to it (see MANIFEST.txt)."
