#!/usr/bin/env bash
# Installer for claude-dev-agents — copies agents + skills into Claude Code config.
# Agents/skills are auto-discovered from the repo; no list to maintain.
# Usage:
#   ./install.sh                     install to user scope   (~/.claude)
#   ./install.sh --project           install to project scope (./.claude)
#   ./install.sh --agent NAME        install only NAME (repeatable), skills untouched
#   ./install.sh --uninstall         remove from user scope
#   ./install.sh --uninstall --project
#   ./install.sh --uninstall --agent NAME   remove only NAME, leave rest installed
#
# Uninstall is receipt-driven (see docs/adr/0001): install writes a manifest of the
# exact files it placed plus a content hash for each. Uninstall removes only files it
# can prove it owns and that the user has not modified. No manifest -> refuse to delete.
# --agent installs/uninstalls are atomic per invocation: either every requested agent
# is applied and the manifest updated in one swap, or (on an unknown name) nothing
# changes and the script exits 1.
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
  VERSION="1.9.0"
fi
REPO="lastangel001/claude-dev-agents"

SCOPE="user"
ACTION="install"
AGENT_FILTER=()
while [ $# -gt 0 ]; do
  case "$1" in
    --project)        SCOPE="project" ;;
    --user)           SCOPE="user" ;;
    --uninstall)      ACTION="uninstall" ;;
    --agent)
      shift
      [ $# -gt 0 ] || { echo "--agent requires a name" >&2; exit 1; }
      AGENT_FILTER+=("$1")
      ;;
    -v|--version)     echo "claude-dev-agents ${VERSION}"; exit 0 ;;
    -h|--help)        grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
  shift
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
  # With --agent, only manifest lines for agents/<name>.md are candidates for
  # removal; every other line (other agents, all skills) is copied back untouched
  # so a single-agent uninstall can't disturb the rest of the install.
  REMAIN_TMP="$(mktemp)"
  REQUESTED_SEEN=()
  # `|| [ -n "$rel" ]` processes a final record that lacks a trailing newline,
  # which `read` alone would silently drop.
  while IFS=$'\t' read -r rel hash || [ -n "${rel:-}" ]; do
    [ -n "${rel:-}" ] || continue
    target_me=1
    if [ "${#AGENT_FILTER[@]}" -gt 0 ]; then
      target_me=0
      for name in "${AGENT_FILTER[@]}"; do
        if [ "$rel" = "agents/${name}.md" ]; then target_me=1; REQUESTED_SEEN+=("$name"); break; fi
      done
    fi
    if [ "$target_me" -eq 0 ]; then
      printf '%s\t%s\n' "$rel" "$hash" >> "$REMAIN_TMP"
      continue
    fi
    target="${BASE}/${rel}"
    if [ ! -e "$target" ]; then echo "  gone, skip   ${rel}"; continue; fi
    if [ "$hash" != "nohash" ]; then
      if [ "$(sha_of "$target")" != "$hash" ]; then
        echo "  modified, KEPT ${rel}"; printf '%s\t%s\n' "$rel" "$hash" >> "$REMAIN_TMP"; continue
      fi
    else
      # No hash tool was available at install time; cannot verify ownership.
      # Treat as fail-safe: keep the file rather than delete it unverified.
      echo "  nohash, KEPT  ${rel}"; printf '%s\t%s\n' "$rel" "$hash" >> "$REMAIN_TMP"; continue
    fi
    rm -f "$target" && echo "  removed      ${rel}"
  done < "$MANIFEST"
  if [ "${#AGENT_FILTER[@]}" -gt 0 ]; then
    for name in "${AGENT_FILTER[@]}"; do
      found=0
      for seen in "${REQUESTED_SEEN[@]:-}"; do [ "$seen" = "$name" ] && found=1; done
      [ "$found" -eq 1 ] || echo "  not installed (no manifest entry): ${name}"
    done
  fi
  # Drop skill dirs left empty after their files were removed.
  if [ -d "$SKILLS_DIR" ]; then
    find "$SKILLS_DIR" -mindepth 1 -type d -empty -delete 2>/dev/null || true
  fi
  if [ -s "$REMAIN_TMP" ]; then
    mv "$REMAIN_TMP" "$MANIFEST"
  else
    rm -f "$REMAIN_TMP" "$MANIFEST"
  fi
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

