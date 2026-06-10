#!/usr/bin/env bash
# smoke.sh — bash install -> assertions -> uninstall
# Run with: bash test/smoke.sh
# Installs into a throwaway temp dir (--project scope); never touches real ~/.claude.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
pass() { echo "  PASS  $*"; }
fail() { echo "  FAIL  $*" >&2; exit 1; }
assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    pass "$label"
  else
    echo "  FAIL  $label" >&2
    echo "        expected: $expected" >&2
    echo "        actual:   $actual" >&2
    exit 1
  fi
}

# sha256 of a file — same portability wrapper as the installer
sha_of() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}';
  elif command -v shasum   >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}';
  else echo "nohash"; fi
}

echo "=== smoke.sh ==="

# ---------------------------------------------------------------------------
# setup: copy repo into TMP_SRC; each test gets its own scope dir
# ---------------------------------------------------------------------------
TMP_SRC="$(mktemp -d)"
trap 'rm -rf "$TMP_SRC"' EXIT

cp -R "${REPO_ROOT}/agents"     "$TMP_SRC/"
cp -R "${REPO_ROOT}/skills"     "$TMP_SRC/"
cp    "${REPO_ROOT}/VERSION"    "$TMP_SRC/"
cp    "${REPO_ROOT}/install.sh" "$TMP_SRC/"

INSTALLER="${TMP_SRC}/install.sh"
VERSION="$(tr -d '[:space:]' < "${REPO_ROOT}/VERSION")"

# ---------------------------------------------------------------------------
# 1. --version
# ---------------------------------------------------------------------------
VERSION_OUT="$("$INSTALLER" --version)"
assert_eq "1. --version output" "claude-dev-agents ${VERSION}" "$VERSION_OUT"

# ---------------------------------------------------------------------------
# 2–8. fresh install scope
# ---------------------------------------------------------------------------
SCOPE_A="$(mktemp -d)"
trap 'rm -rf "$TMP_SRC" "$SCOPE_A"' EXIT
MANIFEST="${SCOPE_A}/.claude/.cda-manifest"

cd "$SCOPE_A"
bash "$INSTALLER" --project
pass "2. install exit 0"
cd "$REPO_ROOT"

# 3. manifest exists and non-empty
[ -f "$MANIFEST" ] || fail "3. manifest absent"
[ -s "$MANIFEST" ] || fail "3. manifest empty"
pass "3. manifest exists and non-empty"

# 4. manifest format: every line matches <relpath>TAB(<64hex>|nohash)
BAD=0
while IFS=$'\t' read -r rel hash || [ -n "${rel:-}" ]; do
  [ -n "${rel:-}" ] || continue
  echo "$hash" | grep -qE '^([0-9a-f]{64}|nohash)$' || { echo "  bad hash '$hash' for '$rel'" >&2; BAD=1; }
done < "$MANIFEST"
[ "$BAD" = "0" ] || fail "4. manifest has lines with invalid hash format"
pass "4. manifest format valid"

# 5. BL-006 guard: manifest line count == installed file count
MANIFEST_COUNT="$(grep -c '' "$MANIFEST")"
INSTALLED_COUNT="$(find "${SCOPE_A}/.claude/agents" "${SCOPE_A}/.claude/skills" -type f 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "5. BL-006 line count == file count" "$INSTALLED_COUNT" "$MANIFEST_COUNT"
LAST_REL="$(find "${SCOPE_A}/.claude/agents" "${SCOPE_A}/.claude/skills" -type f | sort | tail -1 | sed "s|${SCOPE_A}/.claude/||")"
grep -q "^${LAST_REL}" "$MANIFEST" || fail "5. last installed file '$LAST_REL' missing from manifest"
pass "5. last installed file in manifest (BL-006 guard)"

