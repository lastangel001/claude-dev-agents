#!/usr/bin/env bash
# pipeline-signals.sh — print the repository signals pipeline-init reads
# (memory files, stack manifests, CI, review process, reversibility, tests,
# tracker prefixes, docs dirs) as plain text.
#
# Usage: pipeline-signals.sh [repo-root]
#   repo-root defaults to `git rev-parse --show-toplevel`, then to the cwd.
#
# Output contract: byte-identical to pipeline-signals.ps1 (after BOM/CR
# normalisation); test/pipeline-signals-parity.sh enforces it. Paths are
# relative to the root, forward slashes, no leading "./"; lists are sorted in
# C-locale byte order; every "## section" is always printed.
#
# Portability: POSIX tools only (find/grep/awk/sort/uniq/sed/wc). No sed -i,
# no grep -P, no GNU-only flags; must run on macOS and Linux.
set -euo pipefail

export LC_ALL=C

# ---------------------------------------------------------------------------
# root
# ---------------------------------------------------------------------------
ROOT="${1:-}"
if [ -z "$ROOT" ]; then
  ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  [ -n "$ROOT" ] || ROOT="$(pwd)"
fi
[ -d "$ROOT" ] || { echo "pipeline-signals: not a directory: $ROOT" >&2; exit 1; }
cd "$ROOT"
ROOT="$(pwd)"

# Excluded directories (pruned from every recursive search)
EXCL='( -name .git -o -name node_modules -o -name vendor -o -name dist -o -name build -o -name .venv -o -name venv -o -name __pycache__ -o -name .next -o -name target )'

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
# strip leading "./" and sort in byte order
rel_sort() { sed 's|^\./||' | sort; }

# present_file <key> <file>...   -> "<key>: present" if any file exists
present_file() {
  local key="$1"; shift
  local f
  for f in "$@"; do
    if [ -f "$f" ]; then echo "$key: present"; return 0; fi
  done
  echo "$key: absent"
}

# list_or_none <key>   (stdin: lines) -> "<key>: <line>" per line, or "<key>: none"
list_or_none() {
  local key="$1" any=0 line
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    echo "$key: $line"; any=1
  done
  [ "$any" -eq 1 ] || echo "$key: none"
}

# root_files <key> <name>...   -> existing root files among names, sorted
root_files() {
  local key="$1"; shift
  local f
  for f in "$@"; do if [ -f "$f" ]; then echo "$f"; fi; done | sort | list_or_none "$key"
}

# find_dirs <maxdepth> <name>...   -> matching dirs (relative), excluded pruned
find_dirs() {
  local depth="$1"; shift
  local expr="" n
  for n in "$@"; do
    if [ -z "$expr" ]; then expr="-name $n"; else expr="$expr -o -name $n"; fi
  done
  # shellcheck disable=SC2086  # EXCL/expr are deliberately word-split
  find . -maxdepth "$depth" \( -type d $EXCL -prune \) -o -type d \( $expr \) -print
}

# find_files_named <maxdepth> <pattern>...   -> matching files (relative)
find_files_named() {
  local depth="$1"; shift
  local expr="" p
  for p in "$@"; do
    if [ -z "$expr" ]; then expr="-name $p"; else expr="$expr -o -name $p"; fi
  done
  # shellcheck disable=SC2086
  find . -maxdepth "$depth" \( -type d $EXCL -prune \) -o -type f \( $expr \) -print
}

# ---------------------------------------------------------------------------
echo "# pipeline-signals"
echo "repo: $(basename "$ROOT")"

# ---------------------------------------------------------------------------
echo "## memory"
present_file claude-md CLAUDE.md
present_file claude-docs-architecture .claude-docs/architecture.md
present_file pipeline-md docs/PIPELINE.md

# ---------------------------------------------------------------------------
echo "## stack"
root_files manifest package.json composer.json pyproject.toml requirements.txt go.mod \
  Cargo.toml pom.xml build.gradle build.gradle.kts Gemfile mix.exs
# lockfile: known lockfile names, plus pip-compile outputs at the root
# (requirements*.lock / requirements*.txt containing "--hash="); a plain
# requirements.txt without hashes stays a manifest.
{
  for f in package-lock.json pnpm-lock.yaml yarn.lock bun.lockb composer.lock \
           poetry.lock uv.lock Pipfile.lock Cargo.lock go.sum Gemfile.lock; do
    if [ -f "$f" ]; then echo "$f"; fi
  done
  for f in requirements*.lock requirements*.txt; do
    if [ -f "$f" ] && grep -q -e '--hash=' "$f"; then echo "$f"; fi
  done
} | sort | list_or_none lockfile

# ---------------------------------------------------------------------------
echo "## ci"
GH_WORKFLOWS=""
if [ -d .github/workflows ]; then
  GH_WORKFLOWS="$(find .github/workflows -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) -print | rel_sort)"
