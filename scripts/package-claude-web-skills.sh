#!/usr/bin/env bash
# Package git-memory + Matt Pocock skills as Claude Web upload zips.
#
# Claude.ai accepts one skill per ZIP:
#   skill-name.zip
#   └── skill-name/
#       └── SKILL.md   (+ optional resources)
#
# Usage:
#   ./scripts/package-claude-web-skills.sh              # full Matt set
#   ./scripts/package-claude-web-skills.sh --set minimal
#   ./scripts/package-claude-web-skills.sh --matt-dir /path/to/mattpocock/skills
#   ./scripts/package-claude-web-skills.sh --no-adapt    # raw copies, no Claude rewrites
#
# Outputs under dist/claude-web/:
#   skills/<name>.zip          — upload each in Customize → Skills → Upload
#   all-skill-zips.zip         — convenience bag of the individual zips
#   plugin/git-memory-claude/  — Claude Code / org plugin layout (optional)
#   MANIFEST.txt

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${ROOT}/dist/claude-web"
SET="full"
MATT_DIR=""
ADAPT=1
INCLUDE_PLUGIN=1
DESC_MAX=200
VENV="${ROOT}/.venv-pack"
ADAPT_PY="${ROOT}/scripts/_adapt_claude_web_skill.py"

ensure_python() {
  if [[ -x "${VENV}/bin/python" ]]; then
    PYTHON="${VENV}/bin/python"
    return
  fi
  python3 -m venv "$VENV"
  PYTHON="${VENV}/bin/python"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --set) SET="${2:?}"; shift 2 ;;
    --matt-dir) MATT_DIR="${2:?}"; shift 2 ;;
    --no-adapt) ADAPT=0; shift ;;
    --no-plugin) INCLUDE_PLUGIN=0; shift ;;
    -h|--help)
      sed -n '2,20p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      exit 1
      ;;
  esac
done

if [[ "$SET" != "full" && "$SET" != "minimal" ]]; then
  echo "--set must be full or minimal" >&2
  exit 1
fi

read_matt_names() {
  local section="$1"
  awk -v sec="$section" '
    $0 == "## " sec { insec=1; next }
    /^## / { insec=0 }
    insec && /^[a-z0-9-]+$/ { print }
  ' "${ROOT}/matt-skill-sets.txt"
}

