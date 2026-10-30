# claude-dev-agents

![version](https://img.shields.io/badge/version-1.32.2-blue)

Curated [Claude Code](https://claude.com/claude-code) **subagents** and **skills** for software development — a language-agnostic systems architect plus strictly-typed, tested, idiomatic PHP and Python builders with built-in reviewers, a front-end reviewer for JavaScript/TypeScript and Vue, language-agnostic review roles for cross-service contracts and for verifying findings before they reach the author, and a QA pair: a coverage strategist/auditor and a Playwright E2E builder.

> Check installed version: `./install.sh --version` (or `.\install.ps1 -Version`).

## What's inside

### Agents (`agents/`)
| Agent | Purpose |
|-------|---------|
| `analyst-writer` | Thin fan-out wrapper over the `analyst-patterns` skill — business + systems analyst with a technical writer's craft, for the runs that need N fresh contexts (N task descriptions, a batch of post-mortems); the main loop uses the skill directly for dialogue-heavy work (Analyze mode, clarifying questions). Same three modes (Explain, Analyze, Draft-task), same routing to `explanation-patterns` and `ru-output-style`; tracker issues drafted only, created after approval |
| `architect` | Language-agnostic systems architect — designs, trade-offs, ADRs grounded in the real codebase; writes docs/ADRs, never code |
| `backlog-planner` | Scans the codebase and produces a consistently-structured, ICE-prioritized development backlog (pain · impact · effort) at `docs/backlog/BACKLOG.md`; docs only, never code (read-only git for dates/hashes) |
| `contract-reviewer` | Cross-boundary contract reviewer — for every changed call leaving the module (service, SDK, HTTP/RPC API, queue) opens the callee's real implementation and proves four gates: parameter accepted, value honoured, format interpreted identically, response shape as read; language-agnostic |
| `data-analyst` | Turns a raw dataset (xlsx/csv/json) into a self-contained one-page HTML report — KPI cards, inline-SVG charts, full metrics table; every metric as absolute + % |
| `design-reviewer` | Cold adversarial review of a technical design decision, three inputs: a design before it becomes an issue, an ADR or a PR; the approach behind a PR or diff before merge (the right place and coupling, not line-level correctness); an existing ADR revisited against the current code (do its assumptions still hold) — arrives without the discussion history, hunts unstated assumptions, failure modes, unconsidered alternatives, internal contradictions, irreversibility and standing operational cost; grounds every assumption in the actual repo, calibrates rigor to reversibility, hands back falsifiable scenarios instead of a rewritten design; not for UI/UX design |
| `devops-engineer` | DevOps builder — CI/CD pipelines (GitLab CI/GitHub Actions/Jenkins), Dockerfiles, Kubernetes/Helm, IaC (Terraform/Ansible), deployment strategies with rollback, observability, build/pipeline performance; pinned, least-privilege, idempotent automation; reads `devops-patterns` for the detail, keeps only the essentials inline |
| `js-developer` | JS/TS front-end builder — Vue 3 (Composition or Options), Vue 2, Nuxt, framework-free browser code; detects the project's stack and idiom first, writes typed, tested, linter-clean components, composables, Pinia stores, routes and request layers with lifecycle cleanup and XSS-safe rendering; reads `js-patterns` for idioms |
| `js-reviewer` | JS/TS front-end reviewer — Vue 3 (Options and Composition), Vue 2, Nuxt, framework-free browser code; detects the project's stack and linter coverage first, then reviews what tooling misses: XSS via raw-HTML rendering, reactivity and lifecycle bugs, listener/chart/observer leaks, component contracts, store discipline, request-layer failure handling |
| `php-developer` | PHP 8.3+ builder — Laravel/Symfony APIs, services, CLI, queues, packages |
| `php-reviewer` | PHP reviewer — PSR-12, strict types, security (SQLi/XSS/CSRF), framework patterns |
| `python-developer` | Python 3.11+ builder — FastAPI/Flask/Django, async, CLI, data pipelines |
| `python-reviewer` | Python reviewer — PEP 8, type hints, security, performance |
| `qa-expert` | QA strategist and coverage auditor — test strategy at project/feature start (risk analysis, level assignment, testability of acceptance criteria → `docs/qa/TEST-STRATEGY.md`), PR test-coverage audit (behavioral coverage, assertion quality, edge/error paths), and a regular project audit of coverage actuality (dead/skipped tests, stale suites) persisting a stable-ID feature × level matrix to `docs/qa/COVERAGE-MATRIX.md`; docs only, never code |
| `security-reviewer` | Cross-cutting security reviewer, language-agnostic and read-only — runs only when a diff touches a security trigger (auth, user input and uploads, DB queries, file-system paths from input, external calls, crypto/tokens/sessions, secrets and config, dependency manifests or CI workflows) and reviews what the language reviewers structurally cannot: the access model across the change, trust boundaries, secrets in repo and CI, SSRF and open redirects, weak crypto, vulnerable dependencies via the project's own audit tooling (never installs any), workflow permissions; eight families with questions, a pattern → severity → fix catalog, a false-positive list; every finding carries a reachable input or state so `review-verifier` can refute it; not a pentest, never writes exploits |
| `root-cause-investigator` | Read-only investigator of a failure — takes a symptom (error text, stack, log excerpt, failing test, reproduction steps, revision, time window) and returns the cause with an evidence chain (input or state → `file:line` → wrong outcome → why the guards do not fire); reproduces first, ranks hypotheses by the cost of checking, refutes them one by one, reads git history between «worked» and «broke», bisects on tests when cheaper; runs tests and scripts but never edits a file; hands the builder the failing test as text, the blast radius and the refuted hypotheses; «Not reproduced» is a valid verdict, a hypothesis is never reported as a cause |
| `review-verifier` | Adversarial verifier for review findings — tries to refute each claim against the code and returns CONFIRMED / REFUTED / OVERSTATED / UNPROVEN with cited evidence; burden of proof on the finding, so unproven claims never reach the author |
| `test-automator` | Playwright E2E builder — bootstraps the toolchain itself (`@playwright/test`, browsers, config), writes stable tests (POM, fixtures, data-testid, auto-waiting, no fixed timeouts), stabilizes flaky tests (`--repeat-each`, trace-driven diagnosis, referenced quarantine), prepares CI integration and writes the environment spec for devops at `docs/qa/ENVIRONMENT.md`; takes e2e gaps from qa-expert's matrix as its backlog |

### Skills (`skills/`)
| Skill | Purpose |
|-------|---------|
| `js-patterns` | Idiomatic front-end patterns — Vue 3 (SFC order, typed props/emits, `defineModel`, composables with cleanup, reactivity rules, Pinia setup stores, typed routes, Vue 3.5 APIs), Vue 2 differences and migration traps, Nuxt (`useAsyncData`/`useFetch`, server routes, runtime config), TypeScript at the boundary (`unknown` over `any`, discriminated unions, `satisfies`, guards for API responses), browser code (event delegation, `AbortController`, leaks in long-lived SPAs, one request client with surfaced errors, XSS-safe rendering), testing (Vitest, Vue Test Utils, MSW, no fixed timeouts) and tooling (ESLint flat config, `vue-tsc`, Vite, strict `tsconfig`); Vue sections distilled from [affaan-m/ECC](https://github.com/affaan-m/ECC) `vue-patterns` (MIT) |
| `php-patterns` | Idiomatic PHP 8.3+ patterns — enums, readonly DTOs, repository/service layers, Laravel/Symfony, security, testing |
| `python-patterns` | Idiomatic Python 3.11+ patterns — type hints, idioms, async/TaskGroup, FastAPI, tooling |
| `facilitation-patterns` | Facilitation craft, now including the meeting plan itself (the former `facilitator` agent folded in) — classify the meeting (base / strategic / global), goals pyramid and target level, the main question (главный вопрос), Strachan's questioning principles, client's role A / B / C, session lifecycle and real-time interventions, method catalog (brainstorm, 6-3-5, 1-2-4-All, World Café, Liberating Structures, SWOT/SOAR, dot-voting…), preparation & the after-phase, online facilitation, and the fixed plan skeleton (`references/plan-building.md`); the plan is written in the request's language, Russian prose via `ru-output-style` |
| `analyst-patterns` | Business + systems analysis and technical writing as a skill — Explain (business layer first, technical appendix after, the explicit «объясни нетехническому специалисту» direction), Analyze (fact/assumption separation, proportionality check before the solution is elaborated, prioritised clarifying questions), Draft-task (tracker-ready drafts), the forming-questions method and the read-with-someone-else's-eyes final check; routes to `explanation-patterns` for the shape and `ru-output-style` for the wording; loaded by the main loop for dialogue, by the `analyst-writer` agent for fan-out |
| `devops-patterns` | Delivery-infrastructure patterns for `devops-engineer` — CI on GitLab CI and GitHub Actions as equals (DAG stages, caches keyed on lockfile hash, matrices, minimal permissions, actions pinned by SHA and images by digest, OIDC over long-lived keys, fork safety, reusable templates, the aggregator job), Jenkins in one section; Docker (multi-stage builds per stack, non-root, digest pinning, `HEALTHCHECK`, BuildKit secrets, scanning); Kubernetes with Helm (requests and limits, probes, PDB, HPA, secrets, migrations as a one-runner job, RBAC, chart layout and per-environment values, `--atomic`); IaC (Terraform state, modules, reviewed `plan`, `moved` blocks, drift; Ansible idempotence, check mode, vault); deployment (rolling, blue-green, canary with metric gates, feature flags, expand → deploy → contract with `sql-patterns`, rollback runbook, post-deploy verification); observability (structured logs, RED/USE, SLOs, symptom alerts with runbooks); distilled from [affaan-m/ECC](https://github.com/affaan-m/ECC) (MIT) |
| `explanation-patterns` | Shapes for delivering information so the reader can follow the reasoning — Minto pyramid + SCQA + MECE for a document, Context-Action-Result for a narrative, Need-Solution-Result for a proposal, **a six-beat shape for a decision somebody else has to make** (question, options including «do nothing», price and gain of each, reversibility, your recommendation, who decides by when), What/So-what/Now-what for a paragraph, and **mechanism plus failure condition** for explaining a defect; picks the shape by scale and genre (each with its own "does not fit"), forbids visible scaffolding (no heading named after a beat), **refuses to invent the need behind a proposal** (no concrete scenario in which the need shows itself means it is not established: the gap is reported as a gap and proportionality flagged), makes the «so what» mandatory for every fact, and adds density ceilings (one «доля (N из M)» per paragraph, enumerations no longer than four, business-layer sentences under ~25 words, frame sentences explicitly legal); language-agnostic, `references/frameworks.md` + `references/diagnosis.md` |
| `sql-patterns` | Data-store patterns for builders and reviewers — schema (types, constraints, composite and partial indexes, FK indexes, soft delete, multi-tenant filters; per-engine notes for PostgreSQL, MySQL/MariaDB and SQLite), queries (N+1 per ORM, cursor pagination, EXPLAIN reading, isolation levels, lock ordering, `SKIP LOCKED`, short transactions), migrations (expand-contract, concurrent indexes, batched backfills, forward-only rollback, per-tool workflows for Alembic, Django, Doctrine Migrations and Laravel), ORM escape hatches kept parameterised (Eloquent, Doctrine, Django ORM, SQLAlchemy), and NoSQL (MongoDB, Redis/Dragonfly, ClickHouse, Elasticsearch/OpenSearch); wired into `php-developer`, `python-developer`, `php-reviewer`, `python-reviewer` and `design-reviewer`; migration and PostgreSQL sections distilled from [affaan-m/ECC](https://github.com/affaan-m/ECC) (MIT) |
| `ru-output-style` | Style guard for Russian prose written for humans (findings, verdicts, plans, summaries) — hard-bans the telltale AI-slop patterns (negative parallelisms, long dash, math signs in prose, rule of three, «подводя итог» closings, unusable gerunds like «платя», closing clauses with nothing to check) **and guards reader comprehension** (a term is glossed at its first use, opposite pairs are defined when introduced, a percentage carries its base, result before method, a defect is written as a condition rather than an absence, an evaluation carries its threshold) + a distilled 52-pattern catalog (with a «Разборы пограничных случаев» section that rules on every pair of rules which look contradictory) with cures, gold examples per genre (`references/gold.md`), a deterministic linter (`scripts/lint-ru.sh` — exit 1 on hard bans; warns on rhythm monotony, AI-lexicon, in HTML on a gloss attached to a later occurrence than the first bare one, and on the density ceilings and framework-named headings documented in `explanation-patterns`) and a mandatory three-question final check (fact integrity + preserve-human-details, adapted from [blader/humanizer](https://github.com/blader/humanizer), plus «can the reader parse this»); distilled from [smixs/humanizer-ru](https://github.com/smixs/humanizer-ru) (MIT) |
| `playwright-patterns` | Playwright E2E patterns — Page Object Model & fixtures, config house defaults (pinned locale/timezone/viewport, artifacts on failure), flaky-test diagnosis by cause with cures, CI integration (GitHub Actions/GitLab, sharding), critical-flow testing (financial/destructive guards, wallet/web3 mocking) |
| `pipeline-init` | Writes the project's development pipeline down once so every later session knows which agents run when — scans the repo for pipeline signals (`scripts/pipeline-signals.sh` + a byte-identical `.ps1`: stack, CI jobs, CODEOWNERS/PR template, migration dirs, API schemas, external-service calls, tests, tracker prefixes), reads `.claude-docs/architecture.md` when `/onboard-memory` has written one, asks at most four questions (typical operations, one-way doors, autonomy mode `propose`/`guided`/`autonomous`, reader and language), shows the plan including the agents it will **not** use here, and after an explicit yes writes `docs/PIPELINE.md` (stages by operation × size, two gates, security triggers, artifact paths, definition of done, delivery checklist) in the user's language plus an eight-line block in the project's `CLAUDE.md`; re-run to diff signals and patch; optional SessionStart reminder hook in `hooks/` |
| `address-review` | The author's side of the review loop — takes `review-verifier`'s «Publish these» list (or raw reviewer output, marked `unverified`) plus the branch, answers every finding with `addressed` / `declined` (only with a reason citing code or a recorded decision) / `clarifying` (one question, the status each answer leads to) / `skipped` (blast-radius guard: no fixes outside the diff, over a third of a file, on a public contract or needing a design decision; follow-up named), makes the smallest fix, runs lint and tests on the touched files, commits fix-ups in `guided`/`autonomous` mode, and returns the per-finding table plus reply drafts for the PR threads; never posts, never re-runs the reviewer — the orchestrator does both |

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
> use the design-reviewer agent on this design before I turn it into an issue
> use the design-reviewer agent on this PR — is the approach right, not the code
> use the design-reviewer agent on docs/adr/0007 — do its assumptions still hold
> use the php-developer agent to build a Laravel webhook controller
> use the contract-reviewer agent on this diff — it calls the billing service
> use the review-verifier agent on the findings above before I post them
> use the qa-expert agent to audit test coverage on this PR
> use the test-automator agent to cover the checkout flow with Playwright tests
```

`design-reviewer` reads decisions, not code: a design that does not exist as code yet (the cheap fix is
still a paragraph), the approach a PR embodies before merge (the language reviewers check the code, it
checks whether the code is in the right place), or an old ADR against today's code. `architect` drafts,
`design-reviewer` pressure-tests. Of the
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

### How agents chain

Every agent ends with the same four sections — `## Input`, `## Output`, `## Handoff`,
`## Fragile points` — so the main loop can hand work from one to the next without re-explaining
each link: a builder's report says which behaviours changed and which tests prove them, which is
what the language reviewer reads; a reviewer's findings carry severity, `file:line`, claim and
failure scenario, which is what `review-verifier` requires. The spec and the full chain table are
in [docs/AGENT-CONTRACT.md](docs/AGENT-CONTRACT.md).

A subagent cannot ask a question and wait, so when it cannot deliver the result it ends with one
of three **terminal states** on the first line: `NEEDS_INPUT` (a fact only you have would change
the result; the questions follow, each with the result it leads to), `BLOCKED` (a precondition
outside the brief is unmet: a tool not configured, an ADR still `Proposed`, a callee repository
not checked out) or `OUT_OF_SCOPE` (not this agent's job; it names whose). Show the state to the
user as is rather than folding it into a summary; answer it and re-run with the full brief. A
second `NEEDS_INPUT` from the same agent on the same task means the work belongs in the main
loop, with the conversation, not in a subagent.

### Setting up a project's pipeline

Run `/pipeline-init` once in a repository (or just ask «с чего начать на этом проекте» / «which
agents should I use here»). It scans the project, asks up to four questions and, after your yes,
writes `docs/PIPELINE.md` and a short `## Pipeline` block into the project's `CLAUDE.md`. From
then on every session states the task's operation and size, follows the matching row, announces
which agents it will spawn, and stops at the two gates. The universal skeleton (stage order, owners,
default masks, gates, autonomy modes) lives in the skill's `references/stages.md`; the project
file holds only what differs. Re-running on a project that has a pipeline file diffs the signals
and patches the file.

To be reminded in repositories that have code but no pipeline yet, add the optional SessionStart
hook to `~/.claude/settings.json` (nothing is installed automatically):

```json
{ "hooks": { "SessionStart": [ { "hooks": [ { "type": "command",
  "command": "bash ~/.claude/skills/pipeline-init/hooks/session-start.sh" } ] } ] } }
```

(`powershell -NoProfile -File $HOME/.claude/skills/pipeline-init/hooks/session-start.ps1` on
Windows without Git Bash.) It prints one line, or nothing.

## Uninstall

```bash
./install.sh --uninstall            # from user scope
./install.sh --uninstall --project  # from project scope
```

Uninstall is **receipt-driven** (see [ADR-0001](docs/adr/0001-name-keyed-install-set-as-uninstall-manifest.md)): install records every file it places, with a content hash, in `<scope>/.claude/.cda-manifest`. Uninstall removes only files it can prove it installed and that you have **not** modified — your edits and same-named files from other sources are kept, not deleted. If no manifest is present, uninstall refuses rather than guess.

## License

MIT — see [LICENSE](LICENSE).
