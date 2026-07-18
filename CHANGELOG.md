# Changelog

All notable changes to this project are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); versioning is [SemVer](https://semver.org/).

## [Unreleased]

## [1.7.0] — 2026-07-18

### Changed
- **`devops-engineer` now runs on `opus`** (was `sonnet`). Its responsibility zone —
  CI/CD pipelines, IaC, and deployment automation — is high-blast-radius and, unlike the
  `python`/`php-developer` builders, its output passes through no reviewer agent. Aligning it
  with the repo's other critical-zone agents (architect, reviewers, backlog-planner,
  data-analyst) raises quality where mistakes are most costly.
  ([agents/devops-engineer.md](agents/devops-engineer.md))

## [1.6.0] — 2026-07-16

### Added
- **`--agent NAME` install/uninstall flag** (`--agent` on `install.sh`, repeatable;
  `-Agent` on `install.ps1`, array) — install or remove a single agent (or a few) instead
  of the whole set, atomically: an unknown name aborts before anything is copied, and the
  manifest is merged rather than overwritten so a selective run never orphans the tracking
  of agents/skills placed by an earlier full install. Skills are left untouched by a
  selective agent install. Uninstall with `--agent`/`-Agent` removes only the named
  agent's manifest entry and file, leaving the rest of the install intact.
  ([install.sh](install.sh), [install.ps1](install.ps1))

## [1.5.0] — 2026-07-06

### Added
- **`devops-engineer` agent** — DevOps builder for delivery infrastructure: CI/CD pipelines
  (GitHub Actions, GitLab CI, Jenkins), container images (multi-stage, non-root, layer-cache
  ordering), Kubernetes/Helm (probes, resources, securityContext, PDB), IaC (Terraform remote
  state + plan-on-PR/apply-on-merge, Ansible idempotency), deployment strategies
  (rolling/blue-green/canary, expand–contract migrations, automated rollback), observability
  (symptoms-not-causes alerting, SLOs) and build/pipeline performance (lockfile-keyed caches,
  affected-only monorepo builds). Hard rules: no secrets in code/logs, pin everything,
  least privilege, idempotent re-runnable steps, every deploy has a rollback path, no
  snowflake state, blocking quality gates. Self-checks with available validators
  (actionlint, hadolint, helm lint, kubeconform, terraform validate, shellcheck) and
  reports what could not be verified. Synthesized from three community subagent drafts
  (build-engineer, devops-engineer, devops-maestro) into the repo's agent style.
  ([agents/devops-engineer.md](agents/devops-engineer.md))

## [1.4.0] — 2026-06-15

### Added
- **`facilitator` agent** — a facilitation expert that prepares and designs sessions,
  workshops and brainstorms. It classifies the meeting by complexity level
  (base meeting / strategic session / global dialogue), sets the rational and existential
  goals and the target pyramid level (Global Dialog: shared field → alternatives → decision →
  roadmap), drafts the **main question** (`основная часть + «чтобы что…»`), a timed scenario
  grid (`Этап | Время | Содержание/Вопросы | Механика | Визуализация`), a stage-by-stage
  question bank (Strachan's 6 principles), run-time lifehacks and in-the-moment interventions,
  a risk forecast (Голова/Руки/Сердце), and an after-phase plan. Outputs one Markdown meeting
  plan in the request's language. Docs-only — never edits source code.
  ([agents/facilitator.md](agents/facilitator.md))
- **`facilitation-patterns` skill** — thin `SKILL.md` entry + routing table over
  `references/`: `facilitation-101.md` (process-vs-content, IAF competencies, three
  complexity levels & role aspects, goals pyramid, client roles A/B/C, Path to Action),
  `questions.md` (Strachan principles, main-question constructor, question bank),
  `methods.md` (method catalog with when-to-use: brainstorm, metaphor, SWOT/SOAR, problem
  tree, Ishikawa, moderation, voting, 6-3-5 brainwriting, 1-2-4-All, World Café, Liberating
  Structures + Troika), `preparation.md` (5 prep steps, difficulty forecast, the after-phase),
  `extended.md` (ORID, retro formats, online facilitation, international ↔ local synthesis).
- `.gitignore`: `examples/` — private learning materials (the agent carries the expertise
  inline; source PDFs/xlsx stay local, not distributed).

## [1.3.1] — 2026-06-10

### Added
- `CLAUDE.md` — repo entry point for Claude Code agents: commands, release discipline
  (every change ships as a release: md docs + badge + VERSION/fallbacks + tag + GitHub release),
  boundaries (LF/exec bits, installer parity, workflow `shell:` gotcha).

### Fixed
- **CI never ran**: every workflow run since BL-003 failed at startup (0s, no jobs) because
  GitHub rejects a workflow file whose step-level `shell:` contains an expression
  (`shell: ${{ matrix.shell }}` in the smoke matrix). Replaced with a literal `shell: bash`
  (the matrix commands invoke `powershell`/`pwsh` as executables) and a `label` matrix key
  for job names. First green run: all 9 jobs. ([.github/workflows/ci.yml](.github/workflows/ci.yml))
- Real failures the first live CI run then exposed:
  `install.sh` and `test/*.sh` had no executable bit (repo authored on Windows; smoke failed
  with exit 126 on Linux/macOS — and `./install.sh` from the README would too);
  GNU-only `sed -i` in smoke test 10 broke BSD sed on macOS (rewritten via temp file);
  shellcheck findings SC2015/SC2016/SC2295 in `install.sh`, `test/version-check.sh`,
  `test/parity.sh`; PSScriptAnalyzer `PSUseSingularNouns` on the private `Backup-IfExists`
  helper (excluded in settings).

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
