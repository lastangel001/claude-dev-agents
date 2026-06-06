<#
.SYNOPSIS
  Installer for claude-dev-agents — copies agents + skills into Claude Code config.
  Agents/skills are auto-discovered from the repo; no list to maintain.
.EXAMPLE
  .\install.ps1                  # user scope   (~\.claude)
  .\install.ps1 -Project         # project scope (.\.claude)
  .\install.ps1 -Uninstall
  .\install.ps1 -Uninstall -Project
  irm https://raw.githubusercontent.com/lastangel001/claude-dev-agents/main/install.ps1 | iex
#>
[CmdletBinding()]
param(
  [switch]$Project,
  [switch]$Uninstall
)
$ErrorActionPreference = 'Stop'

$Repo = 'lastangel001/claude-dev-agents'

$Base = if ($Project) { Join-Path (Get-Location) '.claude' } else { Join-Path $HOME '.claude' }
$AgentsDir = Join-Path $Base 'agents'
$SkillsDir = Join-Path $Base 'skills'
$scopeName = if ($Project) { 'project' } else { 'user' }

# Resolve source: local repo dir (if script lives next to agents/) else download tarball.
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { $null }
$src = $null
$tmp = $null
if ($scriptDir -and (Test-Path (Join-Path $scriptDir 'agents'))) {
  $src = $scriptDir
} else {
  $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("cda_" + [System.IO.Path]::GetRandomFileName())
  New-Item -ItemType Directory -Force -Path $tmp | Out-Null
  $tgz = Join-Path $tmp 'repo.tgz'
  Write-Host "Downloading $Repo ..."
  Invoke-WebRequest -Uri "https://github.com/$Repo/archive/refs/heads/main.tar.gz" -OutFile $tgz -UseBasicParsing
  tar -xzf $tgz -C $tmp
  $src = (Get-ChildItem -Path $tmp -Directory -Filter 'claude-dev-agents-*' | Select-Object -First 1).FullName
  if (-not $src -or -not (Test-Path (Join-Path $src 'agents'))) { throw "download looks wrong: no agents/ dir" }
}

# Auto-discover: every .md under agents/, every dir under skills/.
$Agents = @(Get-ChildItem -Path (Join-Path $src 'agents') -Filter '*.md' -File | ForEach-Object { $_.BaseName })
$Skills = @()
$skillsSrc = Join-Path $src 'skills'
if (Test-Path $skillsSrc) {
  $Skills = @(Get-ChildItem -Path $skillsSrc -Directory | ForEach-Object { $_.Name })
}

# Backups go OUTSIDE agents/ and skills/ so Claude Code never loads a .bak as a
# duplicate agent/skill. One timestamped dir per run under $Base\.cda-backups.
$BackupRoot = Join-Path $Base (Join-Path '.cda-backups' (Get-Date -Format 'yyyyMMdd-HHmmss'))
function Backup-IfExists($path) {
  if (Test-Path $path) {
    $rel = $path.Substring($Base.Length).TrimStart('\','/')
    $dest = Join-Path $BackupRoot $rel
    New-Item -ItemType Directory -Force -Path (Split-Path $dest -Parent) | Out-Null
    Move-Item $path $dest
    Write-Host "  backed up -> $dest"
  }
}

if ($Uninstall) {
  Write-Host "Uninstalling from $Base ..."
  foreach ($a in $Agents) { $p = Join-Path $AgentsDir "$a.md"; if (Test-Path $p) { Remove-Item $p -Force; Write-Host "  removed agent $a" } }
  foreach ($s in $Skills) { $p = Join-Path $SkillsDir $s;     if (Test-Path $p) { Remove-Item $p -Recurse -Force; Write-Host "  removed skill $s" } }
  if ($tmp) { Remove-Item $tmp -Recurse -Force }
  Write-Host "Done."
  return
}

Write-Host "Installing claude-dev-agents -> $Base ($scopeName scope)"
New-Item -ItemType Directory -Force -Path $AgentsDir, $SkillsDir | Out-Null

Write-Host "Agents:"
foreach ($a in $Agents) {
  $dst = Join-Path $AgentsDir "$a.md"
  Backup-IfExists $dst
  Copy-Item (Join-Path $src "agents\$a.md") $dst -Force
  Write-Host "  installed agent $a"
}
Write-Host "Skills:"
foreach ($s in $Skills) {
  $dst = Join-Path $SkillsDir $s
  Backup-IfExists $dst
  Copy-Item (Join-Path $src "skills\$s") $dst -Recurse -Force
  Write-Host "  installed skill $s"
}

if ($tmp) { Remove-Item $tmp -Recurse -Force }
Write-Host ""
Write-Host "Done. Restart Claude Code (or start a new session) to pick up the changes."
