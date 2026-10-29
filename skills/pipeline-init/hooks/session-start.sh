#!/usr/bin/env bash
# session-start.sh — one-line reminder when a repository has code but no docs/PIPELINE.md.
#
# Claude Code SessionStart hook. Prints nothing when there is nothing to say, so it is safe to
# leave enabled. Install (settings.json):
#   "hooks": { "SessionStart": [ { "hooks": [ { "type": "command",
#     "command": "bash ~/.claude/skills/pipeline-init/hooks/session-start.sh" } ] } ] }
set -u

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
[ -f "$root/docs/PIPELINE.md" ] && exit 0

# "Has code": a manifest at the root, or a source directory. Nothing to remind about otherwise.
has_code=0
for f in package.json composer.json pyproject.toml requirements.txt go.mod Cargo.toml pom.xml build.gradle Gemfile mix.exs; do
  [ -f "$root/$f" ] && has_code=1 && break
done
if [ "$has_code" -eq 0 ]; then
  for d in src app lib pkg cmd internal; do
    [ -d "$root/$d" ] && has_code=1 && break
  done
fi
[ "$has_code" -eq 1 ] || exit 0

echo "pipeline-init: this repository has code but no docs/PIPELINE.md — run /pipeline-init to record which agents run when."
exit 0
