#!/usr/bin/env bash
# Installer for claude-dev-agents — copies agents + skills into Claude Code config.
# Usage:
#   ./install.sh                     install to user scope   (~/.claude)
#   ./install.sh --project           install to project scope (./.claude)
#   ./install.sh --uninstall         remove from user scope
#   ./install.sh --uninstall --project
set -euo pipefail

REPO="lastangel001/claude-dev-agents"
RAW="https://raw.githubusercontent.com/${REPO}/main"
AGENTS=(php-developer php-reviewer python-developer python-reviewer)
SKILLS=(php-patterns python-patterns)

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

# Detect run mode: piped (curl | bash) has no local files -> download; else copy from repo dir.
SCRIPT_DIR=""
if [ -n "${BASH_SOURCE:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
LOCAL=0
if [ -n "$SCRIPT_DIR" ] && [ -d "${SCRIPT_DIR}/agents" ]; then LOCAL=1; fi

backup() { [ -e "$1" ] && mv "$1" "$1.bak" && echo "  backed up -> $1.bak" || true; }

if [ "$ACTION" = "uninstall" ]; then
  echo "Uninstalling from ${BASE} ..."
  for a in "${AGENTS[@]}"; do rm -f "${AGENTS_DIR}/${a}.md" && echo "  removed agent ${a}"; done
  for s in "${SKILLS[@]}"; do rm -rf "${SKILLS_DIR}/${s}" && echo "  removed skill ${s}"; done
  echo "Done."
  exit 0
fi

echo "Installing claude-dev-agents -> ${BASE} (${SCOPE} scope)"
mkdir -p "$AGENTS_DIR" "$SKILLS_DIR"

if [ "$LOCAL" = "1" ]; then
  echo "Agents:"
  for a in "${AGENTS[@]}"; do
    backup "${AGENTS_DIR}/${a}.md"
    cp "${SCRIPT_DIR}/agents/${a}.md" "${AGENTS_DIR}/${a}.md"
    echo "  installed agent ${a}"
  done
  echo "Skills:"
  for s in "${SKILLS[@]}"; do
    backup "${SKILLS_DIR}/${s}"
    cp -R "${SCRIPT_DIR}/skills/${s}" "${SKILLS_DIR}/${s}"
    echo "  installed skill ${s}"
  done
else
  command -v curl >/dev/null || { echo "curl required for remote install" >&2; exit 1; }
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  echo "Downloading ${REPO} ..."
  curl -fsSL "https://github.com/${REPO}/archive/refs/heads/main.tar.gz" -o "${TMP}/repo.tgz"
  tar -xzf "${TMP}/repo.tgz" -C "$TMP"
  SRC="$(find "$TMP" -maxdepth 1 -type d -name 'claude-dev-agents-*' | head -1)"
  [ -d "${SRC}/agents" ] || { echo "download looks wrong: no agents/ dir" >&2; exit 1; }
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
fi

echo ""
echo "Done. Restart Claude Code (or start a new session) to pick up the changes."
