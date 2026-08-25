#!/usr/bin/env bash
# run-model-eval.sh — model eval for the ru-output-style skill.
#
# Feeds slop-bait prompts (eval/ru-output-style/prompts/*.txt) to `claude -p` with
# the skill (SKILL.md + patterns.md + gold.md) appended as system prompt, then runs
# the deterministic linter over each answer. A prompt passes when its answer has
# zero hard bans. Exit 1 if any skill-mode answer fails.
#
# COSTS TOKENS — run manually, not in CI. The deterministic regression suite for
# the linter itself is test/lint-ru-test.sh (free, runs in CI).
#
# Usage:
#   bash eval/ru-output-style/run-model-eval.sh [--model NAME] [--baseline] [--strict]
#     --model NAME   pass through to claude -p (default: CLI default model)
#     --baseline     additionally run each prompt WITHOUT the skill, to show the delta
#     --strict       a skill-mode answer also fails on warnings, not only bans
#
# Outputs land in eval/out/<prompt>.<skill|baseline>.md (gitignored).
set -euo pipefail

EVAL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${EVAL_DIR}/../.." && pwd)"
SKILL_DIR="${REPO_ROOT}/skills/ru-output-style"
LINTER="${SKILL_DIR}/scripts/lint-ru.sh"
PROMPTS_DIR="${EVAL_DIR}/prompts"
OUT_DIR="${REPO_ROOT}/eval/out"

MODEL=""
BASELINE=0
STRICT=0
while [ $# -gt 0 ]; do
  case "$1" in
    --model)    shift; [ $# -gt 0 ] || { echo "--model requires a name" >&2; exit 2; }; MODEL="$1" ;;
    --baseline) BASELINE=1 ;;
    --strict)   STRICT=1 ;;
    -h|--help)  grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done

command -v claude >/dev/null || { echo "claude CLI not found on PATH" >&2; exit 2; }
[ -f "$LINTER" ] || { echo "linter not found: $LINTER" >&2; exit 2; }

CLAUDE_ARGS=()
[ -n "$MODEL" ] && CLAUDE_ARGS+=(--model "$MODEL")

mkdir -p "$OUT_DIR"

# The style guide is ~30 KB — too large for a CLI argument on Windows ("Argument
# list too long"), so both the guide and the task go to `claude -p` via stdin.
run_one() {  # $1 prompt file, $2 mode (skill|baseline) -> writes answer, echoes path
  local pf="$1" mode="$2" name out
  name="$(basename "$pf" .txt)"
  out="${OUT_DIR}/${name}.${mode}.md"
  if [ "$mode" = "skill" ]; then
    {
      echo "You write Russian prose for humans. Follow this style skill strictly"
      echo "(hard bans, gold examples, final check) for every Russian sentence:"
      echo
      cat "${SKILL_DIR}/SKILL.md" "${SKILL_DIR}/references/patterns.md" "${SKILL_DIR}/references/gold.md"
      echo
      echo "ЗАДАЧА:"
      cat "$pf"
    } | claude -p "${CLAUDE_ARGS[@]+"${CLAUDE_ARGS[@]}"}" > "$out"
  else
    claude -p "${CLAUDE_ARGS[@]+"${CLAUDE_ARGS[@]}"}" < "$pf" > "$out"
  fi
  # A missing/empty/near-empty answer is a plumbing failure, not a style pass.
  if [ ! -s "$out" ] || [ "$(wc -c < "$out")" -lt 200 ]; then
    echo "ERROR: answer for ${name} (${mode}) is empty or suspiciously short: $out" >&2
    return 1
  fi
  echo "$out"
}

FAILED=0
TOTAL=0
echo "=== ru-output-style model eval (model: ${MODEL:-cli default}) ==="
for pf in "${PROMPTS_DIR}"/*.txt; do
  [ -e "$pf" ] || { echo "no prompts in ${PROMPTS_DIR}" >&2; exit 2; }
  name="$(basename "$pf" .txt)"
  TOTAL=$((TOTAL + 1))

  set +e
  out="$(run_one "$pf" skill)"
  ro=$?
  set -e
  if [ "$ro" -ne 0 ]; then
    FAILED=$((FAILED + 1))
    echo "  FAIL  ${name}  (no answer from claude -p)"
    continue
  fi
  set +e
  if [ "$STRICT" = "1" ]; then
    LINT_OUT="$(bash "$LINTER" --strict "$out" 2>&1)"
  else
    LINT_OUT="$(bash "$LINTER" "$out" 2>&1)"
  fi
  RC=$?
  set -e
  SUMMARY="$(printf '%s\n' "$LINT_OUT" | grep '^lint-ru:' | sed 's/^lint-ru: //')"
  if [ "$RC" -eq 0 ]; then
    echo "  PASS  ${name}  (${SUMMARY##* - })"
  else
    FAILED=$((FAILED + 1))
    echo "  FAIL  ${name}  (${SUMMARY##* - })"
    printf '%s\n' "$LINT_OUT" | grep -v '^lint-ru:' | sed 's/^/        /'
  fi

  if [ "$BASELINE" = "1" ]; then
    set +e
    bout="$(run_one "$pf" baseline)" \
      && BASE_OUT="$(bash "$LINTER" "$bout" 2>&1)" \
      && BASE_SUMMARY="$(printf '%s\n' "$BASE_OUT" | grep '^lint-ru:' | sed 's/^lint-ru: //')" \
      && echo "        baseline: ${BASE_SUMMARY##* - }" \
      || echo "        baseline: no answer"
    set -e
  fi
done

echo "=== model eval: $((TOTAL - FAILED))/${TOTAL} prompts clean; answers in eval/out/ ==="
[ "$FAILED" -eq 0 ]
