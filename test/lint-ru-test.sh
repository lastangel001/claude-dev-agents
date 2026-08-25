#!/usr/bin/env bash
# lint-ru-test.sh — regression suite for skills/ru-output-style/scripts/lint-ru.sh
# Run with: bash test/lint-ru-test.sh
#
# Fixture-driven: for every test/fixtures/lint-ru/*.expect there is a fixture file
# with the same name minus the .expect suffix (extension varies: .md or .html).
# Expect-file directives, one per line:
#   EXIT <n>          required — linter exit code on the fixture
#   STRICT_EXIT <n>   optional — exit code with --strict
#   HAS <substring>   output must contain the substring (fixed string, not regex)
# Assertions are presence-based on purpose: new linter checks may add lines to the
# output without breaking existing fixtures.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LINTER="${REPO_ROOT}/skills/ru-output-style/scripts/lint-ru.sh"
FIXDIR="${REPO_ROOT}/test/fixtures/lint-ru"

pass() { echo "  PASS  $*"; }
fail() { echo "  FAIL  $*" >&2; exit 1; }

echo "=== lint-ru-test.sh ==="
[ -f "$LINTER" ] || fail "linter not found: $LINTER"

TOTAL=0
for exp in "${FIXDIR}"/*.expect; do
  [ -e "$exp" ] || fail "no fixtures found in ${FIXDIR}"
  fixture="${exp%.expect}"
  name="$(basename "$fixture")"
  [ -f "$fixture" ] || fail "${name}: fixture file missing for $(basename "$exp")"

  set +e
  OUT="$(bash "$LINTER" "$fixture" 2>&1)"
  RC=$?
  set -e

  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      "") continue ;;
      EXIT\ *)
        want="${line#EXIT }"
        [ "$RC" = "$want" ] || { echo "$OUT" >&2; fail "${name}: exit $RC, expected $want"; }
        ;;
      STRICT_EXIT\ *)
        want="${line#STRICT_EXIT }"
        set +e
        bash "$LINTER" --strict "$fixture" >/dev/null 2>&1
        src=$?
        set -e
        [ "$src" = "$want" ] || fail "${name}: --strict exit $src, expected $want"
        ;;
      HAS\ *)
        needle="${line#HAS }"
        printf '%s' "$OUT" | grep -qF -- "$needle" \
          || { echo "$OUT" >&2; fail "${name}: output missing '${needle}'"; }
        ;;
      *) fail "${name}: unknown directive in expect file: $line" ;;
    esac
  done < "$exp"

  TOTAL=$((TOTAL + 1))
  pass "$name"
done

echo "=== lint-ru-test.sh: ${TOTAL} fixtures passed ==="
