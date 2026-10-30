#!/usr/bin/env bash
# agent-lint.sh — frontmatter and contract lint for agents/*.md and skills/*/SKILL.md
# Run with: bash test/agent-lint.sh
#
# Agents (agents/*.md):
#   - frontmatter block present (--- on line 1, closed), no CR line endings
#   - name == file basename; description non-empty; model in opus|sonnet|haiku|inherit
#   - tools, when present, is a JSON-style list
#   - exactly one of each contract heading outside fenced code:
#       ## Input   ## Output   ## Handoff   ## Fragile points
#   - the `### Terminal states` block matches docs/AGENT-CONTRACT.md verbatim
#   - the `### Project pipeline` block (inside ## Input) matches docs/AGENT-CONTRACT.md verbatim
# Skills (skills/*/SKILL.md):
#   - frontmatter present, no CR; name == directory name; description non-empty
#
# POSIX tools only (awk, grep, cmp, head); no GNU-only flags — CI runs this on macOS too.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SPEC="${REPO_ROOT}/docs/AGENT-CONTRACT.md"
TMP="${TMPDIR:-/tmp}/agent-lint.$$"
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT

FAILS=0
pass() { echo "  PASS  $*"; }
fail() { echo "  FAIL  $*" >&2; FAILS=$((FAILS + 1)); }

# frontmatter_value FILE KEY -> prints the value of `KEY:` inside the leading --- block
frontmatter_value() {
  awk -v key="$2" '
    NR == 1 { if ($0 != "---") exit; next }
    /^---$/ { exit }
    index($0, key ":") == 1 {
      v = substr($0, length(key) + 2)
      sub(/^[ \t]+/, "", v); sub(/[ \t]+$/, "", v)
      gsub(/^"|"$/, "", v)
      print v; exit
    }
  ' "$1"
}

has_frontmatter() {
  awk 'NR == 1 && $0 != "---" { exit 1 } NR > 1 && /^---$/ { found = 1; exit } END { exit found ? 0 : 1 }' "$1"
}

# heading_count FILE HEADING -> number of lines equal to HEADING outside ``` fences
heading_count() {
  awk -v h="$2" 'BEGIN { c = 0; n = 0 } /^```/ { c = !c; next } c == 0 && $0 == h { n++ } END { print n }' "$1"
}

echo "=== agent-lint.sh ==="
[ -f "$SPEC" ] || { echo "spec not found: $SPEC" >&2; exit 1; }

# The canonical blocks live in ```markdown fences in the spec, each recognised by its first line.
# spec_block HEADING -> prints the fence whose first line is HEADING
spec_block() {
  awk -v h="$1" '
    /^```markdown$/ { infence = 1; first = 1; next }
    /^```$/ { if (p) exit; infence = 0; next }
    infence && first { first = 0; if ($0 == h) p = 1; else infence = 0 }
    p { print }
  ' "$SPEC"
}
spec_block "### Terminal states" > "$TMP/spec.txt"
SPEC_LINES="$(awk 'END { print NR }' "$TMP/spec.txt")"
if [ "$SPEC_LINES" -lt 5 ]; then
  echo "could not extract the terminal-states block from $SPEC" >&2
  exit 1
fi
spec_block "### Project pipeline" > "$TMP/spec2.txt"
SPEC2_LINES="$(awk 'END { print NR }' "$TMP/spec2.txt")"
if [ "$SPEC2_LINES" -lt 3 ]; then
  echo "could not extract the project-pipeline block from $SPEC" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Agents
