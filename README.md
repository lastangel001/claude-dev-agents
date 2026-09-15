# claude-dev-agents

![version](https://img.shields.io/badge/version-1.20.0-blue)

Curated [Claude Code](https://claude.com/claude-code) **subagents** and **skills** for software development — a language-agnostic systems architect plus strictly-typed, tested, idiomatic PHP and Python builders with built-in reviewers, a front-end reviewer for JavaScript/TypeScript and Vue, language-agnostic review roles for cross-service contracts and for verifying findings before they reach the author, and a QA pair: a coverage strategist/auditor and a Playwright E2E builder.

> Check installed version: `./install.sh --version` (or `.\install.ps1 -Version`).

## What's inside

### Agents (`agents/`)
| Agent | Purpose |
|-------|---------|
| `analyst-writer` | Business + systems analyst with a technical writer's craft — turns research results, task breakdowns and incident post-mortems into business-readable narratives (business layer first, technical appendix after), with an explicit **«объясни нетехническому специалисту»** direction inside Explain (reader named first, term list built before writing, mechanism through observable behaviour, metrics given a scale, procedure names exiled to the appendix), routing to `explanation-patterns` for the shape and `ru-output-style` for the wording, and a separate read-with-someone-else's-eyes pass before delivery; runs requirements analysis with fact/assumption separation, a proportionality check before the solution is elaborated, and prioritized clarifying questions, drafts tracker-ready tasks (created only after user approval); deliverables: Markdown or self-contained interactive HTML (inline JS controls, MathML/SVG formulas) |
| `architect` | Language-agnostic systems architect — designs, trade-offs, ADRs grounded in the real codebase; writes docs/ADRs, never code |
| `backlog-planner` | Scans the codebase and produces a consistently-structured, ICE-prioritized development backlog (pain · impact · effort) at `docs/backlog/BACKLOG.md`; docs only, never code (read-only git for dates/hashes) |
| `contract-reviewer` | Cross-boundary contract reviewer — for every changed call leaving the module (service, SDK, HTTP/RPC API, queue) opens the callee's real implementation and proves four gates: parameter accepted, value honoured, format interpreted identically, response shape as read; language-agnostic |
| `critic` | Cold adversarial review of a design before it becomes an issue, an ADR or a PR — arrives without the discussion history, hunts unstated assumptions, failure modes, unconsidered alternatives, internal contradictions, irreversibility and standing operational cost; grounds every assumption in the actual repo, calibrates rigor to reversibility, and hands back falsifiable scenarios instead of a rewritten design |
| `data-analyst` | Turns a raw dataset (xlsx/csv/json) into a self-contained one-page HTML report — KPI cards, inline-SVG charts, full metrics table; every metric as absolute + % |
| `devops-engineer` | DevOps builder — CI/CD pipelines (GitHub Actions/GitLab CI/Jenkins), Dockerfiles, Kubernetes/Helm, IaC (Terraform/Ansible), deployment strategies with rollback, observability, build/pipeline performance; pinned, least-privilege, idempotent automation |
| `facilitator` | Designs facilitation sessions, workshops and brainstorms — classifies the meeting (base / strategic / global), sets rational + existential goals and pyramid level, drafts the main question, a timed scenario grid, a question bank, run-time lifehacks and risk profiling; outputs one Markdown meeting plan in the request's language |
| `js-reviewer` | JS/TS front-end reviewer — Vue 3 (Options and Composition), Vue 2, Nuxt, framework-free browser code; detects the project's stack and linter coverage first, then reviews what tooling misses: XSS via raw-HTML rendering, reactivity and lifecycle bugs, listener/chart/observer leaks, component contracts, store discipline, request-layer failure handling |
| `php-developer` | PHP 8.3+ builder — Laravel/Symfony APIs, services, CLI, queues, packages |
| `php-reviewer` | PHP reviewer — PSR-12, strict types, security (SQLi/XSS/CSRF), framework patterns |
| `python-developer` | Python 3.11+ builder — FastAPI/Flask/Django, async, CLI, data pipelines |
| `python-reviewer` | Python reviewer — PEP 8, type hints, security, performance |
| `qa-expert` | QA strategist and coverage auditor — test strategy at project/feature start (risk analysis, level assignment, testability of acceptance criteria → `docs/qa/TEST-STRATEGY.md`), PR test-coverage audit (behavioral coverage, assertion quality, edge/error paths), and a regular project audit of coverage actuality (dead/skipped tests, stale suites) persisting a stable-ID feature × level matrix to `docs/qa/COVERAGE-MATRIX.md`; docs only, never code |
| `review-verifier` | Adversarial verifier for review findings — tries to refute each claim against the code and returns CONFIRMED / REFUTED / OVERSTATED / UNPROVEN with cited evidence; burden of proof on the finding, so unproven claims never reach the author |
| `test-automator` | Playwright E2E builder — bootstraps the toolchain itself (`@playwright/test`, browsers, config), writes stable tests (POM, fixtures, data-testid, auto-waiting, no fixed timeouts), stabilizes flaky tests (`--repeat-each`, trace-driven diagnosis, referenced quarantine), prepares CI integration and writes the environment spec for devops at `docs/qa/ENVIRONMENT.md`; takes e2e gaps from qa-expert's matrix as its backlog |

### Skills (`skills/`)
| Skill | Purpose |
|-------|---------|
| `php-patterns` | Idiomatic PHP 8.3+ patterns — enums, readonly DTOs, repository/service layers, Laravel/Symfony, security, testing |
| `python-patterns` | Idiomatic Python 3.11+ patterns — type hints, idioms, async/TaskGroup, FastAPI, tooling |
| `facilitation-patterns` | Facilitation craft — goals pyramid, the main question, Strachan's questioning principles, method catalog (brainstorm, 6-3-5, 1-2-4-All, World Café, Liberating Structures, SWOT/SOAR, dot-voting…), preparation & the after-phase, online facilitation |
| `explanation-patterns` | Shapes for delivering information so the reader can follow the reasoning — Minto pyramid + SCQA + MECE for a document, Context-Action-Result for a narrative, Need-Solution-Result for a proposal, **a six-beat shape for a decision somebody else has to make** (question, options including «do nothing», price and gain of each, reversibility, your recommendation, who decides by when), What/So-what/Now-what for a paragraph, and **mechanism plus failure condition** for explaining a defect; picks the shape by scale and genre (each with its own "does not fit"), forbids visible scaffolding (no heading named after a beat), **refuses to invent the need behind a proposal** (no concrete scenario in which the need shows itself means it is not established: the gap is reported as a gap and proportionality flagged), makes the «so what» mandatory for every fact, and adds density ceilings (one «доля (N из M)» per paragraph, enumerations no longer than four, business-layer sentences under ~25 words, frame sentences explicitly legal); language-agnostic, `references/frameworks.md` + `references/diagnosis.md` |
| `ru-output-style` | Style guard for Russian prose written for humans (findings, verdicts, plans, summaries) — hard-bans the telltale AI-slop patterns (negative parallelisms, long dash, math signs in prose, rule of three, «подводя итог» closings, unusable gerunds like «платя», closing clauses with nothing to check) **and guards reader comprehension** (a term is glossed at its first use, opposite pairs are defined when introduced, a percentage carries its base, result before method, a defect is written as a condition rather than an absence, an evaluation carries its threshold) + a distilled 52-pattern catalog (with a «Разборы пограничных случаев» section that rules on every pair of rules which look contradictory) with cures, gold examples per genre (`references/gold.md`), a deterministic linter (`scripts/lint-ru.sh` — exit 1 on hard bans; warns on rhythm monotony, AI-lexicon, in HTML on a gloss attached to a later occurrence than the first bare one, and on the density ceilings and framework-named headings documented in `explanation-patterns`) and a mandatory three-question final check (fact integrity + preserve-human-details, adapted from [blader/humanizer](https://github.com/blader/humanizer), plus «can the reader parse this»); distilled from [smixs/humanizer-ru](https://github.com/smixs/humanizer-ru) (MIT) |
| `playwright-patterns` | Playwright E2E patterns — Page Object Model & fixtures, config house defaults (pinned locale/timezone/viewport, artifacts on failure), flaky-test diagnosis by cause with cures, CI integration (GitHub Actions/GitLab, sharding), critical-flow testing (financial/destructive guards, wallet/web3 mocking) |

Each skill is a thin `SKILL.md` entry point (principles digest + routing table) plus
`references/*.md` read on demand — agents load only the sections the task needs instead
of the whole skill.

## Install

### One-liner

**macOS / Linux:**
```bash
curl -fsSL https://raw.githubusercontent.com/lastangel001/claude-dev-agents/main/install.sh | bash
```

**Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/lastangel001/claude-dev-agents/main/install.ps1 | iex
```

### Scope: user vs project

By default the installer copies into your **user** Claude config (`~/.claude/`), making the agents and skills available in every project.

To install into the **current project only** (`./.claude/`):

```bash
# macOS / Linux
curl -fsSL https://raw.githubusercontent.com/lastangel001/claude-dev-agents/main/install.sh | bash -s -- --project
```

```powershell
# Windows — clone then run with -Project
git clone https://github.com/lastangel001/claude-dev-agents
.\claude-dev-agents\install.ps1 -Project
```

### Manual

```bash
git clone https://github.com/lastangel001/claude-dev-agents
cd claude-dev-agents
./install.sh            # user scope  (~/.claude)
./install.sh --project  # project scope (./.claude)
```

The installer auto-discovers and copies **every** agent and skill in the repo (no list to maintain):
- `agents/*.md`  →  `<scope>/.claude/agents/`
- `skills/*/`    →  `<scope>/.claude/skills/`

Existing files with the same name are backed up to a timestamped dir under `<scope>/.claude/.cda-backups/` before overwrite — kept outside `agents/` and `skills/` so Claude Code never loads a backup as a duplicate.

### Installing a single agent (atomic)

Use `--agent NAME` (repeatable) to install just one or a few agents instead of the whole set. Skills are left untouched, and the operation is atomic — an unknown name aborts before anything is copied, and the manifest is merged (not overwritten), so it never orphans agents/skills from a prior full install.

```bash
# macOS / Linux — one agent, user scope
./install.sh --agent architect

# multiple agents, project scope
./install.sh --agent architect --agent python-developer --project

# via the one-liner
curl -fsSL https://raw.githubusercontent.com/lastangel001/claude-dev-agents/main/install.sh | bash -s -- --agent devops-engineer
```

```powershell
# Windows — one agent
.\install.ps1 -Agent architect

# multiple agents (comma-separated array), project scope
.\install.ps1 -Agent architect,python-developer -Project
```

Remove a single agent the same way, leaving the rest of the install intact:

```bash
./install.sh --uninstall --agent architect
```

```powershell
.\install.ps1 -Uninstall -Agent architect
```

## Use

After install, restart Claude Code (or start a new session). Agents are invoked automatically by Claude when relevant, or explicitly:

```
> use the architect agent to design the data sync between service A and B
> use the critic agent on this design before I turn it into an issue
> use the php-developer agent to build a Laravel webhook controller
> use the contract-reviewer agent on this diff — it calls the billing service
> use the review-verifier agent on the findings above before I post them
> use the qa-expert agent to audit test coverage on this PR
> use the test-automator agent to cover the checkout flow with Playwright tests
```

`critic` runs one step earlier than any of the reviewers: it reads a decision that does not exist as
code yet, so the cheap fix is still a paragraph. `architect` drafts, `critic` pressure-tests. Of the
resulting findings, the repo-grounded ones (a mechanism claimed to exist, a contradiction with a
recorded decision) can go through `review-verifier`; the design-level ones (an untested assumption, an
alternative never compared) have no code to refute them against and go to the author as questions.

The two review roles compose with the language reviewers rather than replacing them: run
`php-reviewer`/`python-reviewer`/`js-reviewer` for the code, `contract-reviewer` for what the code says to the
other side of a boundary, then `review-verifier` over the combined findings before anything is
published to the author.

Skills activate automatically based on their description, or via the `Skill` tool.

The QA pair works as a loop: `qa-expert` owns the coverage matrix (`docs/qa/COVERAGE-MATRIX.md`) and
hands e2e gaps to `test-automator`, which writes the Playwright tests and maintains the environment
spec for devops (`docs/qa/ENVIRONMENT.md`). For a recurring actuality check, schedule qa-expert's
project-audit mode in the target project (cron/scheduled task) — each run diffs the matrix against
the previous one.

## Uninstall

```bash
./install.sh --uninstall            # from user scope
./install.sh --uninstall --project  # from project scope
```

Uninstall is **receipt-driven** (see [ADR-0001](docs/adr/0001-name-keyed-install-set-as-uninstall-manifest.md)): install records every file it places, with a content hash, in `<scope>/.claude/.cda-manifest`. Uninstall removes only files it can prove it installed and that you have **not** modified — your edits and same-named files from other sources are kept, not deleted. If no manifest is present, uninstall refuses rather than guess.

## License

MIT — see [LICENSE](LICENSE).