fi
{
  [ -z "$GH_WORKFLOWS" ] || printf '%s\n' "$GH_WORKFLOWS"
  for f in .gitlab-ci.yml Jenkinsfile .circleci/config.yml azure-pipelines.yml bitbucket-pipelines.yml; do
    if [ -f "$f" ]; then echo "$f"; fi
  done
} | sort | list_or_none ci-file

# ci-job: top-level keys under "jobs:" in each GitHub workflow, in file order;
# then every top-level key of .gitlab-ci.yml that is neither a reserved
# keyword nor a hidden ".template" (jobs declared via extends: included).
{
  if [ -n "$GH_WORKFLOWS" ]; then
    printf '%s\n' "$GH_WORKFLOWS" | while IFS= read -r wf; do
      awk -v file="$wf" '
        { sub(/\r$/, "") }
        /^jobs:/ { injobs = 1; next }
        injobs && /^[^ \t#]/ { injobs = 0 }
        injobs && /^  [A-Za-z_][A-Za-z0-9_-]*:/ {
          k = $1; sub(/:.*/, "", k); print file ":" k
        }' "$wf"
    done
  fi
  if [ -f .gitlab-ci.yml ]; then
    awk -v file=.gitlab-ci.yml '
      BEGIN {
        split("stages variables default include workflow image services cache before_script after_script", r, " ")
        for (i in r) reserved[r[i]] = 1
      }
      { sub(/\r$/, "") }
      /^[A-Za-z0-9_.-]+:/ {
        k = $0; sub(/:.*/, "", k)
        if (k ~ /^\./ || (k in reserved)) next
        print file ":" k
      }' .gitlab-ci.yml
  fi
} | list_or_none ci-job

# ---------------------------------------------------------------------------
echo "## review-process"
present_file codeowners CODEOWNERS .github/CODEOWNERS docs/CODEOWNERS
if [ -f .github/PULL_REQUEST_TEMPLATE.md ] || [ -f .github/pull_request_template.md ] \
   || [ -f PULL_REQUEST_TEMPLATE.md ] \
   || { [ -d .gitlab/merge_request_templates ] \
        && [ -n "$(find .gitlab/merge_request_templates -type f -print | head -1)" ]; }; then
  echo "pr-template: present"
else
  echo "pr-template: absent"
fi

# ---------------------------------------------------------------------------
echo "## reversibility"
{
  find_dirs 4 migrations migrate alembic
  for d in db/migrate database/migrations; do if [ -d "$d" ]; then echo "$d"; fi; done
} | rel_sort | uniq | list_or_none migrations-dir

find_files_named 4 'openapi*.yml' 'openapi*.yaml' 'openapi*.json' \
  'swagger*.yml' 'swagger*.yaml' 'swagger*.json' '*.proto' '*.graphql' \
  | rel_sort | list_or_none api-schema

CLIENT_RE='requests\.|httpx|aiohttp|guzzle|axios|fetch\(|grpc|amqp|kafka|celery|bullmq|sqs|pubsub|Queue::'
# shellcheck disable=SC2086
CLIENT_N="$(find . \( -type d $EXCL -prune \) -o -type f \
  \( -name '*.py' -o -name '*.php' -o -name '*.js' -o -name '*.ts' -o -name '*.go' \
     -o -name '*.rb' -o -name '*.java' -o -name '*.cs' -o -name '*.kt' \) \
  -exec grep -lE "$CLIENT_RE" {} + 2>/dev/null | wc -l | tr -d ' \t')"
echo "external-client-files: ${CLIENT_N:-0}"

# ---------------------------------------------------------------------------
echo "## tests"
find_dirs 2 tests test __tests__ spec e2e cypress playwright | rel_sort | list_or_none test-dir
root_files test-config pytest.ini setup.cfg tox.ini phpunit.xml phpunit.xml.dist \
  jest.config.js jest.config.ts jest.config.mjs vitest.config.ts vitest.config.js vitest.config.mts \
  playwright.config.ts playwright.config.js cypress.config.ts cypress.config.js \
  .mocharc.yml .mocharc.json

# ---------------------------------------------------------------------------
echo "## tracker"
if git rev-parse --show-toplevel >/dev/null 2>&1; then
  git log -200 --format=%s 2>/dev/null \
    | { grep -oE '[A-Z][A-Z0-9]{1,9}-[0-9]+' || true; } \
    | sed 's/-.*$//' | sort | uniq -c \
    | sort -k1,1nr -k2,2 | head -3 \
    | awk '{ print $2 " " $1 }' | list_or_none tracker-prefix
else
  echo "tracker-prefix: none"
fi

# ---------------------------------------------------------------------------
echo "## docs"
for d in docs/adr docs/qa docs/backlog docs/architecture docs/decisions; do
  if [ -d "$d" ]; then echo "$d"; fi
done | sort | list_or_none docs-dir
