<#
.SYNOPSIS
  Installer for claude-dev-agents — copies agents + skills into Claude Code config.
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

$Repo   = 'lastangel001/claude-dev-agents'
$Agents = @('php-developer','php-reviewer','python-developer','python-reviewer')
$Skills = @('php-patterns','python-patterns')

$Base = if ($Project) { Join-Path (Get-Location) '.claude' } else { Join-Path $HOME '.claude' }
$AgentsDir = Join-Path $Base 'agents'
$SkillsDir = Join-Path $Base 'skills'
$scopeName = if ($Project) { 'project' } else { 'user' }

function Backup-IfExists($path) {
  if (Test-Path $path) {
    $bak = "$path.bak"
    if (Test-Path $bak) { Remove-Item $bak -Recurse -Force }
    Move-Item $path $bak
    Write-Host "  backed up -> $bak"
  }
}

if ($Uninstall) {
  Write-Host "Uninstalling from $Base ..."
  foreach ($a in $Agents) { $p = Join-Path $AgentsDir "$a.md"; if (Test-Path $p) { Remove-Item $p -Force; Write-Host "  removed agent $a" } }
  foreach ($s in $Skills) { $p = Join-Path $SkillsDir $s;     if (Test-Path $p) { Remove-Item $p -Recurse -Force; Write-Host "  removed skill $s" } }
  Write-Host "Done."
  return
}

Write-Host "Installing claude-dev-agents -> $Base ($scopeName scope)"
New-Item -ItemType Directory -Force -Path $AgentsDir, $SkillsDir | Out-Null

# Determine source: local repo dir (if script lives next to agents/) else download tarball.
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