# 6. sampled hash: agents/architect.md hash matches manifest entry
ARCH_FILE="${SCOPE_A}/.claude/agents/architect.md"
[ -f "$ARCH_FILE" ] || fail "6. agents/architect.md not installed"
ACTUAL_HASH="$(sha_of "$ARCH_FILE")"
MANIFEST_HASH="$(grep '^agents/architect\.md' "$MANIFEST" | cut -f2)"
assert_eq "6. architect.md hash" "$ACTUAL_HASH" "$MANIFEST_HASH"

# 7. security — refuse uninstall without manifest
SCOPE_B="$(mktemp -d)"
trap 'rm -rf "$TMP_SRC" "$SCOPE_A" "$SCOPE_B"' EXIT
cd "$SCOPE_B"
set +e
REFUSE_EXIT=0
bash "$INSTALLER" --project --uninstall 2>/dev/null || REFUSE_EXIT=$?
set -e
cd "$REPO_ROOT"
[ "$REFUSE_EXIT" -ne 0 ] || fail "7. uninstall without manifest should exit nonzero"
pass "7. security: refuse uninstall without manifest (exit $REFUSE_EXIT)"

# 8. uninstall: all files gone, manifest removed
cd "$SCOPE_A"
bash "$INSTALLER" --project --uninstall
cd "$REPO_ROOT"
[ ! -f "$MANIFEST" ] || fail "8. manifest not removed after uninstall"
LEFTOVER="$(find "${SCOPE_A}/.claude/agents" "${SCOPE_A}/.claude/skills" -type f 2>/dev/null | head -5 || true)"
[ -z "$LEFTOVER" ] || fail "8. files left after uninstall: $LEFTOVER"
pass "8. uninstall: files removed, manifest gone"

# ---------------------------------------------------------------------------
# 9. security — modified file KEPT
# ---------------------------------------------------------------------------
SCOPE_C="$(mktemp -d)"
trap 'rm -rf "$TMP_SRC" "$SCOPE_B" "$SCOPE_C"' EXIT
cd "$SCOPE_C"
bash "$INSTALLER" --project
echo "# user edit" >> "${SCOPE_C}/.claude/agents/architect.md"
KEPT_OUT="$(bash "$INSTALLER" --project --uninstall 2>&1)"
cd "$REPO_ROOT"
[ -f "${SCOPE_C}/.claude/agents/architect.md" ] || fail "9. modified file deleted (should be KEPT)"
echo "$KEPT_OUT" | grep -q "modified, KEPT" || fail "9. output missing 'modified, KEPT'"
pass "9. modified file KEPT; output contains 'modified, KEPT'"

# ---------------------------------------------------------------------------
# 10. security — nohash entry: file must NOT be deleted (BL-004 fix)
# ---------------------------------------------------------------------------
SCOPE_D="$(mktemp -d)"
trap 'rm -rf "$TMP_SRC" "$SCOPE_B" "$SCOPE_C" "$SCOPE_D"' EXIT
cd "$SCOPE_D"
bash "$INSTALLER" --project
# Patch manifest: replace architect.md hash with nohash
NOHASH_MANIFEST="${SCOPE_D}/.claude/.cda-manifest"
sed -i 's/^agents\/architect\.md\t[0-9a-f]*/agents\/architect.md\tnohash/' "$NOHASH_MANIFEST"
grep -q $'^agents/architect.md\tnohash' "$NOHASH_MANIFEST" || fail "10. sed nohash patch failed"
NOHASH_OUT="$(bash "$INSTALLER" --project --uninstall 2>&1)"
cd "$REPO_ROOT"
[ -f "${SCOPE_D}/.claude/agents/architect.md" ] || \
  fail "10. nohash entry was deleted — must be KEPT (same safety as 'modified, KEPT')"
echo "$NOHASH_OUT" | grep -q "nohash, KEPT" || fail "10. output missing 'nohash, KEPT'"
pass "10. nohash: file KEPT, output contains 'nohash, KEPT'"

echo "=== smoke.sh: all assertions passed ==="
