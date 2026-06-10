#!/usr/bin/env bash
# Installer for claude-dev-agents — copies agents + skills into Claude Code config.
# Agents/skills are auto-discovered from the repo; no list to maintain.
# Usage:
#   ./install.sh                     install to user scope   (~/.claude)
#   ./install.sh --project           install to project scope (./.claude)
#   ./install.sh --uninstall         remove from user scope
#   ./install.sh --uninstall --project
#
# Uninstall is receipt-driven (see docs/adr/0001): install writes a manifest of the
# exact files it placed plus a content hash for each. Uninstall removes only files it
# can prove it owns and that the user has not modified. No manifest -> refuse to delete.
set -euo pipefail

# Resolve where this script lives (empty when piped via curl|bash).
SCRIPT_DIR=""
if [ -n "${BASH_SOURCE:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

# Single source of truth for the version: read the sibling VERSION file when
# running from a local checkout; fall back to the embedded constant only for the
# piped-remote case where no file is present.
if [ -n "$SCRIPT_DIR" ] && [ -f "${SCRIPT_DIR}/VERSION" ]; then
  VERSION="$(tr -d '[:space:]' < "${SCRIPT_DIR}/VERSION")"
else
  VERSION="1.3.0"
fi
REPO="lastangel001/claude-dev-agents"

SCOPE="user"
ACTION="install"
for arg in "$@"; do
  case "$arg" in
    --project)        SCOPE="project" ;;
    --user)           SCOPE="user" ;;
    --uninstall)      ACTION="uninstall" ;;
    -v|--version)     echo "claude-dev-agents ${VERSION}"; exit 0 ;;
    -h|--help)        grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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
MANIFEST="${BASE}/.cda-manifest"   # install receipt: "<relpath>\t<sha256|nohash>" per line

# SHA-256 of a file, portable across Linux (sha256sum) and macOS (shasum). "nohash"
# when no tool is available — uninstall then removes by ownership only, without an
# edit check, and says so.
sha_of() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}';
  elif command -v shasum   >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}';
  else echo "nohash"; fi
}

if [ "$ACTION" = "uninstall" ]; then
  echo "Uninstalling from ${BASE} ..."
  if [ ! -f "$MANIFEST" ]; then
    echo "  no install manifest at ${MANIFEST}" >&2
    echo "  refusing to delete — cannot prove which files belong to claude-dev-agents." >&2
    echo "  remove unwanted files manually from ${AGENTS_DIR} and ${SKILLS_DIR}." >&2
    exit 1
  fi
  # `|| [ -n "$rel" ]` processes a final record that lacks a trailing newline,
  # which `read` alone would silently drop.
  while IFS=$'\t' read -r rel hash || [ -n "${rel:-}" ]; do
    [ -n "${rel:-}" ] || continue
    target="${BASE}/${rel}"
    if [ ! -e "$target" ]; then echo "  gone, skip   ${rel}"; continue; fi
    if [ "$hash" != "nohash" ]; then
      if [ "$(sha_of "$target")" != "$hash" ]; then
        echo "  modified, KEPT ${rel}"; continue
      fi
    else
      # No hash tool was available at install time; cannot verify ownership.
      # Treat as fail-safe: keep the file rather than delete it unverified.
      echo "  nohash, KEPT  ${rel}"; continue
    fi
    rm -f "$target" && echo "  removed      ${rel}"
  done < "$MANIFEST"
  # Drop skill dirs left empty after their files were removed.
  [ -d "$SKILLS_DIR" ] && find "$SKILLS_DIR" -mindepth 1 -type d -empty -delete 2>/dev/null || true
  rm -f "$MANIFEST"
  echo "Done."
  exit 0
fi

# ---- install ----------------------------------------------------------------

# Resolve source dir: local repo (script lives next to agents/) else download tarball.
if [ -n "$SCRIPT_DIR" ] && [ -d "${SCRIPT_DIR}/agents" ]; then
  SRC="$SCRIPT_DIR"
else
  command -v curl >/dev/null || { echo "curl required for remote install" >&2; exit 1; }
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  echo "Downloading ${REPO} v${VERSION} ..."
  # Pin to the released tag, not the moving main tip — a piped install must fetch
  # exactly the version this script reports, with no surprise upstream content.
  curl -fsSL "https://github.com/${REPO}/archive/refs/tags/v${VERSION}.tar.gz" -o "${TMP}/repo.tgz"
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

# Build the install receipt in a temp file, swap into place at the end.
MANIFEST_TMP="$(mktemp)"
record() { local p="$1"; printf '%s\t%s\n' "${p#${BASE}/}" "$(sha_of "$p")" >> "$MANIFEST_TMP"; }

echo "Installing claude-dev-agents v${VERSION} -> ${BASE} (${SCOPE} scope)"
mkdir -p "$AGENTS_DIR" "$SKILLS_DIR"

echo "Agents:"
for a in "${AGENTS[@]}"; do
  backup "${AGENTS_DIR}/${a}.md"
  cp "${SRC}/agents/${a}.md" "${AGENTS_DIR}/${a}.md"
  record "${AGENTS_DIR}/${a}.md"
  echo "  installed agent ${a}"
done
echo "Skills:"
for s in "${SKILLS[@]}"; do
  backup "${SKILLS_DIR}/${s}"
  cp -R "${SRC}/skills/${s}" "${SKILLS_DIR}/${s}"
  while IFS= read -r f; do record "$f"; done < <(find "${SKILLS_DIR}/${s}" -type f)
  echo "  installed skill ${s}"
done

mv "$MANIFEST_TMP" "$MANIFEST"

echo ""
echo "Done. Restart Claude Code (or start a new session) to pick up the changes."