# ---------------------------------------------------------------------------
AGENTS=0
for f in "${REPO_ROOT}"/agents/*.md; do
  [ -e "$f" ] || break
  AGENTS=$((AGENTS + 1))
  base="$(basename "$f" .md)"
  ok=1

  if grep -q "$(printf '\r')" "$f"; then fail "$base: CR line endings"; ok=0; fi
  if ! has_frontmatter "$f"; then fail "$base: no frontmatter block"; ok=0; fi

  name="$(frontmatter_value "$f" name)"
  [ "$name" = "$base" ] || { fail "$base: frontmatter name '$name' != filename"; ok=0; }

  desc="$(frontmatter_value "$f" description)"
  [ -n "$desc" ] || { fail "$base: description missing or empty"; ok=0; }

  model="$(frontmatter_value "$f" model)"
  case "$model" in
    opus|sonnet|haiku|inherit) ;;
    *) fail "$base: model '$model' not in opus|sonnet|haiku|inherit"; ok=0 ;;
  esac

  tools="$(frontmatter_value "$f" tools)"
  if [ -n "$tools" ]; then
    case "$tools" in
      \[*\]) ;;
      *) fail "$base: tools must be a JSON-style list, got: $tools"; ok=0 ;;
    esac
  fi

  for h in "## Input" "## Output" "## Handoff" "## Fragile points"; do
    n="$(heading_count "$f" "$h")"
    [ "$n" -eq 1 ] || { fail "$base: expected exactly one '$h' outside code fences, found $n"; ok=0; }
  done

  n="$(heading_count "$f" "### Terminal states")"
  if [ "$n" -ne 1 ]; then
    fail "$base: expected exactly one '### Terminal states', found $n"; ok=0
  else
    # awk stops itself: an `awk | head` pipeline dies of SIGPIPE under pipefail on Linux (exit 141)
    awk -v n="$SPEC_LINES" '/^### Terminal states$/ { p = 1 } p { print; c++; if (c >= n) exit }' "$f" > "$TMP/agent.txt"
    if ! cmp -s "$TMP/spec.txt" "$TMP/agent.txt"; then
      fail "$base: terminal-states block differs from docs/AGENT-CONTRACT.md"; ok=0
      diff "$TMP/spec.txt" "$TMP/agent.txt" | head -n 6 >&2 || true
    fi
  fi

  n="$(heading_count "$f" "### Project pipeline")"
  if [ "$n" -ne 1 ]; then
    fail "$base: expected exactly one '### Project pipeline' (inside ## Input), found $n"; ok=0
  else
    awk -v n="$SPEC2_LINES" '/^### Project pipeline$/ { p = 1 } p { print; c++; if (c >= n) exit }' "$f" > "$TMP/agent2.txt"
    if ! cmp -s "$TMP/spec2.txt" "$TMP/agent2.txt"; then
      fail "$base: project-pipeline block differs from docs/AGENT-CONTRACT.md"; ok=0
      diff "$TMP/spec2.txt" "$TMP/agent2.txt" | head -n 6 >&2 || true
    fi
  fi

  [ "$ok" -eq 1 ] && pass "agent $base"
done
[ "$AGENTS" -gt 0 ] || fail "no agents found under agents/"

# ---------------------------------------------------------------------------
# Skills
# ---------------------------------------------------------------------------
SKILLS=0
for f in "${REPO_ROOT}"/skills/*/SKILL.md; do
  [ -e "$f" ] || break
  SKILLS=$((SKILLS + 1))
  dir="$(basename "$(dirname "$f")")"
  ok=1

  if grep -q "$(printf '\r')" "$f"; then fail "skill $dir: CR line endings"; ok=0; fi
  if ! has_frontmatter "$f"; then fail "skill $dir: no frontmatter block"; ok=0; fi

  name="$(frontmatter_value "$f" name)"
  [ "$name" = "$dir" ] || { fail "skill $dir: frontmatter name '$name' != directory"; ok=0; }

  desc="$(frontmatter_value "$f" description)"
  [ -n "$desc" ] || { fail "skill $dir: description missing or empty"; ok=0; }

  [ "$ok" -eq 1 ] && pass "skill $dir"
done
[ "$SKILLS" -gt 0 ] || fail "no skills found under skills/"

echo
if [ "$FAILS" -gt 0 ]; then
  echo "=== agent-lint.sh: $FAILS failure(s) ===" >&2
  exit 1
fi
echo "=== agent-lint.sh: $AGENTS agents, $SKILLS skills — all checks passed ==="
