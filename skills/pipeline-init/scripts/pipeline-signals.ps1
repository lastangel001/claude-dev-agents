#!/usr/bin/env pwsh
# pipeline-signals.ps1 — print the repository signals pipeline-init reads
# (memory files, stack manifests, CI, review process, reversibility, tests,
# tracker prefixes, docs dirs) as plain text.
#
# Usage: pipeline-signals.ps1 [repo-root]
#   repo-root defaults to `git rev-parse --show-toplevel`, then to the cwd.
#
# Output contract: byte-identical to pipeline-signals.sh (after BOM/CR
# normalisation); test/pipeline-signals-parity.sh enforces it. Paths are
# relative to the root, forward slashes, no leading "./"; lists are sorted in
# ordinal (byte) order; every "## section" is always printed.
#
# Portability: Windows PowerShell 5.1 and pwsh 7. No &&/|| chain operators,
# no ternary, no ??. Output is UTF-8 without BOM, LF line endings.
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Root = ''
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

try {
    [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
} catch {
    # Non-console host: keep the default encoding.
}

# ---------------------------------------------------------------------------
# root
# ---------------------------------------------------------------------------
function Get-GitTopLevel {
    param([string]$Dir)
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return $null }
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = & git -C $Dir rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -ne 0) { return $null }
        return ($out | Select-Object -First 1)
    } catch {
        return $null
    } finally {
        $ErrorActionPreference = $prev
    }
}

