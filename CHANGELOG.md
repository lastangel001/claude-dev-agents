# Changelog

All notable changes to this project are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); versioning is [SemVer](https://semver.org/).

## [Unreleased]

## [1.14.1] — 2026-08-25

### Fixed
- **`lint-ru.sh` runs awk under `LC_ALL=C`** — in a UTF-8 locale (ubuntu CI) gawk rejects
  the raw byte-prefix variables (emoji detection) as "Invalid multibyte data" and the
  emoji check silently never fires; local Git Bash ran byte-mode and hid it. Byte mode
  makes every fixed-string match locale-independent. Caught by the v1.14.0 fixture suite
  on its very first CI run.

## [1.14.0] — 2026-08-25

### Added
- **`ru-output-style` eval suite**, two tiers:
  - **Deterministic linter regression** ([test/lint-ru-test.sh](test/lint-ru-test.sh) +
    9 fixtures in [test/fixtures/lint-ru/](test/fixtures/lint-ru/)) — every hard-ban
    family, warn lexicon, rhythm/anaphora metrics, `--strict`, skip zones (frontmatter,
    fenced/inline code, tables) and HTML mode each pinned by a fixture with an `.expect`
    file (`EXIT` / `STRICT_EXIT` / `HAS <substring>` directives, presence-based so new
    linter checks don't break old fixtures). Wired into CI (static-bash job); the new
    scripts are also under `bash -n`, shellcheck and the CRLF guard (now recursive over
    `test/`, `skills/`, `eval/`).
  - **Model eval** ([eval/ru-output-style/run-model-eval.sh](eval/ru-output-style/run-model-eval.sh) +
    5 slop-bait prompts) — feeds Russian bait tasks (findings, business summary, incident,
    meeting plan, chat reply) to `claude -p` with the full skill piped via stdin (a ~30 KB
    system-prompt argument dies on Windows with "Argument list too long"), lints every
    answer, reports pass rate; `--baseline` also runs each prompt without the skill for
    the delta, `--strict` fails on warnings too, `--model` passes through. Guards against
    empty/short answers so a failed CLI call reads FAIL, not false PASS. Costs tokens —
    manual only, never CI. Answers land in `eval/out/` (gitignored).
- **`lint-ru.sh`**: «по сути» / «в конечном счёте» now also caught capitalized
  (sentence-initial position — found by the fixture suite).

## [1.13.0] — 2026-08-25

### Added
- **`ru-output-style`: 5 new catalog patterns (37 → 42)** in
  [references/patterns.md](skills/ru-output-style/references/patterns.md):
  канцелярские указатели и обёртки («данный», «в рамках», «на предмет»), анафора (3+
  предложений подряд с одного слова), булет-листы вместо связной прозы, защита от
  невыдвинутых возражений («хотя кто-то может возразить»), дисклеймеры о границах знаний
  («на момент написания», «насколько известно»). Plus a standing maintenance rule: slop
  spotted in real output goes into the catalog immediately as a before/after case, and
  into the linter when it is deterministically catchable.
- **`lint-ru.sh`: new checks** — WARN groups for unprompted-objection defenses and
  knowledge-limit disclaimers, and an anaphora rhythm metric (3+ consecutive sentences
  opening with the same word).

### Changed
- **Russian-prose guard blocks deduplicated** in `data-analyst`, `facilitator`,
  `analyst-writer` — v1.12.0 showed the cost of three hand-maintained copies (one skill
  change = three agent edits, wording already drifting). Each block now leads with "the
  `ru-output-style` skill is the single source of truth, following it is mandatory" and
  keeps only the top hard bans + the two-question final check as the not-installed
  fallback. Future catalog/linter changes no longer require touching the agents.

## [1.12.0] — 2026-08-25

### Added
- **`ru-output-style`: deterministic linter** ([skills/ru-output-style/scripts/lint-ru.sh](skills/ru-output-style/scripts/lint-ru.sh)) —
  regex/awk pass over saved Russian prose: exit 1 on any hard ban (negative parallelisms
  incl. «как X, так и Y», em/en dash + HTML entities, arrows/`vs` in prose, «подводя итог»
  closings, colon reveals, chatbot artifacts, emoji/dingbats, `---` separators), warnings
  on AI-lexicon («является», «ключевой», «данный», pseudo-depth…), a rule-of-three
  heuristic, and rhythm metrics (no short sentence ≤8 words, ≥4 same-length sentences in a
  row). Skips YAML frontmatter, fenced code, inline code, Markdown tables; `--html` mode
  (auto for `*.html`) also skips tags, `<script>`/`<style>` and `<table>` content.
  `--strict` makes warnings fail. POSIX awk + bash, no GNU-only flags.
- **`ru-output-style`: gold examples** ([skills/ru-output-style/references/gold.md](skills/ru-output-style/references/gold.md)) —
  positive corpus: one exemplary paragraph per genre (data finding, review verdict,
  business research summary, meeting-plan fragment, final chat reply) with a short "why it
  works" note each; models imitate examples better than they obey ban lists. The file
  passes its own linter.
- **`ru-output-style`: mandatory final check** (adapted from
  [blader/humanizer](https://github.com/blader/humanizer)'s verification phase) — two
  questions before delivering: "what still reads as AI-generated" and "did the style pass
  add or lose any fact, number, name, date, quote, or claim"; plus a
  **preserve-human-details list** (odd concrete details, mixed judgments, dated slang,
  uneven rhythm, self-corrections, deliberate first person) that a style pass must not
  sterilize.

### Changed
- **`data-analyst`, `facilitator`, `analyst-writer`** — their Russian-prose guard now also
  mandates the two-question final check and running `lint-ru.sh` on the saved deliverable
  (fix every BAN before delivering; warnings are a judgment call), and routes to
  `references/gold.md` for the genre's gold example.

## [1.11.0] — 2026-08-14

### Added
- **`analyst-writer` agent** — business + systems analyst with a technical writer's craft.
  Three modes: **Explain** (research results, task breakdowns, incident post-mortems as
  business-readable narratives — business layer first with impact in business units,
  technical appendix after, trigger/root-cause/contributing factors separated), **Analyze**
  (requirements analysis: facts vs assumptions vs open questions labeled explicitly,
  completeness checklist, contradictions named, prioritized clarifying questions grouped by
  addressee and ordered by blocking power), **Draft-task** (learns the project's tracker
  rules first, drafts title/context/scope/acceptance criteria, creates issues **only after
  the user approves the shown text**, never modifies existing issues). Deliverables:
  Markdown or self-contained interactive HTML — inline CSS/vanilla JS, MathML/inline-SVG
  formulas (no CDN renderers), tabs/collapsibles/what-if controls that degrade gracefully.
  Guards its Russian prose the same hybrid way as `data-analyst`/`facilitator`: inline
  hard-ban block + mandatory `ru-output-style` skill read. Intentionally declares no
  `tools:` list — inherits all session tools, including tracker MCPs (Jira/GitLab) when
  present. Model: opus (prose quality is the product).
  ([agents/analyst-writer.md](agents/analyst-writer.md))

## [1.10.1] — 2026-08-12

### Fixed
- **Frontmatter of `contract-reviewer`, `js-reviewer`, `review-verifier` is now valid strict YAML** —
  their `description:` values contain `: ` (colon + space), which a strict YAML parser rejects
  inside an unquoted scalar (`mapping values are not allowed in this context`). GitHub's Markdown
  renderer therefore showed an "Error in user YAML" banner on these three agent pages. Values are
  now double-quoted. Claude Code parsed them fine either way — rendering-only fix, agent behavior
  unchanged.

## [1.10.0] — 2026-08-07

### Added
- **`ru-output-style` skill** — style guard for Russian prose written for humans: findings,
  verdicts, summaries, meeting-plan narratives, final chat replies. Thin `SKILL.md` (hard-ban
  list, forbidden synonym swaps, quick rules for findings) + `references/patterns.md` — a
  distilled catalog of 37 AI-slop patterns by family (канцелярит, AI-словарь, structural hard
  bans, communication register, grammatical calques, rhythm) with markers, cures and до/после
  examples. Cluster rule: one marker means nothing, three from different families reads as
  machine output; hard bans (negative parallelisms «не просто X, а Y», long dash «—», math
  signs in prose, chopped drama, «подводя итог» closings) fail even alone. Explicit
  non-targets: numbers/terms, quotes, questions addressed to people, tables/axis labels/code,
  legal/academic register. Distilled from [smixs/humanizer-ru](https://github.com/smixs/humanizer-ru)
  (MIT) — install that skill separately for *editing* existing text (3-phase pipeline,
  deterministic linter, detect mode); this is the write-time prevention subset.
  ([skills/ru-output-style/](skills/ru-output-style/))

### Changed
- **`data-analyst` and `facilitator` guard their Russian prose** — hybrid wiring, same
  architecture as the language agents and `php`/`python-patterns`: an inline ~10-line
  hard-ban block in each agent (guaranteed — lives in the agent's system prompt, applies
  even when the skill is not installed) plus a mandatory step to read the `ru-output-style`
  skill (Glob + Read — subagents have no Skill tool) for the full catalog before writing
  Russian prose. `data-analyst`: verdict, key findings, caveats, final chat reply; a finding
  is a number, not an assessment («41% ошибок (127 из 310) приходит из канала X», not
  «канал X демонстрирует ключевую роль»). `facilitator`: plan narrative, lifehacks, risks,
  after-phase, chat reply — with an explicit exemption for the question bank (questions
  addressed to the group are the deliverable, not rhetoric).
  ([agents/data-analyst.md](agents/data-analyst.md), [agents/facilitator.md](agents/facilitator.md))

## [1.9.0] — 2026-08-07

### Added
- **`contract-reviewer` agent** — language-agnostic reviewer for the one defect class the language
  reviewers structurally cannot see: the agreement between a call and the code on the other side of
  a boundary (service, cross-repo sync API, SDK, HTTP/RPC/GraphQL, queue). For every changed
  boundary call it locates the callee's real source and proves four gates — the parameter is
  **accepted** (the callee reads that name at all), the value is **honoured** (it is in the set the
  callee acts on, not silently defaulted), the format is **interpreted** identically on both sides
  (timezone of a naive datetime, seconds vs milliseconds, inclusive vs exclusive bound, 0- vs
  1-based offset), and the response shape is what the caller **reads** (map vs list, error channel,
  conditionally present fields). Includes a defect catalog (silent no-op parameter, decorative
  validation, dropped scoping argument, unbounded cost amplified downstream, error-channel
  mismatch, default drift), a reference-caller comparison step, recipes for finding the callee
  (vendor dirs, sibling checkouts, proto/OpenAPI/GraphQL schemas), and a hard rule that a claim
  without a callee quote goes to `Unverified assumptions` rather than into the findings. These
  defects survive linters, type checkers, and mocked tests — the mock encodes the caller's
  assumption, which is exactly what is under review.
  ([agents/contract-reviewer.md](agents/contract-reviewer.md))
- **`review-verifier` agent** — adversarial second pass over a finding list from any source
  (reviewer agent, static analyser, colleague, earlier session). It tries to **refute** each claim
  against the code and returns `CONFIRMED` / `REFUTED` / `OVERSTATED` / `UNPROVEN` with cited
  evidence, on the principle that the burden of proof sits on the finding: what cannot be proven is
  not published as a defect. Refutation checklist (guard one frame up, real types, the callee's
  actual behaviour, framework defaults, reachability, tests that use the real dependency, revision
  drift, documented-as-intentional), symmetric evidence bar for refutation and confirmation,
  severity budget with explicit `not attempted` instead of silent truncation, and an output split
  into *publish* / *retracted* / *open questions*. Deliberately narrow: it verifies, it does not
  discover, so a second pair of eyes cannot add a second layer of unverified claims. Findings it
  receives are treated as untrusted data, not instructions.
  ([agents/review-verifier.md](agents/review-verifier.md))

## [1.8.0] — 2026-08-07

### Added
- **`js-reviewer` agent** — front-end reviewer for JavaScript/TypeScript and Vue (Vue 3 Options and
  Composition API, Vue 2, Nuxt, framework-free browser code), filling the gap left by the PHP and
  Python reviewers. Two steps precede the checklist, and both exist because skipping them is how
  front-end review usually goes wrong: **detect the stack** (a repo often holds several apps of
  different ages — proposing `<script setup>` in a 500-file Options API codebase, or Composition API
  in Vue 2, is the most common failure mode), and **read the linter** — not only to avoid repeating
  it, but to find where its coverage silently ends (a flat config whose single `files: ['**/*.vue']`
  block leaves every `.js` unchecked; `ignores` nested inside a `files` block and therefore not
  global; `--ext` in an npm script, ignored by ESLint 9; `vue3-essential` never extended, so
  `require-v-for-key`, `no-mutating-props` and `no-side-effects-in-computed-properties` are off; a
  config no CI job runs). A coverage gap is itself a finding, and it tells the reviewer which checks
  to perform by hand.

  The checklist targets what tooling cannot see: XSS through `v-html`/`innerHTML`/
  `dangerouslySetInnerHTML` traced to its data source (with the deliberate server-sanitised-markup
  case explicitly listed as a false positive), URL and `postMessage` sinks, secrets inlined into the
  bundle; HTTP status ignored because `fetch` resolves on 4xx/5xx, swallowed rejections, unhandled
  aborts, request races in search/filter inputs; leaks that only matter in a tab left open for hours
  — listeners, timers, observers, and third-party chart/map/editor instances never destroyed on
  unmount; Vue correctness (`v-for` keys, prop mutation, side effects in `computed`, reactivity loss
  on destructuring, factory defaults); component contracts (`emits`, `$refs`, two-way binding);
  store discipline; SSR/hydration; and a11y basics. Plus eleven front-end-specific false positives
  and a rule that code slated for deletion gets correctness review, not modernisation advice.
  ([agents/js-reviewer.md](agents/js-reviewer.md))

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
