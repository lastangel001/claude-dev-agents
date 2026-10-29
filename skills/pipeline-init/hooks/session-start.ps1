# session-start.ps1 - one-line reminder when a repository has code but no docs/PIPELINE.md.
#
# Claude Code SessionStart hook, PowerShell flavour (Windows PowerShell 5.1 and pwsh 7).
# Prints nothing when there is nothing to say. Install (settings.json):
#   "hooks": { "SessionStart": [ { "hooks": [ { "type": "command",
#     "command": "powershell -NoProfile -File $HOME/.claude/skills/pipeline-init/hooks/session-start.ps1" } ] } ] }

$root = $null
try { $root = (git rev-parse --show-toplevel 2>$null) } catch { $root = $null }
if (-not $root) { $root = (Get-Location).Path }

if (Test-Path (Join-Path $root 'docs/PIPELINE.md')) { exit 0 }

$hasCode = $false
foreach ($f in @('package.json','composer.json','pyproject.toml','requirements.txt','go.mod','Cargo.toml','pom.xml','build.gradle','Gemfile','mix.exs')) {
  if (Test-Path (Join-Path $root $f)) { $hasCode = $true; break }
}
if (-not $hasCode) {
  foreach ($d in @('src','app','lib','pkg','cmd','internal')) {
    if (Test-Path (Join-Path $root $d) -PathType Container) { $hasCode = $true; break }
  }
}
if (-not $hasCode) { exit 0 }

Write-Output 'pipeline-init: this repository has code but no docs/PIPELINE.md - run /pipeline-init to record which agents run when.'
exit 0
