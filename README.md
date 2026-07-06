# claude-dev-agents

![version](https://img.shields.io/badge/version-1.5.0-blue)

Curated [Claude Code](https://claude.com/claude-code) **subagents** and **skills** for software development — a language-agnostic systems architect plus strictly-typed, tested, idiomatic PHP and Python builders with built-in reviewers.

> Check installed version: `./install.sh --version` (or `.\install.ps1 -Version`).

## What's inside

### Agents (`agents/`)
| Agent | Purpose |
|-------|---------|
| `architect` | Language-agnostic systems architect — designs, trade-offs, ADRs grounded in the real codebase; writes docs/ADRs, never code |
| `backlog-planner` | Scans the codebase and produces a consistently-structured, ICE-prioritized development backlog (pain · impact · effort) at `docs/backlog/BACKLOG.md`; docs only, never code (read-only git for dates/hashes) |
| `data-analyst` | Turns a raw dataset (xlsx/csv/json) into a self-contained one-page HTML report — KPI cards, inline-SVG charts, full metrics table; every metric as absolute + % |
| `devops-engineer` | DevOps builder — CI/CD pipelines (GitHub Actions/GitLab CI/Jenkins), Dockerfiles, Kubernetes/Helm, IaC (Terraform/Ansible), deployment strategies with rollback, observability, build/pipeline performance; pinned, least-privilege, idempotent automation |
| `facilitator` | Designs facilitation sessions, workshops and brainstorms — classifies the meeting (base / strategic / global), sets rational + existential goals and pyramid level, drafts the main question, a timed scenario grid, a question bank, run-time lifehacks and risk profiling; outputs one Markdown meeting plan in the request's language |
| `php-developer` | PHP 8.3+ builder — Laravel/Symfony APIs, services, CLI, queues, packages |
| `php-reviewer` | PHP reviewer — PSR-12, strict types, security (SQLi/XSS/CSRF), framework patterns |
| `python-developer` | Python 3.11+ builder — FastAPI/Flask/Django, async, CLI, data pipelines |
| `python-reviewer` | Python reviewer — PEP 8, type hints, security, performance |

### Skills (`skills/`)
| Skill | Purpose |
|-------|---------|
| `php-patterns` | Idiomatic PHP 8.3+ patterns — enums, readonly DTOs, repository/service layers, Laravel/Symfony, security, testing |
| `python-patterns` | Idiomatic Python 3.11+ patterns — type hints, idioms, async/TaskGroup, FastAPI, tooling |
| `facilitation-patterns` | Facilitation craft — goals pyramid, the main question, Strachan's questioning principles, method catalog (brainstorm, 6-3-5, 1-2-4-All, World Café, Liberating Structures, SWOT/SOAR, dot-voting…), preparation & the after-phase, online facilitation |

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

## Use

After install, restart Claude Code (or start a new session). Agents are invoked automatically by Claude when relevant, or explicitly:

```
> use the architect agent to design the data sync between service A and B
> use the php-developer agent to build a Laravel webhook controller
```

Skills activate automatically based on their description, or via the `Skill` tool.

## Uninstall

```bash
./install.sh --uninstall            # from user scope
./install.sh --uninstall --project  # from project scope
```

Uninstall is **receipt-driven** (see [ADR-0001](docs/adr/0001-name-keyed-install-set-as-uninstall-manifest.md)): install records every file it places, with a content hash, in `<scope>/.claude/.cda-manifest`. Uninstall removes only files it can prove it installed and that you have **not** modified — your edits and same-named files from other sources are kept, not deleted. If no manifest is present, uninstall refuses rather than guess.

## License

MIT — see [LICENSE](LICENSE).
