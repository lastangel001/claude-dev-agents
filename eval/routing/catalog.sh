#!/usr/bin/env bash
# catalog.sh — print the routing catalog: every agent and skill with its description,
# the way Claude Code presents them when it picks a subagent or activates a skill.
# Used by run-routing-eval.sh and by the subagent pattern (see CLAUDE.md).
# POSIX tools only.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# frontmatter_value FILE KEY — same reader as test/agent-lint.sh
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

echo "# Routing catalog"
echo
echo "## Agents (subagents; spawned with a brief, cannot ask the user)"
echo
for f in "${REPO_ROOT}"/agents/*.md; do
  [ -e "$f" ] || break
  printf -- '- **%s** — %s\n' "$(frontmatter_value "$f" name)" "$(frontmatter_value "$f" description)"
done
echo
echo "## Skills (loaded into the main loop; keep the conversation)"
echo
for f in "${REPO_ROOT}"/skills/*/SKILL.md; do
  [ -e "$f" ] || break
  printf -- '- **%s** — %s\n' "$(frontmatter_value "$f" name)" "$(frontmatter_value "$f" description)"
done
