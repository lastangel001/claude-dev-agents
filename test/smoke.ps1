# smoke.ps1 -- PowerShell mirror of smoke.sh
# Run under PS 5.1: powershell -NoProfile -File test\smoke.ps1
# Run under pwsh 7: pwsh -NoProfile -File test/smoke.ps1
# Installs into a throwaway temp dir (-Project scope); never touches real ~/.claude.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'

$RepoRoot = (Get-Item (Join-Path $PSScriptRoot '..')).FullName

# Resolve current PowerShell executable so tests invoke the installer with the
# same runtime that is running this script (works for PS 5.1 and pwsh 7).
$PsExe = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
function Pass([string]$msg) { Write-Host "  PASS  $msg" }
function Fail([string]$msg) { Write-Host "  FAIL  $msg" -ForegroundColor Red; exit 1 }
function Assert-Eq([string]$label, [string]$expected, [string]$actual) {
  if ($expected -eq $actual) {
    Pass $label
  } else {
    Write-Host "  FAIL  $label" -ForegroundColor Red
    Write-Host "        expected: $expected"
    Write-Host "        actual:   $actual"
    exit 1
  }
}

function Get-Sha([string]$path) { (Get-FileHash -Path $path -Algorithm SHA256).Hash.ToLower() }

function Invoke-Installer {
  param([string[]]$Arguments)
  # PS 5.1 wraps stderr from native executables as NativeCommandError when
  # $ErrorActionPreference = 'Stop'. Use local Continue to avoid a thrown
  # exception; callers check $LASTEXITCODE for the actual exit status.
  $local:ErrorActionPreference = 'Continue'
  & $PsExe -NoProfile -File $script:Installer @Arguments 2>&1
}

Write-Host "=== smoke.ps1 ($(Split-Path $PsExe -Leaf)) ==="

