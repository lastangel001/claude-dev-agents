---
name: pipeline-init
description: "Sets up the development pipeline for a project and writes it down so every later session knows which agents run when: scans the repository for pipeline signals (stack, CI, review process, migrations, external calls, tests), asks three or four questions, shows the plan, and after an explicit yes writes a thin block into the project's CLAUDE.md and the full docs/PIPELINE.md (stages by operation and size, two gates, autonomy mode, security triggers, artifact paths, definition of done). Re-run on a project that already has docs/PIPELINE.md to diff the signals and propose updates. Activate when the user asks where to start on a project, which agents to use here, how to organise the work, to set up the process or pipeline, or starts a new project; triggers: «с чего начать на этом проекте», «какие агенты здесь нужны», «настрой пайплайн / процесс разработки», «новый проект, как организовать работу», «set up the pipeline», «which agents should I use here», «how should we work on this repo»."
---

# pipeline-init

Writes the project's pipeline down once, at the level of the project, so no session has to be
told by hand which agents are needed and where. A skill, not an agent: it asks the user questions
and waits for the answers, which a subagent cannot do. Run from the repository root.

The pipeline it writes is not universal. The **skeleton** is (the order of stages, who owns each,
the two gates, the terminal states: `references/stages.md`); the **filled copy** is this project's
(which stages are mandatory for which operation and size, which agents are active, where
artifacts live, how much autonomy). This skill fills the copy.

## Output language

`docs/PIPELINE.md` and the CLAUDE.md block are written in the **user's language**: the language of
the request, unless the user's own Claude configuration states a preference (check `~/.claude/CLAUDE.md`
and any identity or preferences file it points at; a stated «answer in Russian» wins over the
language of a one-line request). Stage names, agent names, file paths and the `## ` headings the
agents look up stay in English.

## Phase 1 — read the project

1. If `.claude-docs/architecture.md` exists (written by `/onboard-memory` or by hand), read its
   stack, layers and entry points. That file is the architecture map; do not rebuild it here. If
   it is absent, note that `/onboard-memory` would give later sessions a map, and read the
   manifests yourself.
2. Run the signals script and keep its output verbatim for the `## Signals` section:

   ```bash
   bash "${CLAUDE_SKILL_DIR}/scripts/pipeline-signals.sh"
   ```

   On Windows without Git Bash: `powershell -NoProfile -File "<skill dir>\scripts\pipeline-signals.ps1"`.
   Both print the same text. The script emits observations, never verdicts: it says
   `migrations-dir: database/migrations`, not «migrations are a one-way door here». The
   decisions are yours, with the user.
3. If `pipeline-md: present`: this is an **update run**. Read `docs/PIPELINE.md`, compare its
   `## Signals at the time of writing` block with the fresh output, and go to Phase 3 with a list
   of differences (a migrations directory appeared, CI jobs changed, an external client count
   jumped) and the changes each one implies. Do not rewrite the file; patch the sections the
   differences touch and preserve every hand edit.

What the signals mean for the stage mask (defaults, to confirm in Phase 2):

| Signal | Implication |
|---|---|
| `migrations-dir` present | the data model is a one-way door: stages 2 and 3 mandatory for `feature`/`change` at `standard` and above |
| `api-schema` present, or a public package | the API contract is a one-way door: stage 7 mandatory whenever the schema changes |
| `external-client-files` above zero | stage 7 is a live possibility on every change; say it at Gate 1 |
| `ci-job` lines | the delivery checklist includes «CI green»; `devops-engineer` is the owner of CI changes |
| `codeowners` or `pr-template` present | a human reviews PRs: Gate 2 output is written for that reviewer |
| `test-dir` absent | stage 4 runs on the first `feature` at `standard`; coverage stage waits until tests exist |
| `tracker-prefix` found | Clarify ends with a ticket reference in the requirements |

## Phase 2 — ask

Ask with the question tool when available, otherwise list the options numbered and end the turn.
Four questions at most; skip any the signals or the architecture map already answer, and say so.

1. **Operations.** Which kinds of work are typical here: features, behaviour changes, bug fixes,
   refactors, a new service from a spec, research without code? (Multiple answers.) The masks for
   the others stay at the skeleton defaults, marked as such.
2. **One-way doors.** Which changes are expensive to reverse in this project: data model, public
   API, service boundaries, auth model, something project-specific? Offer what the signals suggest
   as the default.
3. **Autonomy.** `propose` (every stage transition waits), `guided` (only the two gates wait),
   `autonomous` (only Gate 2 waits). Recommend `propose` for a project new to the pipeline.
4. **Reader and language.** Who reads the result of a task (a human reviewer on a PR, the tracker,
   only the user) and in which language the reports should be written.

A skipped or dismissed question is not an answer: ask again in plain text and wait.

## Phase 3 — show the card, then write

Before writing anything, show:

```
What I will set up
  Stack:            <from map or manifests>
  Active agents:    <builder, reviewer, ... matched to the stack>
  Not active here:  <agents the masks name but this stack does not use> — why
  One-way doors:    <answer 2>
  Mode:             <answer 3>
  Mandatory stages: <the rows that differ from the skeleton defaults>
  Files:            docs/PIPELINE.md (new|update), CLAUDE.md (block appended|updated)
```

The «not active» line is mandatory. A pipeline that names ten agents and runs two is correct, but
a reader cannot tell a correctly collapsed run from a broken one unless it is said.

Ask «Write these two files?» and wait for an explicit yes. On yes:

1. `docs/PIPELINE.md` from `templates/PIPELINE.md`, every `{{placeholder}}` filled or the line
   removed; the `## Signals at the time of writing` block holds the script output verbatim. In an
   update run, patch instead of overwrite.
2. The thin block in the project's `CLAUDE.md` from `templates/CLAUDE-block.md`: at most eight
   lines, appended under its own `## Pipeline` heading, or replaced in place if the heading
   already exists. If the project has no `CLAUDE.md`, create one holding only this block and say
   that `/onboard-memory` (or `/init`) fills the rest.

Never commit. End with the two paths and the one-line summary of the mode and the active set.

## Phase 4 — what later sessions do with it

Every session loads the CLAUDE.md block, which names the active agents and points at
`docs/PIPELINE.md`. At the start of a task the main loop states the operation and size in one line,
reads the matching row, announces the active set, and runs the stages; agents read the artifact
paths from the pipeline file before their own defaults. Gate 2 runs the «Before delivery» list.

## Reminder hook (optional)

`hooks/session-start.sh` (and `.ps1`) print one line at session start when the repository has
source files but no `docs/PIPELINE.md`. Nothing is installed automatically; the README of
claude-dev-agents shows the `settings.json` snippet. Remove the hook once every project you work in
has its pipeline.

## Reference routing

| Need | Read |
|---|---|
| The stage skeleton, default masks, gates, autonomy modes, security triggers, delivery checklist | [references/stages.md](references/stages.md) |
| The file to fill | [templates/PIPELINE.md](templates/PIPELINE.md) |
| The CLAUDE.md block | [templates/CLAUDE-block.md](templates/CLAUDE-block.md) |
| What each agent needs on input and hands over | `docs/AGENT-CONTRACT.md` in claude-dev-agents |
