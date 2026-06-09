#!/usr/bin/env bash
# parity.sh — assert bash + pwsh7 installers produce identical manifests
# Runs on ubuntu-latest (Job E); requires: bash, pwsh (7+) on PATH.
# Both installers take the local-source path so no download occurs.
#
# Why pwsh 7 on ubuntu (not PS 5.1 on Windows):
#   PS 5.1 on Windows emits a UTF-8 BOM, backslash path separators, and CRLF.
#   Normalizing BOM+CR is done here, but \ vs / would need extra sed and makes
#   the diff noisy. Running pwsh 7 on ubuntu keeps all separators as '/' so the
#   normalized manifests are directly comparable.
#   The BL-012 / PS 5.1 gate lives in Job B (static-pwsh-windows).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

pass() { echo "  PASS  $*"; }
fail() { echo "  FAIL  $*" >&2; exit 1; }

echo "=== parity.sh ==="

# Require pwsh 7
command -v pwsh >/dev/null 2>&1 || fail "pwsh (7+) not found on PATH — required for parity test"

# ---------------------------------------------------------------------------
# Setup: two isolated scope dirs, shared repo source copy
# ---------------------------------------------------------------------------
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

TMP_SRC="${TMP}/src"
SCOPE_BASH="${TMP}/bash_scope"
SCOPE_PWSH="${TMP}/pwsh_scope"

mkdir -p "$TMP_SRC" "$SCOPE_BASH" "$SCOPE_PWSH"

cp -R "${REPO_ROOT}/agents"     "$TMP_SRC/"
cp -R "${REPO_ROOT}/skills"     "$TMP_SRC/"
cp    "${REPO_ROOT}/VERSION"    "$TMP_SRC/"
cp    "${REPO_ROOT}/install.sh" "$TMP_SRC/"
cp    "${REPO_ROOT}/install.ps1" "$TMP_SRC/"

# ---------------------------------------------------------------------------
# Run bash installer
# ---------------------------------------------------------------------------
cd "$SCOPE_BASH"
bash "${TMP_SRC}/install.sh" --project
cd "$REPO_ROOT"
pass "bash install complete"

# ---------------------------------------------------------------------------
# Run pwsh7 installer
# ---------------------------------------------------------------------------
cd "$SCOPE_PWSH"
pwsh -NoProfile -File "${TMP_SRC}/install.ps1" -Project
cd "$REPO_ROOT"
pass "pwsh install complete"

# ---------------------------------------------------------------------------
# Normalize both manifests: strip BOM, strip CR, sort
# normalize <input> <output>
# ---------------------------------------------------------------------------
normalize() {
  local src="$1" dst="$2"
  sed '1s/^\xEF\xBB\xBF//' "$src" | tr -d '\r' | sort > "$dst"
}

MANIFEST_BASH="${SCOPE_BASH}/.claude/.cda-manifest"
MANIFEST_PWSH="${SCOPE_PWSH}/.claude/.cda-manifest"

[ -f "$MANIFEST_BASH" ] || fail "bash manifest missing: $MANIFEST_BASH"
[ -f "$MANIFEST_PWSH" ] || fail "pwsh manifest missing: $MANIFEST_PWSH"

normalize "$MANIFEST_BASH" "${TMP}/bash_norm.txt"
normalize "$MANIFEST_PWSH" "${TMP}/pwsh_norm.txt"

# ---------------------------------------------------------------------------
# Diff normalized manifests — must be empty
# ---------------------------------------------------------------------------
DIFF_OUT="$(diff "${TMP}/bash_norm.txt" "${TMP}/pwsh_norm.txt" || true)"
if [ -n "$DIFF_OUT" ]; then
  echo "  FAIL  normalized manifests differ:" >&2
  echo "$DIFF_OUT" >&2
  exit 1
fi
pass "normalized manifests identical"

# ---------------------------------------------------------------------------
# Byte-for-byte comparison of installed files
# ---------------------------------------------------------------------------
# Agent: architect.md
AGENT_BASH="${SCOPE_BASH}/.claude/agents/architect.md"
AGENT_PWSH="${SCOPE_PWSH}/.claude/agents/architect.md"
[ -f "$AGENT_BASH" ] || fail "bash: agents/architect.md missing"
[ -f "$AGENT_PWSH" ] || fail "pwsh: agents/architect.md missing"
cmp -s "$AGENT_BASH" "$AGENT_PWSH" || fail "agents/architect.md differs between bash and pwsh installs"
pass "agents/architect.md byte-for-byte identical"

# Skill: python-patterns/SKILL.md (pick first skill file found if it exists)
SKILL_BASH="$(find "${SCOPE_BASH}/.claude/skills" -name 'SKILL.md' | head -1 || true)"
SKILL_PWSH="$(find "${SCOPE_PWSH}/.claude/skills" -name 'SKILL.md' | head -1 || true)"
if [ -n "$SKILL_BASH" ] && [ -n "$SKILL_PWSH" ]; then
  SKILL_REL="${SKILL_BASH#${SCOPE_BASH}/.claude/skills/}"
  SKILL_REL_PWSH="${SKILL_PWSH#${SCOPE_PWSH}/.claude/skills/}"
  if [ "$SKILL_REL" = "$SKILL_REL_PWSH" ]; then
    cmp -s "$SKILL_BASH" "$SKILL_PWSH" || fail "skills/${SKILL_REL} differs between bash and pwsh installs"
    pass "skills/${SKILL_REL} byte-for-byte identical"
  else
    pass "skills: different files found (${SKILL_REL} vs ${SKILL_REL_PWSH}) — skipping cmp"
  fi
else
  echo "  NOTE  no SKILL.md found — skipping skill byte-compare"
fi

# ---------------------------------------------------------------------------
# Uninstall both scopes
# ---------------------------------------------------------------------------
cd "$SCOPE_BASH"
bash "${TMP_SRC}/install.sh" --project --uninstall
cd "$REPO_ROOT"

cd "$SCOPE_PWSH"
pwsh -NoProfile -File "${TMP_SRC}/install.ps1" -Project -Uninstall
cd "$REPO_ROOT"

# Assert both manifests gone, no agent/skill files remain
[ ! -f "$MANIFEST_BASH" ] || fail "bash manifest still present after uninstall"
[ ! -f "$MANIFEST_PWSH" ] || fail "pwsh manifest still present after uninstall"
BASH_LEFT="$(find "${SCOPE_BASH}/.claude/agents" "${SCOPE_BASH}/.claude/skills" -type f 2>/dev/null | head -5 || true)"
PWSH_LEFT="$(find "${SCOPE_PWSH}/.claude/agents" "${SCOPE_PWSH}/.claude/skills" -type f 2>/dev/null | head -5 || true)"
[ -z "$BASH_LEFT" ] || fail "bash: files left after uninstall: $BASH_LEFT"
[ -z "$PWSH_LEFT" ] || fail "pwsh: files left after uninstall: $PWSH_LEFT"
pass "both scopes clean after uninstall"

echo "=== parity.sh: all checks passed ==="