if ([string]::IsNullOrEmpty($Root)) {
    $top = Get-GitTopLevel -Dir (Get-Location).Path
    if ([string]::IsNullOrEmpty($top)) { $Root = (Get-Location).Path } else { $Root = $top }
}
if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
    [Console]::Error.WriteLine("pipeline-signals: not a directory: $Root")
    exit 1
}
$Root = (Resolve-Path -LiteralPath $Root).Path.TrimEnd('\', '/')
if ($Root -match '^[A-Za-z]:$') { $Root = $Root + '\' }

$Excluded = @('.git', 'node_modules', 'vendor', 'dist', 'build', '.venv', 'venv', '__pycache__', '.next', 'target')

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
$Out = New-Object System.Collections.Generic.List[string]
function Add-Line { param([string]$Line) $Out.Add($Line) }

function Sort-Ordinal {
    param([string[]]$Items)
    $arr = @($Items | Where-Object { $null -ne $_ -and $_ -ne '' })
    if ($arr.Count -gt 1) { [Array]::Sort($arr, [System.StringComparer]::Ordinal) }
    return , $arr
}

function Test-RootFile { param([string]$Rel) return (Test-Path -LiteralPath (Join-Path $Root $Rel) -PathType Leaf) }
function Test-RootDir  { param([string]$Rel) return (Test-Path -LiteralPath (Join-Path $Root $Rel) -PathType Container) }

function Write-PresentLine {
    param([string]$Key, [string[]]$Files)
    foreach ($f in $Files) {
        if (Test-RootFile $f) { Add-Line "${Key}: present"; return }
    }
    Add-Line "${Key}: absent"
}

function Write-ListLines {
    param([string]$Key, [string[]]$Values)
    $any = $false
    foreach ($v in $Values) {
        if ([string]::IsNullOrEmpty($v)) { continue }
        Add-Line "${Key}: $v"; $any = $true
    }
    if (-not $any) { Add-Line "${Key}: none" }
}

function Write-RootFileLines {
    param([string]$Key, [string[]]$Names)
    $found = @()
    foreach ($n in $Names) { if (Test-RootFile $n) { $found += $n } }
    Write-ListLines $Key (Sort-Ordinal $found)
}

# Walk the tree once (excluded dirs pruned, reparse points skipped like find
# without -L). Fills $AllDirs / $AllFiles with @{ Rel; Name; Depth }.
$AllDirs  = New-Object System.Collections.Generic.List[object]
$AllFiles = New-Object System.Collections.Generic.List[object]

function Invoke-TreeWalk {
    param([string]$Dir, [string]$RelPrefix, [int]$Depth)
    $subdirs = @()
    try { $subdirs = [System.IO.Directory]::GetDirectories($Dir) } catch { $subdirs = @() }
    foreach ($d in $subdirs) {
        $name = [System.IO.Path]::GetFileName($d)
        if ($Excluded -ccontains $name) { continue }
        $attr = [System.IO.File]::GetAttributes($d)
        if (($attr -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) { continue }
        $rel = if ($RelPrefix -eq '') { $name } else { "$RelPrefix/$name" }
        $AllDirs.Add(@{ Rel = $rel; Name = $name; Depth = $Depth })
        Invoke-TreeWalk -Dir $d -RelPrefix $rel -Depth ($Depth + 1)
    }
    $files = @()
    try { $files = [System.IO.Directory]::GetFiles($Dir) } catch { $files = @() }
    foreach ($f in $files) {
        $name = [System.IO.Path]::GetFileName($f)
        $attr = [System.IO.File]::GetAttributes($f)
        if (($attr -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) { continue }
        $rel = if ($RelPrefix -eq '') { $name } else { "$RelPrefix/$name" }
        $AllFiles.Add(@{ Rel = $rel; Name = $name; Depth = $Depth; Full = $f })
    }
}
Invoke-TreeWalk -Dir $Root -RelPrefix '' -Depth 1

function Get-MatchingDirs {
    param([int]$MaxDepth, [string[]]$Names)
    $r = @()
    foreach ($d in $AllDirs) {
        if ($d.Depth -le $MaxDepth -and ($Names -ccontains $d.Name)) { $r += $d.Rel }
    }
    return , $r
}

function Get-MatchingFiles {
    param([int]$MaxDepth, [string]$NameRegex)
    $r = @()
    foreach ($f in $AllFiles) {
        if (($MaxDepth -lt 0 -or $f.Depth -le $MaxDepth) -and [regex]::IsMatch($f.Name, $NameRegex)) { $r += $f.Rel }
    }
    return , $r
}

# ---------------------------------------------------------------------------
Add-Line '# pipeline-signals'
Add-Line "repo: $(Split-Path -Leaf $Root)"

# ---------------------------------------------------------------------------
Add-Line '## memory'
Write-PresentLine 'claude-md' @('CLAUDE.md')
Write-PresentLine 'claude-docs-architecture' @('.claude-docs/architecture.md')
Write-PresentLine 'pipeline-md' @('docs/PIPELINE.md')

# ---------------------------------------------------------------------------
Add-Line '## stack'
Write-RootFileLines 'manifest' @('package.json', 'composer.json', 'pyproject.toml', 'requirements.txt', 'go.mod',
    'Cargo.toml', 'pom.xml', 'build.gradle', 'build.gradle.kts', 'Gemfile', 'mix.exs')
Write-RootFileLines 'lockfile' @('package-lock.json', 'pnpm-lock.yaml', 'yarn.lock', 'bun.lockb', 'composer.lock',
    'poetry.lock', 'uv.lock', 'Pipfile.lock', 'Cargo.lock', 'go.sum', 'Gemfile.lock')

# ---------------------------------------------------------------------------
Add-Line '## ci'
$ghWorkflows = @()
$wfDir = Join-Path $Root '.github/workflows'
if (Test-Path -LiteralPath $wfDir -PathType Container) {
    $wfFiles = @()
    try { $wfFiles = [System.IO.Directory]::GetFiles($wfDir) } catch { $wfFiles = @() }
    foreach ($f in $wfFiles) {
        $name = [System.IO.Path]::GetFileName($f)
        if ($name -cmatch '\.(yml|yaml)$') { $ghWorkflows += ".github/workflows/$name" }
    }
    $ghWorkflows = Sort-Ordinal $ghWorkflows
}
$ciFiles = @() + $ghWorkflows
foreach ($f in @('.gitlab-ci.yml', 'Jenkinsfile', '.circleci/config.yml', 'azure-pipelines.yml', 'bitbucket-pipelines.yml')) {
    if (Test-RootFile $f) { $ciFiles += $f }
}
Write-ListLines 'ci-file' (Sort-Ordinal $ciFiles)

# ci-job: top-level keys under "jobs:" in each GitHub workflow, in file order
$ciJobs = @()
foreach ($wf in $ghWorkflows) {
    $lines = [System.IO.File]::ReadAllLines((Join-Path $Root $wf))
    $inJobs = $false
    foreach ($line in $lines) {
        $line = $line -replace '\r$', ''
        if ($line -cmatch '^jobs:') { $inJobs = $true; continue }
        if ($inJobs -and $line -cmatch '^[^ \t#]') { $inJobs = $false }
        if ($inJobs -and $line -cmatch '^  ([A-Za-z_][A-Za-z0-9_-]*):') { $ciJobs += "${wf}:$($Matches[1])" }
    }
}
Write-ListLines 'ci-job' $ciJobs

# ---------------------------------------------------------------------------
Add-Line '## review-process'
Write-PresentLine 'codeowners' @('CODEOWNERS', '.github/CODEOWNERS', 'docs/CODEOWNERS')
$prTemplate = $false
foreach ($f in @('.github/PULL_REQUEST_TEMPLATE.md', '.github/pull_request_template.md', 'PULL_REQUEST_TEMPLATE.md')) {
    if (Test-RootFile $f) { $prTemplate = $true }
}
if (-not $prTemplate) {
    $mrDir = Join-Path $Root '.gitlab/merge_request_templates'
    if (Test-Path -LiteralPath $mrDir -PathType Container) {
        $mrFiles = @()
        try { $mrFiles = [System.IO.Directory]::GetFiles($mrDir, '*', [System.IO.SearchOption]::AllDirectories) } catch { $mrFiles = @() }
        if ($mrFiles.Count -gt 0) { $prTemplate = $true }
    }
}
if ($prTemplate) { Add-Line 'pr-template: present' } else { Add-Line 'pr-template: absent' }

# ---------------------------------------------------------------------------
Add-Line '## reversibility'
$migrations = @() + (Get-MatchingDirs 4 @('migrations', 'migrate', 'alembic'))
foreach ($d in @('db/migrate', 'database/migrations')) { if (Test-RootDir $d) { $migrations += $d } }
Write-ListLines 'migrations-dir' (Sort-Ordinal ($migrations | Select-Object -Unique))

Write-ListLines 'api-schema' (Sort-Ordinal (Get-MatchingFiles 4 '^(openapi.*\.(yml|yaml|json)|swagger.*\.(yml|yaml|json)|.*\.proto|.*\.graphql)$'))

$clientRe = [regex]'requests\.|httpx|aiohttp|guzzle|axios|fetch\(|grpc|amqp|kafka|celery|bullmq|sqs|pubsub|Queue::'
$latin1 = [System.Text.Encoding]::GetEncoding(28591)
$clientN = 0
foreach ($f in $AllFiles) {
    if ($f.Name -cnotmatch '\.(py|php|js|ts|go|rb|java|cs|kt)$') { continue }
    $text = $null
    try { $text = $latin1.GetString([System.IO.File]::ReadAllBytes($f.Full)) } catch { $text = $null }
    if ($null -ne $text -and $clientRe.IsMatch($text)) { $clientN++ }
}
Add-Line "external-client-files: $clientN"

# ---------------------------------------------------------------------------
Add-Line '## tests'
Write-ListLines 'test-dir' (Sort-Ordinal (Get-MatchingDirs 2 @('tests', 'test', '__tests__', 'spec', 'e2e', 'cypress', 'playwright')))
Write-RootFileLines 'test-config' @('pytest.ini', 'setup.cfg', 'tox.ini', 'phpunit.xml', 'phpunit.xml.dist',
    'jest.config.js', 'jest.config.ts', 'jest.config.mjs', 'vitest.config.ts', 'vitest.config.js', 'vitest.config.mts',
    'playwright.config.ts', 'playwright.config.js', 'cypress.config.ts', 'cypress.config.js',
    '.mocharc.yml', '.mocharc.json')

# ---------------------------------------------------------------------------
Add-Line '## tracker'
$trackerLines = @()
$gitTop = Get-GitTopLevel -Dir $Root
if (-not [string]::IsNullOrEmpty($gitTop)) {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $subjects = @()
    try { $subjects = @(& git -C $Root log -200 --format=%s 2>$null) } catch { $subjects = @() }
    $ErrorActionPreference = $prev
    $counts = @{}
    $keyRe = [regex]'[A-Z][A-Z0-9]{1,9}-[0-9]+'
    foreach ($s in $subjects) {
        if ($null -eq $s) { continue }
        foreach ($m in $keyRe.Matches([string]$s)) {
            $prefix = $m.Value.Substring(0, $m.Value.IndexOf('-'))
            if ($counts.ContainsKey($prefix)) { $counts[$prefix] = $counts[$prefix] + 1 } else { $counts[$prefix] = 1 }
        }
    }
    $distinct = @($counts.Values | Select-Object -Unique | Sort-Object -Descending)
    foreach ($c in $distinct) {
        $names = @($counts.Keys | Where-Object { $counts[$_] -eq $c })
        foreach ($n in (Sort-Ordinal $names)) {
            if ($trackerLines.Count -lt 3) { $trackerLines += "$n $c" }
        }
    }
}
Write-ListLines 'tracker-prefix' $trackerLines

# ---------------------------------------------------------------------------
Add-Line '## docs'
$docsDirs = @()
foreach ($d in @('docs/adr', 'docs/qa', 'docs/backlog', 'docs/architecture', 'docs/decisions')) {
    if (Test-RootDir $d) { $docsDirs += $d }
}
Write-ListLines 'docs-dir' (Sort-Ordinal $docsDirs)

# ---------------------------------------------------------------------------
# write: LF only, exactly one trailing newline, no BOM
$text = ($Out -join "`n") + "`n"
$stdout = [Console]::OpenStandardOutput()
$bytes = (New-Object System.Text.UTF8Encoding($false)).GetBytes($text)
$stdout.Write($bytes, 0, $bytes.Length)
$stdout.Flush()
