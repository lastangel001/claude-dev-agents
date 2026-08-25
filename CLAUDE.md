# CLAUDE.md — claude-dev-agents

Entry point for Claude Code agents working on this repo.

## Commands

- `bash test/smoke.sh` — install→assert→uninstall round-trip (bash)
- `powershell -NoProfile -File test/smoke.ps1` — same, PS 5.1
- `bash test/version-check.sh` — VERSION/fallbacks/README-slug/tag consistency
- `bash test/parity.sh` — bash vs pwsh7 manifest parity (needs pwsh on PATH; CI covers it)
- `bash test/lint-ru-test.sh` — fixture regression for the ru-output-style linter (in CI)
- `bash eval/ru-output-style/run-model-eval.sh` — model eval of the skill via `claude -p`
  (COSTS TOKENS, manual only, never CI; needs authenticated `claude` CLI)
  - **Preferred way to run the model eval: subagents from an interactive session, NOT the
    script.** Nested `claude -p` cannot refresh OAuth ("OAuth session expired and could
    not be refreshed") and Andrey rejected the re-login flow. Pattern (validated
    2026-08-25, skill 5/5 clean vs baseline 2/5 with bans): spawn 2 agents per prompt in
    `eval/ru-output-style/prompts/` — one reads SKILL.md + references/patterns.md +
    references/gold.md then answers, one answers bare — each Writes only the final
    Russian text to `eval/out/<prompt>.{skill,baseline}.md`; then lint every file with
    `bash skills/ru-output-style/scripts/lint-ru.sh` and report bans/warnings per pair.
- `.\install.ps1` — reinstall into `~/.claude` (user scope)

## Release discipline (MUST)

**Every change ships as a release.** No "land it and release later". The full ritual:

1. Update **all affected `.md` files** — README (tables, feature descriptions), CHANGELOG,
   agent/skill docs touched by the change.
2. Bump `VERSION` (SemVer: agent/skill behavior = minor, fixes = patch) **and** the embedded
   fallbacks: `VERSION="x.y.z"` in `install.sh`, `$AppVersion = 'x.y.z'` in `install.ps1`.
3. Update the README version badge (`img.shields.io/badge/version-x.y.z-blue`).
4. CHANGELOG: split `[Unreleased]` into `[x.y.z] — YYYY-MM-DD`.
5. `bash test/version-check.sh` and both smoke tests must pass locally.
6. Commit, `git tag vX.Y.Z`, push `main` **and** the tag.
7. Create the **GitHub release** from the tag, marked Latest:
   `gh release create vX.Y.Z --title "vX.Y.Z — <short theme>" --notes "<CHANGELOG section>"`.
8. Reinstall locally (`.\install.ps1`) so `~/.claude` matches the release.

## Boundaries

### MUST
- Keep `*.md`, `*.sh`, `*.ps1` LF (`.gitattributes` pins it); new `.sh` files get the exec bit
  (`git update-index --chmod=+x`).
- `install.sh`/`install.ps1` stay behaviorally identical — `test/parity.sh` enforces it.

### MUST NOT
- Expressions in step-level `shell:` in workflows — GitHub rejects the whole file at parse
  time (CI ran 0s with no jobs for 4 days because of this).
- GNU-only flags in test scripts (`sed -i` w/o suffix breaks BSD sed on macOS CI).
