#!/usr/bin/env bash
# Installer for claude-dev-agents — copies agents + skills into Claude Code config.
# Agents/skills are auto-discovered from the repo; no list to maintain.
# Usage:
#   ./install.sh                     install to user scope   (~/.claude)
#   ./install.sh --project           install to project scope (./.claude)
#   ./install.sh --uninstall         remove from user scope
#   ./install.sh --uninstall --project
set -euo pipefail

REPO="lastangel001/claude-dev-agents"

SCOPE="user"
ACTION="install"
for arg in "$@"; do
  case "$arg" in
    --project)   SCOPE="project" ;;
    --user)      SCOPE="user" ;;
    --uninstall) ACTION="uninstall" ;;
    -h|--help)   grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $arg" >&2; exit 1 ;;
  esac
done

if [ "$SCOPE" = "project" ]; then
  BASE="$(pwd)/.claude"
else
  BASE="${HOME}/.claude"
fi
AGENTS_DIR="${BASE}/agents"
SKILLS_DIR="${BASE}/skills"

# Resolve source dir: local repo (script lives next to agents/) else download tarball.
SCRIPT_DIR=""
if [ -n "${BASH_SOURCE:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

if [ -n "$SCRIPT_DIR" ] && [ -d "${SCRIPT_DIR}/agents" ]; then
  SRC="$SCRIPT_DIR"
else
  command -v curl >/dev/null || { echo "curl required for remote install" >&2; exit 1; }
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  echo "Downloading ${REPO} ..."
  curl -fsSL "https://github.com/${REPO}/archive/refs/heads/main.tar.gz" -o "${TMP}/repo.tgz"
  tar -xzf "${TMP}/repo.tgz" -C "$TMP"
  SRC="$(find "$TMP" -maxdepth 1 -type d -name 'claude-dev-agents-*' | head -1)"
  [ -d "${SRC}/agents" ] || { echo "download looks wrong: no agents/ dir" >&2; exit 1; }
fi

# Auto-discover: every .md under agents/, every dir under skills/.
AGENTS=()
for f in "${SRC}"/agents/*.md; do [ -e "$f" ] && AGENTS+=("$(basename "$f" .md)"); done
SKILLS=()
if [ -d "${SRC}/skills" ]; then
  for d in "${SRC}"/skills/*/; do [ -d "$d" ] && SKILLS+=("$(basename "$d")"); done
fi

# Backups go OUTSIDE agents/ and skills/ so Claude Code never loads a .bak as a
# duplicate agent/skill. One timestamped dir per run under ${BASE}/.cda-backups.
BACKUP_ROOT="${BASE}/.cda-backups/$(date +%Y%m%d-%H%M%S)"
backup() {
  [ -e "$1" ] || return 0
  local rel="${1#${BASE}/}" dest
  dest="${BACKUP_ROOT}/${rel}"
  mkdir -p "$(dirname "$dest")"
  mv "$1" "$dest" && echo "  backed up -> $dest"
}

if [ "$ACTION" = "uninstall" ]; then
  echo "Uninstalling from ${BASE} ..."
  for a in "${AGENTS[@]}"; do rm -f "${AGENTS_DIR}/${a}.md" && echo "  removed agent ${a}"; done
  for s in "${SKILLS[@]}"; do rm -rf "${SKILLS_DIR}/${s}" && echo "  removed skill ${s}"; done
  echo "Done."
  exit 0
fi

echo "Installing claude-dev-agents -> ${BASE} (${SCOPE} scope)"
mkdir -p "$AGENTS_DIR" "$SKILLS_DIR"

echo "Agents:"
for a in "${AGENTS[@]}"; do
  backup "${AGENTS_DIR}/${a}.md"
  cp "${SRC}/agents/${a}.md" "${AGENTS_DIR}/${a}.md"
  echo "  installed agent ${a}"
done
echo "Skills:"
for s in "${SKILLS[@]}"; do
  backup "${SKILLS_DIR}/${s}"
  cp -R "${SRC}/skills/${s}" "${SKILLS_DIR}/${s}"
  echo "  installed skill ${s}"
done

echo ""
echo "Done. Restart Claude Code (or start a new session) to pick up the changes."
