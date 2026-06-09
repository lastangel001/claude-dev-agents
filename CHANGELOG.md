# Changelog

All notable changes to this project are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); versioning is [SemVer](https://semver.org/).

## [Unreleased]

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