# --agent restricts the install to the named agent(s) only; skills are left
# untouched. Validate every requested name up front so a typo fails before
# anything is copied, not partway through.
if [ "${#AGENT_FILTER[@]}" -gt 0 ]; then
  MISSING=()
  for name in "${AGENT_FILTER[@]}"; do
    found=0
    for a in "${AGENTS[@]}"; do [ "$a" = "$name" ] && found=1 && break; done
    [ "$found" -eq 1 ] || MISSING+=("$name")
  done
  if [ "${#MISSING[@]}" -gt 0 ]; then
    echo "unknown agent(s): ${MISSING[*]}" >&2
    echo "available: ${AGENTS[*]}" >&2
    exit 1
  fi
  AGENTS=("${AGENT_FILTER[@]}")
  SKILLS=()
fi

# Backups go OUTSIDE agents/ and skills/ so Claude Code never loads a .bak as a
# duplicate agent/skill. One timestamped dir per run under ${BASE}/.cda-backups.
BACKUP_ROOT="${BASE}/.cda-backups/$(date +%Y%m%d-%H%M%S)"
backup() {
  [ -e "$1" ] || return 0
  local rel="${1#"${BASE}"/}" dest
  dest="${BACKUP_ROOT}/${rel}"
  mkdir -p "$(dirname "$dest")"
  mv "$1" "$dest" && echo "  backed up -> $dest"
}

# Build the install receipt in a temp file, swap into place at the end.
MANIFEST_TMP="$(mktemp)"
record() { local p="$1"; printf '%s\t%s\n' "${p#"${BASE}"/}" "$(sha_of "$p")" >> "$MANIFEST_TMP"; }

echo "Installing claude-dev-agents v${VERSION} -> ${BASE} (${SCOPE} scope)"
mkdir -p "$AGENTS_DIR" "$SKILLS_DIR"

echo "Agents:"
for a in "${AGENTS[@]}"; do
  backup "${AGENTS_DIR}/${a}.md"
  cp "${SRC}/agents/${a}.md" "${AGENTS_DIR}/${a}.md"
  record "${AGENTS_DIR}/${a}.md"
  echo "  installed agent ${a}"
done
if [ "${#AGENT_FILTER[@]}" -gt 0 ]; then
  echo "Skills: (skipped — --agent installs only the named agent)"
else
  echo "Skills:"
fi
for s in "${SKILLS[@]}"; do
  backup "${SKILLS_DIR}/${s}"
  cp -R "${SRC}/skills/${s}" "${SKILLS_DIR}/${s}"
  while IFS= read -r f; do record "$f"; done < <(find "${SKILLS_DIR}/${s}" -type f)
  echo "  installed skill ${s}"
done

# Merge into any existing manifest instead of overwriting it, so a selective
# --agent install doesn't orphan the tracking of agents/skills installed by an
# earlier full run. Last write per relpath wins.
COMBINED_TMP="$(mktemp)"
if [ -f "$MANIFEST" ]; then
  cat "$MANIFEST" "$MANIFEST_TMP" > "$COMBINED_TMP"
else
  cp "$MANIFEST_TMP" "$COMBINED_TMP"
fi
awk -F'\t' '{data[$1]=$0} END{for (k in data) print data[k]}' "$COMBINED_TMP" | sort > "$MANIFEST_TMP"
mv "$MANIFEST_TMP" "$MANIFEST"
rm -f "$COMBINED_TMP"

echo ""
echo "Done. Restart Claude Code (or start a new session) to pick up the changes."