# ---------------------------------------------------------------------------
# setup: copy repo into tmp src dir; each test gets its own scope dir
# ---------------------------------------------------------------------------
$TmpBase = [System.IO.Path]::GetTempPath()
$TmpSrc = Join-Path $TmpBase ("cda_src_" + [System.IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Force -Path $TmpSrc | Out-Null

try {
  Copy-Item (Join-Path $RepoRoot 'agents')      $TmpSrc -Recurse -Force
  Copy-Item (Join-Path $RepoRoot 'skills')      $TmpSrc -Recurse -Force
  Copy-Item (Join-Path $RepoRoot 'VERSION')     $TmpSrc -Force
  Copy-Item (Join-Path $RepoRoot 'install.ps1') $TmpSrc -Force

  $script:Installer = Join-Path $TmpSrc 'install.ps1'
  $Version = (Get-Content (Join-Path $RepoRoot 'VERSION') -Raw).Trim()

  # -----------------------------------------------------------------------
  # 1. -Version
  # -----------------------------------------------------------------------
  $VersionOut = (Invoke-Installer '-Version') -join '' | ForEach-Object { $_.Trim() }
  # Normalize: $VersionOut may be a list; join and trim
  if ($VersionOut -is [array]) { $VersionOut = ($VersionOut | Where-Object { $_ }) -join '' }
  $VersionOut = "$VersionOut".Trim()
  Assert-Eq "1. -Version output" "claude-dev-agents $Version" $VersionOut

  # -----------------------------------------------------------------------
  # 2-8. fresh install scope
  # -----------------------------------------------------------------------
  $ScopeA = Join-Path $TmpBase ("cda_a_" + [System.IO.Path]::GetRandomFileName())
  New-Item -ItemType Directory -Force -Path $ScopeA | Out-Null
  $Manifest = Join-Path $ScopeA '.claude\.cda-manifest'

  Push-Location $ScopeA
  Invoke-Installer '-Project' | Out-Null
  if ($LASTEXITCODE -ne 0) { Pop-Location; Fail "2. install exited $LASTEXITCODE" }
  Pop-Location
  Pass "2. install exit 0"

  # 3. manifest exists and non-empty
  if (-not (Test-Path $Manifest)) { Fail "3. manifest absent" }
  if ((Get-Item $Manifest).Length -eq 0) { Fail "3. manifest empty" }
  Pass "3. manifest exists and non-empty"

  # 4. manifest format: every line matches <relpath>TAB(<64hex>|nohash)
  $hashPattern = '^([0-9a-f]{64}|nohash)$'
  foreach ($line in Get-Content $Manifest -Encoding utf8) {
    if (-not $line.Trim()) { continue }
    $parts = $line -split "`t", 2
    $hash = if ($parts.Count -gt 1) { $parts[1] } else { '' }
    if ($hash -notmatch $hashPattern) {
      Fail "4. manifest bad hash '$hash' for '$($parts[0])'"
    }
  }
  Pass "4. manifest format valid"

  # 5. BL-006 line count + BL-007 no-BOM guard
  $ManifestLines = @(Get-Content $Manifest -Encoding utf8 | Where-Object { $_.Trim() })
  $ManifestCount = $ManifestLines.Count

  $AgentsDir = Join-Path $ScopeA '.claude\agents'
  $SkillsDir = Join-Path $ScopeA '.claude\skills'
  $InstalledFiles = @(
    Get-ChildItem $AgentsDir -Recurse -File -ErrorAction SilentlyContinue
    Get-ChildItem $SkillsDir -Recurse -File -ErrorAction SilentlyContinue
  )
  $InstalledCount = $InstalledFiles.Count
  Assert-Eq "5. BL-006 line count == file count" "$InstalledCount" "$ManifestCount"

  # BL-007: Get-Content -Encoding utf8 strips BOM; verify first relpath has no leading BOM char
  $FirstLine = $ManifestLines[0]
  if ($FirstLine.Length -gt 0 -and [int][char]$FirstLine[0] -eq 0xFEFF) {
    Fail "5. BL-007: manifest first line starts with BOM (encoding not pinned)"
  }
  Pass "5. BL-006+BL-007: line count correct; no BOM on first relpath"

  # 6. sampled hash: agents/architect.md
  # Use flexible pattern for the manifest lookup: path separator may be '/' (Linux/pwsh7)
  # or '\' (Windows/PS5.1 -- To-Rel strips the base which uses backslashes on Windows).
  $ArchFile = Join-Path $ScopeA '.claude\agents\architect.md'
  if (-not (Test-Path $ArchFile)) { Fail "6. agents/architect.md not installed" }
  $ActualHash   = Get-Sha $ArchFile
  $ManifestHash = ($ManifestLines | Where-Object { $_ -match 'architect\.md\t' }) -replace '^[^\t]+\t', ''
  Assert-Eq "6. architect.md hash" $ActualHash $ManifestHash

  # 7. security -- refuse uninstall without manifest
  $ScopeB = Join-Path $TmpBase ("cda_b_" + [System.IO.Path]::GetRandomFileName())
  New-Item -ItemType Directory -Force -Path $ScopeB | Out-Null
  Push-Location $ScopeB
  Invoke-Installer '-Project', '-Uninstall' | Out-Null
  $RefuseExit = $LASTEXITCODE
  Pop-Location
  if ($RefuseExit -eq 0) { Fail "7. uninstall without manifest should exit nonzero (got 0)" }
  Pass "7. security: refuse uninstall without manifest (exit $RefuseExit)"

  # 8. uninstall: files gone, manifest removed
  Push-Location $ScopeA
  Invoke-Installer '-Project', '-Uninstall' | Out-Null
  if ($LASTEXITCODE -ne 0) { Pop-Location; Fail "8. uninstall exited $LASTEXITCODE" }
  Pop-Location
  if (Test-Path $Manifest) { Fail "8. manifest not removed after uninstall" }
  $Leftover = @(
    Get-ChildItem (Join-Path $ScopeA '.claude\agents') -Recurse -File -ErrorAction SilentlyContinue
    Get-ChildItem (Join-Path $ScopeA '.claude\skills') -Recurse -File -ErrorAction SilentlyContinue
  )
  if ($Leftover.Count -gt 0) { Fail "8. $($Leftover.Count) files left after uninstall" }
  Pass "8. uninstall: files removed, manifest gone"

  # -----------------------------------------------------------------------
  # 9. security -- modified file KEPT
  # -----------------------------------------------------------------------
  $ScopeC = Join-Path $TmpBase ("cda_c_" + [System.IO.Path]::GetRandomFileName())
  New-Item -ItemType Directory -Force -Path $ScopeC | Out-Null
  Push-Location $ScopeC
  Invoke-Installer '-Project' | Out-Null
  Pop-Location
  Add-Content (Join-Path $ScopeC '.claude\agents\architect.md') "`n# user edit"
  Push-Location $ScopeC
  $KeptOut = Invoke-Installer '-Project', '-Uninstall'
  Pop-Location
  $ArchC = Join-Path $ScopeC '.claude\agents\architect.md'
  if (-not (Test-Path $ArchC)) { Fail "9. modified file deleted (should be KEPT)" }
  if ("$KeptOut" -notmatch "modified, KEPT") { Fail "9. output missing 'modified, KEPT'" }
  Pass "9. modified file KEPT; output contains 'modified, KEPT'"

  # -----------------------------------------------------------------------
  # 10. security -- nohash entry: file must NOT be deleted (BL-004 fix)
  # -----------------------------------------------------------------------
  $ScopeD = Join-Path $TmpBase ("cda_d_" + [System.IO.Path]::GetRandomFileName())
  New-Item -ItemType Directory -Force -Path $ScopeD | Out-Null
  Push-Location $ScopeD
  Invoke-Installer '-Project' | Out-Null
  Pop-Location
  $NohashManifest = Join-Path $ScopeD '.claude\.cda-manifest'
  # Patch manifest: replace architect.md hash with nohash
  $Lines = Get-Content $NohashManifest -Encoding utf8
  $Lines = $Lines | ForEach-Object {
    # Match either '/' (Linux/pwsh7) or '\' (Windows/PS5.1) path separator
    if ($_ -match 'architect\.md\t') { ($_ -replace '\t.*', '') + "`t" + 'nohash' }
    else { $_ }
  }
  Set-Content $NohashManifest -Value $Lines -Encoding utf8 -NoNewline:$false
  $Patched = Get-Content $NohashManifest -Encoding utf8 | Where-Object { $_ -match 'architect\.md\tnohash' }
  if (-not $Patched) { Fail "10. nohash patch failed" }
  Push-Location $ScopeD
  $NohashOut = Invoke-Installer '-Project', '-Uninstall'
  Pop-Location
  $ArchD = Join-Path $ScopeD '.claude\agents\architect.md'
  if (-not (Test-Path $ArchD)) {
    Fail "10. nohash entry was deleted -- must be KEPT (same safety as 'modified, KEPT')"
  }
  if ("$NohashOut" -notmatch "nohash, KEPT") { Fail "10. output missing 'nohash, KEPT'" }
  Pass "10. nohash: file KEPT, output contains 'nohash, KEPT'"

} finally {
  Remove-Item $TmpSrc -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "=== smoke.ps1: all assertions passed ==="
