#!/usr/bin/env bash
# run-routing-eval.sh — model eval of agent/skill routing.
#
# For every case in eval/routing/cases.yaml, asks `claude -p` — given the routing catalog
# (eval/routing/catalog.sh, the same names and descriptions Claude Code sees) — which single
# agent or skill it would route the request to, and compares the answer with `expect` (or any
# name in `accept`). Answers land in eval/out/routing/<id>.txt; a summary table is printed.
# Pass threshold: 87% of cases.
#
# COSTS TOKENS — run manually, not in CI. The free check of the cases file is
# test/routing-cases-check.sh.
#
# NOTE: inside a Claude Code session prefer the subagent pattern (CLAUDE.md) — nested
# `claude -p` cannot refresh OAuth. This script is for a freshly authenticated CLI.
#
# Usage: bash eval/routing/run-routing-eval.sh [--model NAME]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CASES="${REPO_ROOT}/eval/routing/cases.yaml"
OUT="${REPO_ROOT}/eval/out/routing"
MODEL_ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --model) MODEL_ARGS=(--model "$2"); shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

command -v claude >/dev/null 2>&1 || { echo "claude CLI not on PATH" >&2; exit 1; }
mkdir -p "$OUT"
CATALOG="$(bash "${REPO_ROOT}/eval/routing/catalog.sh")"
SYSTEM="You are the routing step of a Claude Code session. The user sent one request. From the catalog below pick the ONE agent or skill the request should go to: an agent when the work should run as a subagent, a skill when it should run in the main loop. If the request is small enough that the main loop should just do it without spawning or loading anything, answer none. Answer with exactly one name from the catalog or none, nothing else.

${CATALOG}"

TOTAL=0; OK=0
printf '%-5s %-26s %-26s %s\n' "id" "expected" "answer" "result"
while IFS= read -r id; do
  req="$(awk -v id="$id" '$0 ~ "^- id: " id "$" { f = 1; next } f && /^  request:/ { sub(/^  request: */, ""); gsub(/^"|"$/, ""); print; exit }' "$CASES")"
  exp="$(awk -v id="$id" '$0 ~ "^- id: " id "$" { f = 1; next } f && /^  expect:/ { print $2; exit }' "$CASES")"
  acc="$(awk -v id="$id" '$0 ~ "^- id: " id "$" { f = 1; next } f && /^- id:/ { exit } f && /^  accept:/ { sub(/^  accept: *\[/, ""); sub(/\].*$/, ""); gsub(/,/, " "); print; exit }' "$CASES")"
  ans="$(printf '%s' "$req" | claude -p "${MODEL_ARGS[@]}" --system-prompt "$SYSTEM" 2>/dev/null | tr -d '\r' | head -n 1 | sed 's/[`*]//g; s/^[ \t]*//; s/[ \t]*$//')"
  printf '%s\n' "$ans" > "${OUT}/${id}.txt"
  TOTAL=$((TOTAL + 1))
  res="FAIL"
  if [ "$ans" = "$exp" ]; then res="PASS"; else for a in $acc; do [ "$ans" = "$a" ] && res="PASS(accept)"; done; fi
  case "$res" in PASS*) OK=$((OK + 1)) ;; esac
  printf '%-5s %-26s %-26s %s\n' "$id" "$exp" "$ans" "$res"
done < <(awk '/^- id:/ { print $3 }' "$CASES")

PCT=$((OK * 100 / TOTAL))
echo
echo "routing eval: ${OK}/${TOTAL} (${PCT}%) — threshold 87%"
[ "$PCT" -ge 87 ]
