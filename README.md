# claude-dev-agents

![version](https://img.shields.io/badge/version-1.14.1-blue)

Curated [Claude Code](https://claude.com/claude-code) **subagents** and **skills** for software development — a language-agnostic systems architect plus strictly-typed, tested, idiomatic PHP and Python builders with built-in reviewers, a front-end reviewer for JavaScript/TypeScript and Vue, and language-agnostic review roles for cross-service contracts and for verifying findings before they reach the author.

> Check installed version: `./install.sh --version` (or `.\install.ps1 -Version`).

## What's inside

### Agents (`agents/`)
| Agent | Purpose |
|-------|---------|
| `analyst-writer` | Business + systems analyst with a technical writer's craft — turns research results, task breakdowns and incident post-mortems into business-readable narratives (business layer first, technical appendix after), runs requirements analysis with fact/assumption separation and prioritized clarifying questions, drafts tracker-ready tasks (created only after user approval); deliverables: Markdown or self-contained interactive HTML (inline JS controls, MathML/SVG formulas) |
| `architect` | Language-agnostic systems architect — designs, trade-offs, ADRs grounded in the real codebase; writes docs/ADRs, never code |
| `backlog-planner` | Scans the codebase and produces a consistently-structured, ICE-prioritized development backlog (pain · impact · effort) at `docs/backlog/BACKLOG.md`; docs only, never code (read-only git for dates/hashes) |
| `contract-reviewer` | Cross-boundary contract reviewer — for every changed call leaving the module (service, SDK, HTTP/RPC API, queue) opens the callee's real implementation and proves four gates: parameter accepted, value honoured, format interpreted identically, response shape as read; language-agnostic |
| `data-analyst` | Turns a raw dataset (xlsx/csv/json) into a self-contained one-page HTML report — KPI cards, inline-SVG charts, full metrics table; every metric as absolute + % |
| `devops-engineer` | DevOps builder — CI/CD pipelines (GitHub Actions/GitLab CI/Jenkins), Dockerfiles, Kubernetes/Helm, IaC (Terraform/Ansible), deployment strategies with rollback, observability, build/pipeline performance; pinned, least-privilege, idempotent automation |
| `facilitator` | Designs facilitation sessions, workshops and brainstorms — classifies the meeting (base / strategic / global), sets rational + existential goals and pyramid level, drafts the main question, a timed scenario grid, a question bank, run-time lifehacks and risk profiling; outputs one Markdown meeting plan in the request's language |
| `js-reviewer` | JS/TS front-end reviewer — Vue 3 (Options and Composition), Vue 2, Nuxt, framework-free browser code; detects the project's stack and linter coverage first, then reviews what tooling misses: XSS via raw-HTML rendering, reactivity and lifecycle bugs, listener/chart/observer leaks, component contracts, store discipline, request-layer failure handling |
| `php-developer` | PHP 8.3+ builder — Laravel/Symfony APIs, services, CLI, queues, packages |
| `php-reviewer` | PHP reviewer — PSR-12, strict types, security (SQLi/XSS/CSRF), framework patterns |
| `python-developer` | Python 3.11+ builder — FastAPI/Flask/Django, async, CLI, data pipelines |
| `python-reviewer` | Python reviewer — PEP 8, type hints, security, performance |
| `review-verifier` | Adversarial verifier for review findings — tries to refute each claim against the code and returns CONFIRMED / REFUTED / OVERSTATED / UNPROVEN with cited evidence; burden of proof on the finding, so unproven claims never reach the author |

### Skills (`skills/`)
| Skill | Purpose |
|-------|---------|
| `php-patterns` | Idiomatic PHP 8.3+ patterns — enums, readonly DTOs, repository/service layers, Laravel/Symfony, security, testing |
| `python-patterns` | Idiomatic Python 3.11+ patterns — type hints, idioms, async/TaskGroup, FastAPI, tooling |
| `facilitation-patterns` | Facilitation craft — goals pyramid, the main question, Strachan's questioning principles, method catalog (brainstorm, 6-3-5, 1-2-4-All, World Café, Liberating Structures, SWOT/SOAR, dot-voting…), preparation & the after-phase, online facilitation |
| `ru-output-style` | Style guard for Russian prose written for humans (findings, verdicts, plans, summaries) — hard-bans the telltale AI-slop patterns (negative parallelisms, long dash, math signs in prose, rule of three, «подводя итог» closings) + a distilled 42-pattern catalog with cures, gold examples per genre (`references/gold.md`), a deterministic linter (`scripts/lint-ru.sh` — exit 1 on hard bans, rhythm-monotony and AI-lexicon warnings) and a mandatory final check (fact integrity + preserve-human-details, adapted from [blader/humanizer](https://github.com/blader/humanizer)); distilled from [smixs/humanizer-ru](https://github.com/smixs/humanizer-ru) (MIT) |

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
> use the php-developer agent to build a Laravel webhook controller
> use the contract-reviewer agent on this diff — it calls the billing service
> use the review-verifier agent on the findings above before I post them
```

The two review roles compose with the language reviewers rather than replacing them: run
`php-reviewer`/`python-reviewer`/`js-reviewer` for the code, `contract-reviewer` for what the code says to the
other side of a boundary, then `review-verifier` over the combined findings before anything is
published to the author.

Skills activate automatically based on their description, or via the `Skill` tool.

## Uninstall

```bash
./install.sh --uninstall            # from user scope
./install.sh --uninstall --project  # from project scope
```

Uninstall is **receipt-driven** (see [ADR-0001](docs/adr/0001-name-keyed-install-set-as-uninstall-manifest.md)): install records every file it places, with a content hash, in `<scope>/.claude/.cda-manifest`. Uninstall removes only files it can prove it installed and that you have **not** modified — your edits and same-named files from other sources are kept, not deleted. If no manifest is present, uninstall refuses rather than guess.

## License

MIT — see [LICENSE](LICENSE).
