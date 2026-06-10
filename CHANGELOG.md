# Changelog

All notable changes to this project are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); versioning is [SemVer](https://semver.org/).

## [Unreleased]

## [1.3.0] — 2026-06-10

### Changed
- `python-reviewer` rewritten to parity with `php-reviewer`: confidence-based filtering,
  pre-report gate, HIGH/CRITICAL proof requirement, Python-specific false-positives list,
  "zero findings is valid", review summary table + verdict, project-conventions section.
  Approval criteria aligned across both reviewers (Block = CRITICAL, Warning = HIGH);
  severity calibration fixed (manual resource management is HIGH, not CRITICAL);
  model raised to opus. ([agents/python-reviewer.md](agents/python-reviewer.md))
- Skills restructured for progressive disclosure: `SKILL.md` is now a thin entry
  (principles digest, quick reference, anti-patterns, routing table) and full pattern
  content moved to `references/*.md` read on demand — agents load only what the task
  needs. No content lost. ([skills/php-patterns/](skills/php-patterns/),
  [skills/python-patterns/](skills/python-patterns/))
- Developer/reviewer agents now load skills via direct `Read` (Glob for
  `**/skills/<name>/SKILL.md`, then needed `references/*.md`) — subagents have no
  `Skill` tool, so the previous "activate the skill" instruction could never fire.
- `backlog-planner` gains `Bash` restricted to read-only git (`git log/show/rev-parse/diff --stat`)
  so `## Resolved` lines carry real commit hashes and dates; writes `commit unknown` when
  git is unavailable. ([agents/backlog-planner.md](agents/backlog-planner.md))
- `data-analyst`: all data-derived strings are HTML-escaped (`html.escape`); report written
  with explicit `encoding="utf-8"` + `<meta charset="utf-8">`; `py -3` launcher fallback
  on Windows. ([agents/data-analyst.md](agents/data-analyst.md))
- `python-developer`: added Django and Flask sections (the description promised them, the
  body covered only FastAPI). ([agents/python-developer.md](agents/python-developer.md))
- `architect` / `backlog-planner`: one-shot subagent semantics — critical ambiguity returns
  questions as the result; otherwise proceed with explicitly listed assumptions.
- `python-patterns` skill description now lists activation triggers (matching `php-patterns`)
  for better auto-activation.

### Fixed
- PHP: `#[AsService]` does not exist in Symfony — replaced with real wiring guidance
  (auto-registration, `#[Autowire]`/`#[AutoconfigureTag]`) in `php-developer` and the skill;
  mislabeled "Spaceship/strict equality" rule renamed; `@dataProvider` docblock updated to
  the PHPUnit 10+ `#[DataProvider]` attribute; `phpstan` baseline bumped to `^2.0`;
  `pdo.persistent` corrected to `PDO::ATTR_PERSISTENT`.
- Python: `x = x or []` mutable-default advice replaced with `if x is None: x = []`
  (the `or` form silently replaces a caller's empty list); EAFP example rewritten
  (undefined `default_value`, and `dict.get` is the real idiom); comprehension section
  no longer contradicts itself; `timer` context manager wraps `yield` in `try/finally`;
  missing `collections.abc` imports added; `datetime.now(UTC)` in dataclass example;
  deprecated `[tool.ruff] select` moved to `[tool.ruff.lint]`; tooling consolidated on
  ruff (black/isort/pylint marked as alternatives).

### Added
- Smoke tests (bash + PowerShell) assert every installed skill ships `references/*.md`.
  ([test/smoke.sh](test/smoke.sh), [test/smoke.ps1](test/smoke.ps1))

## [1.2.0] — 2026-06-10

### Agents
- `data-analyst` — turns a raw dataset (xlsx/csv/tsv/json/parquet) into a single
  self-contained one-page HTML analytics report: dark-theme dashboard with KPI cards,
  inline-SVG bar charts, full metrics table and key findings. Profiles the data, proposes
  slices, always reports absolute values + %; all numbers and chart geometry computed by
  script, verified two ways. Visual system adapted per report; default base palette from
  Brand Analytics brand colors.

### Fixed
- **BL-004** (security): `nohash` manifest entries were deleted during uninstall without any
  edit check, re-opening the silent data-loss path ADR-0001 was written to close. Uninstall
  now treats `nohash` as fail-safe: the file is kept and reported as `nohash, KEPT`,
  mirroring the existing `modified, KEPT` branch. ADR-0001 addendum added.
  ([install.sh](install.sh), [install.ps1](install.ps1),
  [docs/adr/0001-...](docs/adr/0001-name-keyed-install-set-as-uninstall-manifest.md))
- **BL-005** (debt): CI now verifies that all GitHub URL slugs in README.md match the
  authoritative `REPO`/`$Repo` constant in both installers, catching README drift at
  push time. ([test/version-check.sh](test/version-check.sh))

### Added
- **BL-003** (testing): GitHub Actions CI (`ci.yml`) with 5 independent jobs + `ci-pass` aggregator:
  `static-bash` (shellcheck + version-check); `static-pwsh-windows` (PS 5.1 AST parse + `-File` smoke + PSScriptAnalyzer);
  `static-pwsh7` (pwsh 7 parity); `smoke` (matrix ubuntu/macos/windows, PS 5.1 + pwsh 7);
  `parity` (bash vs pwsh7 normalized manifest diff). Test scripts in `test/` — no external test framework.
  Smoke test 10 intentionally fails until BL-004 is fixed (nohash-entry safety gate).
  ([.github/workflows/ci.yml](.github/workflows/ci.yml), [test/](test/))

### Fixed
- **BL-002** (reliability): the version was hardcoded in four places and the `VERSION` file was
  never read. Both installers now read the sibling `VERSION` at runtime (embedded constant kept only
  as the piped-remote fallback), so a release bump touches one file. ([install.sh](install.sh), [install.ps1](install.ps1))
- **BL-006** (reliability): bash uninstall's `while read` loop could silently drop the manifest's
  final record if it lacked a trailing newline. Guarded the loop with `|| [ -n "$rel" ]`. ([install.sh](install.sh))
- **BL-007** (reliability): the PowerShell manifest was written in the shell-default encoding. Pinned
  `-Encoding utf8` on both the write and the read-back (BOM is stripped on read, first relpath intact). ([install.ps1](install.ps1))
- **BL-012** (bug): `install.ps1` failed to parse under Windows PowerShell 5.1 `-File` on non-UTF-8
  system locales (em-dash characters with no BOM) — breaking the documented local / `-Project`
  install. Installer text is now ASCII-only. ([install.ps1](install.ps1))

## [1.1.0] — 2026-06-09

### Agents
- `backlog-planner` — scans the codebase and produces a consistently-structured,
  ICE-prioritized development backlog (pain · impact · effort) at `docs/backlog/BACKLOG.md`.
  Docs-writer only, never edits code. Stable item IDs across runs; resolved items retire to
  a thin `## Resolved` log pointing here.

### Fixed
- **BL-001** (security): installers downloaded `refs/heads/main` — the moving branch tip — via
  `curl|bash` / `irm|iex` with no pinning to the reported version. Now pin the tarball to
  `refs/tags/v$VERSION` so a piped install fetches exactly the released, immutable version.
  ([install.sh:94](install.sh), [install.ps1:84](install.ps1))
- **BL-008** (bug): `*.md` was `text` with no `eol`, so Git normalized agent `.md` line endings
  to the platform native; a manifest hashed on one checkout could mismatch re-hashing on another
  (shared `~/.claude` across WSL + Windows), stranding files as "modified, KEPT" on uninstall.
  Pin `*.md text eol=lf` to match `*.sh` / `*.ps1`. ([.gitattributes](.gitattributes))

## [1.0.0] — 2026-06-08

First tagged release.

### Agents
- `architect` — language-agnostic systems architect; writes designs/ADRs, never code.
- `php-developer`, `php-reviewer` — PHP 8.3+ builder and reviewer.
- `python-developer`, `python-reviewer` — Python 3.11+ builder and reviewer.

### Skills
- `php-patterns`, `python-patterns`.

### Installers
- `install.sh` (bash) and `install.ps1` (PowerShell): local + remote (tarball) modes, user/project scope.
- Auto-discovery — every agent `.md` and skill dir in the repo is installed; no list to maintain.
- Backups to timestamped dir outside `agents/`/`skills/` so Claude Code never loads a `.bak` duplicate.
- Receipt-driven uninstall (see [ADR-0001](docs/adr/0001-name-keyed-install-set-as-uninstall-manifest.md)): removes only files it installed and you haven't modified.
- `VERSION` file and `--version` / `-Version` reporting.
