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

# Synthetic fixture: GitLab CI jobs (reserved keys and hidden templates
# skipped, extends: jobs kept) and pip-compile lockfiles (--hash= outputs).
FIX_DIR="${TMP}/fixture"
mkdir -p "$FIX_DIR/.github/workflows"
cat > "$FIX_DIR/.gitlab-ci.yml" <<'EOF'
stages:
  - test
  - build
variables:
  PIP_CACHE_DIR: .cache/pip
default:
  image: python:3.12
include:
  - local: ci/common.yml
.pytest-base:
  stage: test
  script: pytest
pytest:
  extends: .pytest-base
build-dev:
  stage: build
  script: echo build
pages:
  stage: build
  script: mkdocs build
EOF
cat > "$FIX_DIR/.github/workflows/ci.yml" <<'EOF'
name: ci
on: [push]
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - run: echo lint
  unit:
    runs-on: ubuntu-latest
    steps:
      - run: echo unit
EOF
cat > "$FIX_DIR/requirements.lock" <<'EOF'
example-lib==1.0.0 \
    --hash=sha256:abc
EOF
cat > "$FIX_DIR/requirements.txt" <<'EOF'
example-lib==1.0.0
EOF
cat > "$FIX_DIR/requirements-dev.lock" <<'EOF'
example-test-lib==2.0.0 \
    --hash=sha256:def
EOF

compare_tree repo    "$REPO_ROOT"
compare_tree empty   "$EMPTY_DIR"
compare_tree fixture "$FIX_DIR"

# fixture: ci-job lines, exact set and order
expected_jobs="ci-job: .github/workflows/ci.yml:lint
ci-job: .github/workflows/ci.yml:unit
ci-job: .gitlab-ci.yml:pytest
ci-job: .gitlab-ci.yml:build-dev
ci-job: .gitlab-ci.yml:pages"
actual_jobs="$(grep '^ci-job: ' "${TMP}/fixture.sh.norm" || true)"
if [ "$actual_jobs" != "$expected_jobs" ]; then
  echo "  FAIL  fixture: ci-job lines differ; expected:" >&2
  echo "$expected_jobs" >&2
  echo "  got:" >&2
  echo "$actual_jobs" >&2
  exit 1
fi
pass "fixture: ci-job lists GitHub jobs then GitLab jobs (reserved keys and .templates skipped)"

# fixture: pip-compile outputs are lockfiles, plain requirements.txt is a manifest
grep -qx 'lockfile: requirements-dev.lock' "${TMP}/fixture.sh.norm" || fail "fixture: missing lockfile: requirements-dev.lock"
grep -qx 'lockfile: requirements.lock'     "${TMP}/fixture.sh.norm" || fail "fixture: missing lockfile: requirements.lock"
grep -qx 'manifest: requirements.txt'      "${TMP}/fixture.sh.norm" || fail "fixture: missing manifest: requirements.txt"
if grep -qx 'lockfile: requirements.txt' "${TMP}/fixture.sh.norm"; then
  fail "fixture: requirements.txt without hashes reported as lockfile"
fi
pass "fixture: requirements*.lock with --hash= are lockfiles, requirements.txt stays a manifest"

# The empty tree must degrade fully: no path may be reported there.
if grep -Ev '^(#|repo: |[a-z-]+: (none|absent|0)$)' "${TMP}/empty.sh.norm" | grep -q .; then
  echo "  FAIL  empty: unexpected non-empty signal:" >&2
  grep -Ev '^(#|repo: |[a-z-]+: (none|absent|0)$)' "${TMP}/empty.sh.norm" >&2
  exit 1
fi
pass "empty: every signal is none/absent/0"

echo "=== pipeline-signals-parity.sh: all checks passed ==="
