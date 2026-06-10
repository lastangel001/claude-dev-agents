<#
.SYNOPSIS
  Installer for claude-dev-agents -- copies agents + skills into Claude Code config.
  Agents/skills are auto-discovered from the repo; no list to maintain.
.DESCRIPTION
  Uninstall is receipt-driven (see docs/adr/0001): install writes a manifest of the
  exact files it placed plus a content hash for each. Uninstall removes only files it
  can prove it owns and that the user has not modified. No manifest -> refuse to delete.
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
  [switch]$Uninstall,
  [switch]$Version
)
$ErrorActionPreference = 'Stop'

# Single source of truth for the version: read the sibling VERSION file when
# running from a local checkout; fall back to the embedded constant only for the
# piped-remote case (irm | iex) where $PSScriptRoot is empty / no file is present.
$AppVersion = '1.3.0'
$verFile = if ($PSScriptRoot) { Join-Path $PSScriptRoot 'VERSION' } else { $null }
if ($verFile -and (Test-Path $verFile)) { $AppVersion = (Get-Content $verFile -Raw).Trim() }
if ($Version) { Write-Host "claude-dev-agents $AppVersion"; return }

$Repo = 'lastangel001/claude-dev-agents'

$Base = if ($Project) { Join-Path (Get-Location) '.claude' } else { Join-Path $HOME '.claude' }
$AgentsDir = Join-Path $Base 'agents'
$SkillsDir = Join-Path $Base 'skills'
$scopeName = if ($Project) { 'project' } else { 'user' }
$Manifest  = Join-Path $Base '.cda-manifest'   # "<relpath>`t<sha256>" per line

function Get-Sha($path) { (Get-FileHash -Path $path -Algorithm SHA256).Hash.ToLower() }
function To-Rel($path)  { $path.Substring($Base.Length).TrimStart('\','/') }

if ($Uninstall) {
  Write-Host "Uninstalling from $Base ..."
  if (-not (Test-Path $Manifest)) {
    Write-Error "no install manifest at $Manifest`n  refusing to delete -- cannot prove which files belong to claude-dev-agents.`n  remove unwanted files manually from $AgentsDir and $SkillsDir."
    return
  }
  foreach ($line in Get-Content $Manifest -Encoding utf8) {
    if (-not $line.Trim()) { continue }
    $parts = $line -split "`t", 2
    $rel = $parts[0]; $hash = if ($parts.Count -gt 1) { $parts[1] } else { 'nohash' }
    $target = Join-Path $Base $rel
    if (-not (Test-Path $target)) { Write-Host "  gone, skip   $rel"; continue }
    if ($hash -ne 'nohash') {
      if ((Get-Sha $target) -ne $hash) { Write-Host "  modified, KEPT $rel"; continue }
    } else {
      # No hash available at install time; cannot verify ownership -- keep, do not delete.
      Write-Host "  nohash, KEPT  $rel"; continue
    }
    Remove-Item $target -Force; Write-Host "  removed      $rel"
  }
  # Drop skill dirs left empty after their files were removed.
  if (Test-Path $SkillsDir) {
    Get-ChildItem $SkillsDir -Directory -Recurse |
      Sort-Object { $_.FullName.Length } -Descending |
      Where-Object { -not (Get-ChildItem $_.FullName -Force) } |
      ForEach-Object { Remove-Item $_.FullName -Force }
  }
  Remove-Item $Manifest -Force
  Write-Host "Done."
  return
}

# ---- install ----------------------------------------------------------------

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
  Write-Host "Downloading $Repo v$AppVersion ..."
  # Pin to the released tag, not the moving main tip -- a piped install must fetch
  # exactly the version this script reports, with no surprise upstream content.
  Invoke-WebRequest -Uri "https://github.com/$Repo/archive/refs/tags/v$AppVersion.tar.gz" -OutFile $tgz -UseBasicParsing
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
    $dest = Join-Path $BackupRoot (To-Rel $path)
    New-Item -ItemType Directory -Force -Path (Split-Path $dest -Parent) | Out-Null
    Move-Item $path $dest
    Write-Host "  backed up -> $dest"
  }
}

# Build the install receipt; written at the end.
$manifestLines = New-Object System.Collections.Generic.List[string]
function Record($path) { $manifestLines.Add("$(To-Rel $path)`t$(Get-Sha $path)") }

Write-Host "Installing claude-dev-agents v$AppVersion -> $Base ($scopeName scope)"
New-Item -ItemType Directory -Force -Path $AgentsDir, $SkillsDir | Out-Null

Write-Host "Agents:"
foreach ($a in $Agents) {
  $dst = Join-Path $AgentsDir "$a.md"
  Backup-IfExists $dst
  Copy-Item (Join-Path $src "agents\$a.md") $dst -Force
  Record $dst
  Write-Host "  installed agent $a"
}
Write-Host "Skills:"
foreach ($s in $Skills) {
  $dst = Join-Path $SkillsDir $s
  Backup-IfExists $dst
  Copy-Item (Join-Path $src "skills\$s") $dst -Recurse -Force
  Get-ChildItem $dst -Recurse -File | ForEach-Object { Record $_.FullName }
  Write-Host "  installed skill $s"
}

# Pin UTF-8 so the manifest is byte-stable; read it back with the same encoding
# (Get-Content -Encoding utf8 strips the BOM, so the first relpath stays intact).
Set-Content -Path $Manifest -Value $manifestLines -NoNewline:$false -Encoding utf8

if ($tmp) { Remove-Item $tmp -Recurse -Force }
Write-Host ""
Write-Host "Done. Restart Claude Code (or start a new session) to pick up the changes."