mapfile -t MATT_NAMES < <(read_matt_names "$SET")
if [[ ${#MATT_NAMES[@]} -eq 0 ]]; then
  echo "No Matt skill names found for set=$SET in matt-skill-sets.txt" >&2
  exit 1
fi

resolve_matt_dir() {
  if [[ -n "$MATT_DIR" ]]; then
    [[ -d "$MATT_DIR" ]] || { echo "Matt dir not found: $MATT_DIR" >&2; exit 1; }
    printf '%s\n' "$MATT_DIR"
    return
  fi
  if [[ -d /tmp/mattpocock-skills/skills ]]; then
    printf '%s\n' /tmp/mattpocock-skills
    return
  fi
  local clone=/tmp/mattpocock-skills
  echo "Cloning mattpocock/skills into $clone ..." >&2
  rm -rf "$clone"
  git clone --depth 1 https://github.com/mattpocock/skills.git "$clone" >&2
  printf '%s\n' "$clone"
}

MATT_ROOT="$(resolve_matt_dir)"

find_matt_skill() {
  local name="$1"
  local hit
  hit="$(find "${MATT_ROOT}/skills" -type d -name "$name" 2>/dev/null | head -n 1 || true)"
  if [[ -z "$hit" || ! -f "$hit/SKILL.md" ]]; then
    echo "Matt skill not found: $name (under ${MATT_ROOT}/skills)" >&2
    return 1
  fi
  printf '%s\n' "$hit"
}

# Repo-authored skills: installer pair + scaffold workflow skills.
# Prefer skills/ over scaffold/.cursor/skills/ when both exist (setup lives only in skills/).
declare -a REPO_SKILL_SRCS=()
declare -A REPO_SKILL_SEEN=()

add_repo_skill() {
  local src="$1"
  local name
  name="$(basename "$src")"
  if [[ -n "${REPO_SKILL_SEEN[$name]:-}" ]]; then
    return
  fi
  REPO_SKILL_SEEN[$name]=1
  REPO_SKILL_SRCS+=("$src")
}

add_repo_skill "${ROOT}/skills/setup-git-memory"
add_repo_skill "${ROOT}/skills/update-git-memory"
for d in "${ROOT}/scaffold/.cursor/skills"/*; do
  [[ -d "$d" && -f "$d/SKILL.md" ]] || continue
  add_repo_skill "$d"
done

rm -rf "$OUT"
mkdir -p "$OUT/skills" "$OUT/staging" "$OUT/plugin/git-memory-claude/skills" \
  "$OUT/plugin/git-memory-claude/.claude-plugin"

stage_copy() {
  local src="$1"
  local dest="$2"
  mkdir -p "$(dirname "$dest")"
  rm -rf "$dest"
  cp -a "$src" "$dest"
  # OpenAI agent stubs are irrelevant on Claude Web.
  rm -rf "$dest/agents"
}

adapt_skill_md() {
  local skill_md="$1"
  local skill_name="$2"
  local kind="$3" # repo|matt
  local args=("$ADAPT_PY" "$skill_md" "$skill_name" "$kind" --desc-max "$DESC_MAX")
  if [[ "$ADAPT" -eq 1 ]]; then
    args+=(--adapt)
  fi
  "$PYTHON" "${args[@]}"
}

zip_skill() {
  local staged="$1"
  local name
  name="$(basename "$staged")"
  local zip_path="${OUT}/skills/${name}.zip"
  (
    cd "$(dirname "$staged")"
    rm -f "$zip_path"
    zip -qr "$zip_path" "$name"
  )
  # sanity: zip must contain name/SKILL.md
  if ! unzip -l "$zip_path" | grep -q " ${name}/SKILL.md$"; then
    echo "Bad zip layout for $name" >&2
    unzip -l "$zip_path" >&2
    exit 1
  fi
  echo "  packed ${name}.zip"
}

ensure_python
echo "Packaging Claude Web skills (set=$SET, adapt=$ADAPT) → $OUT"

# --- repo skills ---
for src in "${REPO_SKILL_SRCS[@]}"; do
  name="$(basename "$src")"
  dest="${OUT}/staging/${name}"
  stage_copy "$src" "$dest"
  if [[ "$name" == "setup-git-memory" ]]; then
    # Bundle scaffold so Claude Web can install without a separate clone.
    rm -rf "${dest}/scaffold"
    cp -a "${ROOT}/scaffold" "${dest}/scaffold"
    # Drop nested .cursor/skills from bundled scaffold? Keep them — setup copies them into the target repo.
  fi
  adapt_skill_md "${dest}/SKILL.md" "$name" "repo"
  zip_skill "$dest"
  if [[ "$INCLUDE_PLUGIN" -eq 1 ]]; then
    cp -a "$dest" "${OUT}/plugin/git-memory-claude/skills/${name}"
  fi
done

# --- Matt skills ---
for name in "${MATT_NAMES[@]}"; do
  src="$(find_matt_skill "$name")"
  dest="${OUT}/staging/${name}"
  stage_copy "$src" "$dest"
  adapt_skill_md "${dest}/SKILL.md" "$name" "matt"
  zip_skill "$dest"
  if [[ "$INCLUDE_PLUGIN" -eq 1 ]]; then
    cp -a "$dest" "${OUT}/plugin/git-memory-claude/skills/${name}"
  fi
done

# Convenience bag of individual zips (still one-skill-per-upload).
(
  cd "${OUT}/skills"
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
  echo "matt source: ${MATT_ROOT}"
  echo
  echo "Upload each file in skills/*.zip via Claude → Customize → Skills → Upload a skill."
  echo "Enable every uploaded skill. Claude composes them; do not rely on .agents/skills/ paths."
  echo
  echo "Repo skills:"
  for src in "${REPO_SKILL_SRCS[@]}"; do
    echo "  - $(basename "$src")"
  done
  echo
  echo "Matt skills (${SET}):"
  for name in "${MATT_NAMES[@]}"; do
    echo "  - ${name}"
  done
  echo
  echo "Artifacts:"
  echo "  skills/*.zip                 — Claude Web uploads (one skill each)"
  echo "  all-skill-zips.zip           — bag of those zips for download/share"
  if [[ "$INCLUDE_PLUGIN" -eq 1 ]]; then
    echo "  git-memory-claude-plugin.zip — Claude Code / org plugin layout"
  fi
} | tee "${OUT}/MANIFEST.txt"

echo
echo "Done. See ${OUT}/MANIFEST.txt"
