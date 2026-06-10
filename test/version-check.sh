#!/usr/bin/env bash
# version-check.sh — assert version consistency across VERSION, install.sh, install.ps1
# Pure: no install performed. Runs on every push (Job A, ubuntu-latest).
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

echo "=== version-check.sh ==="

# ---------------------------------------------------------------------------
# 1. Read the canonical VERSION
# ---------------------------------------------------------------------------
VERSION="$(tr -d '[:space:]' < "${REPO_ROOT}/VERSION")"
echo "VERSION file: $VERSION"

# 2. Must match semver
if echo "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  pass "VERSION is valid semver"
else
  fail "VERSION not semver: '$VERSION'"
fi

# ---------------------------------------------------------------------------
# 3. Embedded fallback in install.sh == VERSION
# ---------------------------------------------------------------------------
SH_EMBEDDED="$(grep -m1 'VERSION="[0-9]' "${REPO_ROOT}/install.sh" | sed 's/.*VERSION="\([^"]*\)".*/\1/')"
assert_eq "install.sh embedded fallback" "$VERSION" "$SH_EMBEDDED"

# ---------------------------------------------------------------------------
# 4. Embedded fallback in install.ps1 == VERSION
# ---------------------------------------------------------------------------
PS_EMBEDDED="$(grep -m1 "\\\$AppVersion = '" "${REPO_ROOT}/install.ps1" | sed "s/.*AppVersion = '\\([^']*\\)'.*/\\1/")"
assert_eq "install.ps1 embedded fallback" "$VERSION" "$PS_EMBEDDED"

# ---------------------------------------------------------------------------
# 5. BL-005 add-on: REPO slug identical in both installers
# ---------------------------------------------------------------------------
SH_REPO="$(grep -m1 '^REPO=' "${REPO_ROOT}/install.sh" | sed 's/REPO="\(.*\)"/\1/')"
# shellcheck disable=SC2016  # single quotes are intentional: matching literal $Repo
PS_REPO="$(grep -m1 '^\$Repo = ' "${REPO_ROOT}/install.ps1" | sed "s/.*Repo = '\\([^']*\\)'.*/\\1/")"
assert_eq "BL-005 repo slug parity (sh vs ps1)" "$SH_REPO" "$PS_REPO"
pass "BL-005 slug parity: $SH_REPO"

# BL-005 README add-on: every github.com / raw.githubusercontent.com URL in README.md
# must use the same owner/repo slug as the installers.
# Extract "owner/repo" from all GitHub URL occurrences; each must equal $SH_REPO.
BAD_README_SLUGS=""
while IFS= read -r slug; do
  [ "$slug" = "$SH_REPO" ] || BAD_README_SLUGS="${BAD_README_SLUGS}\n  unexpected: '${slug}'"
done < <(grep -oE '(github\.com|raw\.githubusercontent\.com)/[^/]+/[^/ )]+' \
           "${REPO_ROOT}/README.md" \
         | sed 's|[^/]*/||' | sort -u)
[ -z "$BAD_README_SLUGS" ] || fail "BL-005 README slugs mismatch:${BAD_README_SLUGS}"
pass "BL-005 README slugs all match: $SH_REPO"

# ---------------------------------------------------------------------------
# 6. Runtime: bash install.sh --version
# ---------------------------------------------------------------------------
SH_OUT="$(bash "${REPO_ROOT}/install.sh" --version)"
assert_eq "install.sh --version output" "claude-dev-agents ${VERSION}" "$SH_OUT"

# ---------------------------------------------------------------------------
# 7. Git-tag / CHANGELOG add-on
#    Pass if tag v<VERSION> exists OR the newest versioned CHANGELOG entry == VERSION.
# ---------------------------------------------------------------------------
TAG_EXISTS=0
if git -C "$REPO_ROOT" tag --list "v${VERSION}" | grep -q "v${VERSION}"; then
  TAG_EXISTS=1
fi

CHANGELOG_VER="$(grep -m1 '^## \[[0-9]' "${REPO_ROOT}/CHANGELOG.md" | sed 's/## \[\([^]]*\)\].*/\1/')"

if [ "$TAG_EXISTS" = "1" ]; then
  pass "git-tag add-on: tag v${VERSION} exists"
elif [ "$CHANGELOG_VER" = "$VERSION" ]; then
  pass "git-tag add-on: no tag yet but CHANGELOG top entry = $VERSION (pre-release OK)"
else
  fail "git-tag add-on: no tag v${VERSION} AND CHANGELOG top versioned entry is '$CHANGELOG_VER'"
fi

echo "=== all version checks passed ==="
