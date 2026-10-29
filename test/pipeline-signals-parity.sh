#!/usr/bin/env bash
# pipeline-signals-parity.sh — assert pipeline-signals.sh and pipeline-signals.ps1
# print byte-identical output (after BOM/CR normalisation) on the same tree.
#
# Runs on two trees: this repo's root and an empty temp directory that is not a
# git repo (every section must degrade to none/absent there, and both scripts
# must still exit 0).
#
# PIPELINE_PS            PowerShell binary to use (default: pwsh). Locally on
#                        Windows: PIPELINE_PS=powershell (5.1).
# PIPELINE_PARITY_OPTIONAL=1
#                        when the binary is missing, print SKIP and exit 0
#                        instead of failing.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

pass() { echo "  PASS  $*"; }
fail() { echo "  FAIL  $*" >&2; exit 1; }

echo "=== pipeline-signals-parity.sh ==="

PS_BIN="${PIPELINE_PS:-pwsh}"
if ! command -v "$PS_BIN" >/dev/null 2>&1; then
  echo "  SKIP  ${PS_BIN} not on PATH"
  if [ "${PIPELINE_PARITY_OPTIONAL:-0}" = "1" ]; then
    exit 0
  fi
  fail "${PS_BIN} not on PATH (set PIPELINE_PS, or PIPELINE_PARITY_OPTIONAL=1 to skip)"
fi

SH_SCRIPT="${REPO_ROOT}/skills/pipeline-init/scripts/pipeline-signals.sh"
PS_SCRIPT="${REPO_ROOT}/skills/pipeline-init/scripts/pipeline-signals.ps1"
[ -f "$SH_SCRIPT" ] || fail "missing: $SH_SCRIPT"
[ -f "$PS_SCRIPT" ] || fail "missing: $PS_SCRIPT"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
EMPTY_DIR="${TMP}/empty"
mkdir -p "$EMPTY_DIR"

# normalize <input> <output>: strip BOM, strip CR
normalize() {
  local src="$1" dst="$2"
  sed '1s/^\xEF\xBB\xBF//' "$src" | tr -d '\r' > "$dst"
}

# compare_tree <label> <root-dir>
compare_tree() {
  local label="$1" root="$2"
  local out_sh="${TMP}/${label}.sh.txt" out_ps="${TMP}/${label}.ps.txt"

  bash "$SH_SCRIPT" "$root" > "$out_sh" || fail "${label}: bash script failed"
  pass "${label}: bash script ran"

  "$PS_BIN" -NoProfile -File "$PS_SCRIPT" "$root" > "$out_ps" || fail "${label}: ${PS_BIN} script failed"
  pass "${label}: ${PS_BIN} script ran"

  [ -s "$out_sh" ] || fail "${label}: bash output empty"
  grep -q '^# pipeline-signals$' "$out_sh" || fail "${label}: bash output missing header"

  normalize "$out_sh" "${TMP}/${label}.sh.norm"
  normalize "$out_ps" "${TMP}/${label}.ps.norm"

  local diff_out
  diff_out="$(diff "${TMP}/${label}.sh.norm" "${TMP}/${label}.ps.norm" || true)"
  if [ -n "$diff_out" ]; then
    echo "  FAIL  ${label}: normalized outputs differ (bash < > ${PS_BIN}):" >&2
    echo "$diff_out" >&2
    exit 1
  fi
  pass "${label}: outputs identical"
}

compare_tree repo  "$REPO_ROOT"
compare_tree empty "$EMPTY_DIR"

# The empty tree must degrade fully: no path may be reported there.
if grep -Ev '^(#|repo: |[a-z-]+: (none|absent|0)$)' "${TMP}/empty.sh.norm" | grep -q .; then
  echo "  FAIL  empty: unexpected non-empty signal:" >&2
  grep -Ev '^(#|repo: |[a-z-]+: (none|absent|0)$)' "${TMP}/empty.sh.norm" >&2
  exit 1
fi
pass "empty: every signal is none/absent/0"

echo "=== pipeline-signals-parity.sh: all checks passed ==="
