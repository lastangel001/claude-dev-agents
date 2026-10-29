#!/usr/bin/env bash
# routing-cases-check.sh — deterministic check of eval/routing/cases.yaml (free, runs in CI).
#   - every `expect:` and every name in `accept: [...]` exists as agents/<name>.md or skills/<name>/
#     (`none` = the main loop handles the request itself)
#   - ids are unique and at least 10 cases are present
#   - every case has request, expect and why
# The model run itself is manual: eval/routing/run-routing-eval.sh or the subagent pattern.
# POSIX tools only.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CASES="${REPO_ROOT}/eval/routing/cases.yaml"

FAILS=0
pass() { echo "  PASS  $*"; }
fail() { echo "  FAIL  $*" >&2; FAILS=$((FAILS + 1)); }

echo "=== routing-cases-check.sh ==="
[ -f "$CASES" ] || { echo "cases file not found: $CASES" >&2; exit 1; }

exists() {
  [ "$1" = "none" ] || [ -f "${REPO_ROOT}/agents/$1.md" ] || [ -f "${REPO_ROOT}/skills/$1/SKILL.md" ]
}

IDS="$(awk '/^- id:/ { print $3 }' "$CASES")"
N="$(printf '%s\n' "$IDS" | grep -c . || true)"
[ "$N" -ge 10 ] && pass "$N cases" || fail "only $N cases (need at least 10)"
DUP="$(printf '%s\n' "$IDS" | sort | uniq -d)"
[ -z "$DUP" ] && pass "ids unique" || fail "duplicate ids: $DUP"

for key in request expect why; do
  K="$(grep -c "^  ${key}:" "$CASES" || true)"
  [ "$K" -eq "$N" ] && pass "every case has ${key}" || fail "${K} of ${N} cases have ${key}"
done

# expected and accepted names
NAMES="$( { awk '/^  expect:/ { print $2 }' "$CASES"
            awk '/^  accept:/ { sub(/^  accept: *\[/, ""); sub(/\].*$/, ""); gsub(/,/, " "); print }' "$CASES"; } \
          | tr ' ' '\n' | grep . | sort -u)"
BAD=0
for n in $NAMES; do
  exists "$n" || { fail "unknown target: $n"; BAD=1; }
done
[ "$BAD" -eq 0 ] && pass "all targets exist in agents/ or skills/"

echo
if [ "$FAILS" -gt 0 ]; then
  echo "=== routing-cases-check.sh: $FAILS failure(s) ===" >&2
  exit 1
fi
echo "=== routing-cases-check.sh: all checks passed ==="
