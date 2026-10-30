# Changelog

All notable changes to this project are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); versioning is [SemVer](https://semver.org/).

## [Unreleased]

## [1.34.1] — 2026-10-30

### Fixed
- **CI `agent-lint.sh` died with exit 141 on 1.34.0.** The block comparison used `awk … | head -n N`;
  with the new `### Project pipeline` block sitting in the middle of each agent file, `awk` kept
  printing after `head` had closed the pipe, got SIGPIPE, and `set -o pipefail` turned that into
  a failure on Linux (Git Bash on Windows does not reproduce it, which is why it passed locally).
  `awk` now stops itself after N lines; no pipe, no `head`. Same change for the terminal-states
  comparison, which only survived because that block sits at the end of the file.

## [1.34.0] — 2026-10-30

### Fixed
- **Agents now actually read `docs/PIPELINE.md`.** `pipeline-init` promised since 1.23.0 that
  «agents read the artifact paths from the pipeline file before their own defaults», but only
  `security-reviewer` mentioned the file; a subagent started without an explicit brief never
  opened it, and the project's rules for a role never reached the role. Found on the first real
  use of the skill in another session, where the workaround was a `## Project rules for agents`
  section in the project's pipeline file and a CLAUDE.md rule telling the main loop to paste the
  role's subsection into every brief. That shape is now the standard. Every agent's `## Input`
  ends with a verbatim `### Project pipeline` block (read `docs/PIPELINE.md` when it exists; its
  paths and gates apply; the role's subsection under `## Project rules for agents` overrides the
  agent file's defaults; a brief that quotes the subsection is complete, one that does not is
  still valid, but read the file), checked byte for byte by `test/agent-lint.sh` against
  `docs/AGENT-CONTRACT.md`, the same way the terminal-states block is. The pipeline template gains
  the `## Project rules for agents` section with one subsection per active agent (where the role
  writes, what it never touches, what the project adds), `pipeline-init` fills it in Phase 3, and
  the CLAUDE.md block tells the main loop to paste the subsection into each brief, since a
  subagent reads neither the conversation nor the project's `CLAUDE.md`. The lint now finds the
  spec's fenced blocks by their first line instead of by position.

## [1.33.0] — 2026-10-30

### Added
- **`security-patterns` — the security reviewer's knowledge lives once, and the builders can read
  it before the review.** `security-reviewer` carried its eight families with their questions, a
  pattern → severity → fix catalog and the false-positive list inline, 320 lines that every run
  paid for and no builder could consult. The skill holds it in five references: `families.md`
  (the eight families with the questions per family and one BAD/GOOD pair each: object-level
  authorization, uploads checked by content, `ORDER BY` from the request, path canonicalisation,
  SSRF with private ranges blocked, JWT with a pinned algorithm, production config, dependencies),
  `catalog.md` (26 rows, up from 22: mass assignment, identifiers in `ORDER BY`, missing timeouts
  and a lockfile out of step with the manifest are new; samples in PHP, Python and TypeScript per
  shape, and a table of how deployment context moves the severity word), `false-positives.md`
  (example files, fixtures, publishable keys, checksums, framework defaults named with their
  version, internal-only services with the evidence, the reachable-path rule, consolidation, what
  a zero-finding review must say), `audit-tooling.md` (read-only commands per stack: Composer,
  pip and Poetry, npm/pnpm/Yarn, `govulncheck`, `cargo audit`, `bundle audit`, .NET, Maven only
  when the plugin is configured, Trivy/Grype, `gitleaks`/`trufflehog`, `actionlint`; presence
  check first, never install, never `--fix`, «not checked» by name) and `ci-security.md`
  (`permissions` at the top and widened per job, `pull_request_target` with PR-head checkout and
  its three fixes, event-payload interpolation into `run:`, pinning by SHA and digest, secrets in
  logs, artifacts, build args and the command line, GitLab masked and protected variables, a
  checklist). Every sample is invented.

### Changed
- **`security-reviewer` slimmed from 320 to about 200 lines.** Keeps the role, scope, triggers,
  method, severity refinement, output format, approval criteria and the four contract sections;
  points at the skill the way `devops-engineer` points at `devops-patterns` (`## Security
  Patterns (read the skill)`), and carries an `## Essentials (always)` list of ten rules that hold
  when the skill is not loaded (reachable path, logged in is not authorized, group-level guard,
  bound values only, allowlisted outbound targets, framework crypto, rotate on exposure, audit
  counts from a tool that ran, severity by context, one finding per pattern). One more fragile
  point: the skill not found means the review ran on the essentials alone and must say so.
  Description unchanged, so the routing eval stands.
- **`php-developer`, `python-developer`, `js-developer` load `security-patterns` on a security
  trigger**: one paragraph each in the skill-loading section naming the triggers for that stack
  and the two references to read, so the code arrives at `security-reviewer` already written the
  way it reviews.

## [1.32.2] — 2026-10-30

### Added
- **`docs/reviews/2026-10-29-agents-review-vs-external.md` — the review that produced releases
  1.22.0 through 1.32.1.** The set was compared with Anthropic's «when to fold subagents into
  your main agent loop», openronin, Claude-Code-Game-Studios, and then ECC, VoltAgent and
  lodetomasi: which agents earn a fresh context and which belong in the main loop as skills, why a
  universal pipeline does not exist but a universal skeleton does, which gaps the chain had, and
  what each external set is worth borrowing from. Kept as the original analysis with a status
  note at the top (all twelve plan items shipped; two decisions changed on the way: the
  `analyst-writer` agent stayed as the thin fan-out form, `js-developer` was added). Russian prose,
  linted with `ru-output-style`.

## [1.32.1] — 2026-10-30

### Fixed
- **CI `static-bash` was red since 1.31.0: shellcheck SC2015 in `test/routing-cases-check.sh`.**
  Three `[ test ] && pass || fail` lines, the shape shellcheck flags because `fail` would also run
  if `pass` itself failed; rewritten as `if/else`. Nothing else in 1.31.0 or 1.32.0 was affected
  (the other jobs passed), but the aggregator `ci-pass` was failing with them.

## [1.32.0] — 2026-10-30

### Changed
- **Silent failures get their own block in every language reviewer.** Each reviewer had one
  bullet on the empty catch; the other shapes of a failure the caller cannot see were caught only
  when the reviewer happened to think of them. `php-reviewer` and `python-reviewer` now carry the
  five shapes in the CRITICAL error-handling family, with the language's own idioms: a catch that
  logs without context and carries on; a fallback that hides the failure (`?? []`, `or []`,
  `return null`, `.get()` where a `KeyError` belonged); a rethrow that drops the original (no
  `previous`, no `from e`); a network, file or DB call with no timeout and no error path;
  transactional work with no rollback on the failure branch, or an `asyncio` task whose exception
  nobody awaits. The front end gets the same five in `js-patterns/references/browser.md`
  (`.catch(() => [])`, log-and-forget, `throw new Error('x')` without `{ cause }`, no
  `AbortSignal.timeout`, an unawaited promise) with a BAD/GOOD pair, and a CRITICAL headline in
  `js-reviewer`. The rule in each: a failure the caller cannot see is worse than a crash, and each
  shape is a finding with the input that reaches it.
- **One severity vocabulary, defined by consequence.** The reviewers all said CRITICAL, HIGH,
  MEDIUM, LOW, but each defined the words for itself, and a reader of the review threads could not
  tell what a MEDIUM from `contract-reviewer` had in common with one from `js-reviewer`. The words
  stay (they are understood in PR threads without a glossary); `docs/AGENT-CONTRACT.md` gains a
  shared table that names each one by what happens if it ships: CRITICAL breaks now under
  realistic use, HIGH breaks under conditions that will occur, MEDIUM ships fine and costs later,
  LOW works today and punishes the next change. The three language reviewers point at it from
  their approval criteria; `security-reviewer` and `contract-reviewer` keep their family-specific
  refinements and say they never contradict the table; `review-verifier` judges OVERSTATED against
  it. A reviewer who cannot name the consequence in one sentence has not earned the word and
  demotes or drops the finding.

## [1.31.0] — 2026-10-29

### Added
- **A routing eval: does a request reach the right agent or skill?** The article this set was
  reviewed against asks to track routing while an orchestrator exists; after six releases that
  added, renamed and folded agents and skills, nothing measured whether their descriptions still
  pull the right requests and not each other's. `eval/routing/cases.yaml` holds 34 golden
  requests in two tiers: 24 plain ones that cover every agent and skill at least once, and 10 hard
  ones where the request names no stack, has two plausible owners, or should stay in the main
  loop with nothing spawned (`expect: none`). Each case carries the expected target, optional
  accepted alternatives for the borderline ones, and one line on why. `eval/routing/catalog.sh`
  prints the catalog the way Claude Code sees it (every name and description), so the eval
  measures the descriptions and nothing else. `test/routing-cases-check.sh` runs in CI for free:
  every target exists, ids are unique, every case is complete. The model run is manual and costs
  tokens: `eval/routing/run-routing-eval.sh` through `claude -p`, or, from a session, one
  general-purpose subagent per case with the catalog and the request (the pattern is in
  CLAUDE.md; nested `claude -p` cannot refresh OAuth). Pass threshold 87% per tier, the article's
  «start with ten golden examples» taken as a floor. First run, 2026-10-29, against the 1.30.0
  descriptions: 34 of 34, one through an accepted alternative (a business explanation routed to
  the `analyst-writer` agent where the `analyst-patterns` skill was the first choice). The hard
  tier at 10 of 10 says the descriptions discriminate even when the request does not name the
  target; the eval now stands as the regression guard to re-run whenever a description changes.

### Fixed
- **`pipeline-init` signals scan: GitLab CI jobs and pip-compile lockfiles.** Found on the first
  run of the skill against a real GitLab project (reported by another session): `ci-job` lines
  came only from GitHub workflow files, so a live `.gitlab-ci.yml` with jobs declared through
  `extends:` and hidden `.templates` produced `ci-job: none`, and the delivery checklist lost
  «CI green» while `devops-engineer` was never named the owner of CI changes; and `lockfile`
  knew `poetry.lock`, `uv.lock` and the npm family but not `requirements*.lock` or a
  `requirements*.txt` carrying `--hash=` lines, so hash-pinned Python projects lost their lockfile
  from the security triggers. Both scripts (`.sh` and `.ps1`, still byte-identical) now list every
  top-level key of a GitLab CI file that is not a reserved keyword and does not start with a dot
  as a job, and treat pip-compile outputs with hashes as lockfiles; the parity test carries a
  synthetic fixture for both.

## [1.30.0] — 2026-10-29

### Added
- **`devops-patterns` — the last builder gets its skill.** `devops-engineer` was the one builder
  still carrying its knowledge inline, in ninety-five lines that could not grow without bloating
  every run. The skill holds it once, in six references: `ci.md` (GitLab CI and GitHub Actions
  shown as equals, GitLab first: DAG stages, caches keyed on the lockfile hash, matrices, minimal
  permissions per job, actions pinned by SHA and images by digest, OIDC instead of long-lived
  keys, fork and `pull_request_target` safety, reusable templates, test splitting, the aggregator
  job; Jenkins in one «what differs» section), `docker.md` (multi-stage builds per stack, digest
  pinning, non-root, layer ordering, `HEALTHCHECK`, PID 1, BuildKit secrets, image scanning),
  `kubernetes.md` (requests and limits, the three probes, PodDisruptionBudget, HPA, ConfigMap vs
  Secret, migrations as a one-runner job, NetworkPolicy, RBAC, Helm chart layout, per-environment
  values, `helm lint`/`template` in CI, `--atomic`), `iac.md` (Terraform remote state with
  locking, modules, a reviewed `plan` as a CI artifact, `moved` blocks, drift, provider pinning;
  Ansible idempotent modules, check mode, vault, inventories, `ansible-lint`), `deploy.md`
  (rolling, blue-green, canary with metric gates, feature flags, expand → deploy → contract with
  `sql-patterns`, a rollback runbook template, post-deploy verification, freeze windows) and
  `observability.md` (structured logs with correlation ids, what never to log, RED/USE, SLOs and
  error budgets, symptom alerts with runbook links, tracing, retention). `devops-engineer` keeps
  its workflow, hard rules and contract, points at the skill the way the other builders do, and
  keeps an «Essentials» list of the rules that must hold even without reading it. Docker,
  Kubernetes and deployment sections are distilled from [affaan-m/ECC](https://github.com/affaan-m/ECC)
  (MIT).

## [1.29.0] — 2026-10-29

### Added
- **`root-cause-investigator` — the stage nobody owned: finding the cause.** `analyst-writer`
  wrote the post-mortem and the builders fixed what they were told to fix, but between a symptom
  and a fix there was no role that reproduced, ranked hypotheses and refuted them. The new agent
  is read-only (Read, Grep, Glob, Bash for running tests, reproduction scripts, `git log`/`diff`/
  `bisect` on a local checkout, and reading logs at the paths the brief names; never a write, a
  commit, an install or anything against production unless the brief names a read-only command).
  Method: reproduce first and state the exact command; localise from the stack or the time window;
  list every hypothesis with the observation that would kill it and its cost; run the cheapest
  check first and keep only what survives; bisect when the window is bigger than one can read and
  a test encodes the symptom; confirm the cause only with a closed chain (input or state, the code
  at `file:line`, the wrong outcome, why the existing guards do not fire), the same bar
  `review-verifier` uses. Three verdicts: CAUSE CONFIRMED, BEST HYPOTHESIS with the experiment
  that would close it, NOT REPRODUCED with everything that was tried; a hypothesis is never
  reported as a cause. The report hands the builder the smallest failing test as text (the fix
  starts red, the first move of a `fix` in the pipeline skeleton), the blast radius with the call
  sites checked, the refuted hypotheses so nobody re-checks them, and every command run.
  `analyst-writer` names it as the source of a post-mortem's timeline and chain; the pipeline
  skeleton gains stage 0, Investigate, in the `fix` masks at `standard` and `large`.

## [1.28.0] — 2026-10-29

### Added
- **`sql-patterns` — the data-store knowledge the builders and reviewers lacked.** A migration
  used to be reviewed only as part of the diff: nobody checked what it locks on a production-sized
  table, whether the index is built inline, whether the backfill sits inside the DDL, or what the
  forward path back is. The skill holds that once: `schema.md` (types, constraints, composite and
  partial indexes, FK indexes, soft delete, multi-tenant filters, with per-engine notes for
  PostgreSQL, MySQL/MariaDB and SQLite), `queries.md` (N+1 and its fix in each ORM, cursor
  pagination over OFFSET, reading EXPLAIN, isolation levels, lock ordering, `SKIP LOCKED` for
  queues, short transactions, replication lag), `migrations.md` (the safety checklist,
  expand-contract renames, adding columns safely per engine version, concurrent index creation,
  removing a column in two deploys, batched backfills, forward-only rollback, immutable deployed
  migrations, per-tool workflows for Alembic, Django, Doctrine Migrations and Laravel), `orm.md`
  (raw-SQL escape hatches of Eloquent, Doctrine, Django ORM and SQLAlchemy and how to keep them
  parameterised, mass assignment, transactions, unit-of-work pitfalls, model-vs-schema drift
  checks) and `nosql.md` (MongoDB document modelling and lazy schema migration, Redis and
  Dragonfly key hygiene, TTLs, correct distributed locks and queues, ClickHouse MergeTree ordering,
  partitions, batch inserts and the cost of mutations and `FINAL`, Elasticsearch/OpenSearch
  immutable mappings, alias-swap reindexing, `search_after`). `php-developer`, `python-developer`,
  `php-reviewer` and `python-reviewer` load it whenever a diff touches a schema, a migration, a
  backfill, a hot query or a NoSQL store; the reviewers name a migration reviewed without the
  checklist as a review gap; `design-reviewer` treats a schema change as the commonest one-way
  door and prices it with `migrations.md`. No `db-reviewer` agent: the skill first, an agent only
  if migration reviews turn out frequent. Migration and PostgreSQL sections are distilled from
  [affaan-m/ECC](https://github.com/affaan-m/ECC) `database-migrations` and `postgres-patterns`
  (MIT).

## [1.27.0] — 2026-10-29

### Added
- **`security-reviewer` — the cross-cutting pass the language reviewers structurally cannot
  make.** `php-reviewer`, `python-reviewer` and `js-reviewer` catch injection and XSS inside
  their language; nobody looked at the access model across a change, trust boundaries, secrets in
  the repository and CI, SSRF through user-supplied URLs, home-made crypto, vulnerable
  dependencies or workflow permissions. The new agent is language-agnostic and read-only, runs only
  when the diff touches a security trigger (the list the pipeline skeleton already carried:
  authentication or authorization, user input and uploads, database queries, file-system paths
  built from input, external calls, cryptography and sessions, secrets and configuration,
  dependency manifests and CI workflows) and otherwise answers APPROVE in one line, because a
  review that invents a security angle is noise. Method: detect the stack and the trust
  boundaries; run the project's own audit tooling if present (`composer audit`, `pip-audit`,
  `npm audit`, `govulncheck`, `cargo audit`, `bundle audit`, `gitleaks`), never installing
  anything and reporting what could not be checked; walk the diff through eight families with
  concrete questions; try to refute every candidate before writing it. A pattern → severity → fix
  catalog (string-built queries, `fetch(userUrl)`, TLS verification off, plaintext or MD5
  passwords, `pull_request_target` with a checkout of the PR head, actions pinned by tag, `*`
  CORS with credentials, raw-HTML sinks, JWT `alg` from the token, balance checks without a
  lock, committed `.env`) and a false-positive list (`.env.example`, marked test credentials,
  public keys, SHA-256 as a checksum, frameworks that escape by default with the version named).
  Every finding needs a reachable input or state, so `review-verifier` can refute or confirm it;
  «could be dangerous» without a path goes to unverified assumptions with the experiment that
  settles it. A leaked secret is also handed to the user with «rotate», because the fix is
  operational. When a language reviewer already ran, it reads those findings first and goes
  beyond them. Stage 8 of the pipeline skeleton and the `Security pass` row of the pipeline
  template now name the agent.

## [1.26.0] — 2026-10-29

### Added
- **The front-end triad: `js-patterns` skill, `js-developer` builder, a slimmer `js-reviewer`.**
  PHP and Python each had a builder, a reviewer and a patterns skill; the front end had only a
  reviewer, and because it had no skill to point at, `js-reviewer` carried its knowledge inline
  and was the largest agent in the set. **`js-patterns`** now holds the idioms once: Vue 3 (SFC
  order, typed props and emits, `defineModel`, composables with cleanup, `ref` vs `reactive`,
  `computed` purity, `watch` sources, `shallowRef` for large data, Pinia setup stores, typed
  routes, Vue 3.5 APIs), Vue 2 differences and migration traps, Nuxt (`useAsyncData`/`useFetch`,
  server routes, runtime config), TypeScript at the boundary (`unknown` over `any`, discriminated
  unions, `satisfies`, guards for API responses), browser code (event delegation,
  `AbortController`, leaks in long-lived SPAs, one request client with surfaced errors, XSS-safe
  rendering), testing (Vitest, Vue Test Utils, MSW, no fixed timeouts) and tooling (ESLint flat
  config, `vue-tsc`, Vite, strict `tsconfig`). Scope is Vue 3, Vue 2, Nuxt, TypeScript and
  framework-free browser code; React and server-side JavaScript are out. The Vue sections are
  distilled from [affaan-m/ECC](https://github.com/affaan-m/ECC) `vue-patterns` (MIT).
  **`js-developer`** mirrors the PHP and Python builders: detects the stack and idiom first
  (Vue major, Options or Composition, Nuxt, TS or JS, linter config) and keeps it, then writes
  typed, tested, linter-clean code under hard rules (every listener, timer, observer, chart or
  socket disposed on unmount; `v-html` only with sanitised input; store state changed only through
  actions; no `async` in `computed`; one request client that surfaces errors), with the agent
  contract: hands the diff and its report to `js-reviewer`, to `contract-reviewer` when a call
  reaches the backend, and blocks on a `Proposed` ADR. **`js-reviewer`** keeps its process (stack
  detection, reading the linter first, confidence filtering, false-positive list, output format,
  contract) and replaces the inline checklist with headlines that point at the skill's references,
  the way `php-reviewer` and `python-reviewer` already did. The builder lists in `architect`,
  `qa-expert`, `docs/AGENT-CONTRACT.md` and the pipeline skeleton name `js-developer`.

## [1.25.0] — 2026-10-29

### Changed
- **The two conversational agents move their knowledge into skills.** A subagent cannot ask a
  question and wait; `analyst-writer` in Analyze mode and `facilitator` building a meeting plan
  both have to, so as subagents they returned questions, the main loop relayed them, and the next
  call started from nothing. The craft now loads into the main loop, where the conversation is.
  **`analyst-patterns`** is a new skill holding what `agents/analyst-writer.md` carried: the three
  modes (Explain with the «объясни нетехническому специалисту» direction, Analyze with the
  proportionality check, Draft-task), the forming-questions method, the read-with-someone-else's-
  eyes final check, the deliverable skeletons and calibration, with the routing to
  `explanation-patterns` and `ru-output-style`. The **`analyst-writer` agent stays, thin**: a
  wrapper that loads the skill, for the runs that need N fresh contexts (N analysts writing N
  task descriptions, a batch of post-mortems); its contract keeps the fan-out rule (every brief
  carries the shared glossary, the format and the decisions taken, because instances cannot see
  each other) and tracker issues are still created only in the main loop after approval.
  **`facilitator` is removed**: its process, level classification, main-question method, client
  roles, lifecycle, interventions and the fixed plan skeleton fold into `facilitation-patterns`
  (`references/plan-building.md`), which already held the rest; a meeting plan is built in
  dialogue, and a fan-out over N meetings does not occur in practice. The installer merges
  manifests and never deletes a file that left the release, so an install of 1.24.0 keeps a stale
  `agents/facilitator.md`: remove it once with `./install.sh --uninstall --agent facilitator`
  (or `.\install.ps1 -Uninstall -Agent facilitator`), then reinstall. Precedent: the `critic` →
  `design-reviewer` rename in 1.21.0 shipped as a minor release the same way.

## [1.24.0] — 2026-10-29

### Added
- **`address-review` — the author's side of the review loop.** The reviewers produced findings
  and `review-verifier` kept the ones that survived, but nothing consumed that list in a fixed
  form: fixes happened «somehow» and the reviewer learned of them by re-reading the diff. The
  skill (in the main loop, with the conversation that produced the code) takes the «Publish
  these» list, or a reviewer's raw output marked `unverified`, and answers every finding with one
  of four statuses: `addressed` (with the test or check that shows it), `declined` (only with a
  reason that cites code or a recorded decision; a decline without one becomes `clarifying`),
  `clarifying` (one question and the status each answer leads to), `skipped` (right fix, wrong
  change: the blast-radius guard refuses fixes that touch files outside the diff, rewrite more
  than a third of a file, change a public contract or need a design decision, and names the
  follow-up). Fixes are the smallest change inside the diff's scope; the project's lint and tests
  run on the touched files, and a fix that breaks a test is reverted and sent back as
  `clarifying`. In `guided` and `autonomous` mode it commits the fix-ups (one per finding when two
  or more CRITICAL/HIGH were addressed), in `propose` it stops with the diff and the commit text;
  push, PR update and thread replies stay with the orchestrator at Gate 2, and the re-review of
  the fix-up diff is the orchestrator's call, the skill only says «ready for re-review». Output:
  a per-finding table the orchestrator acts on (`references/statuses.md`) and reply drafts for
  the PR threads in the review's language (`references/replies.md`). `review-verifier`'s handoff
  now names the skill as its consumer.

### Fixed
- `skills/pipeline-init/hooks/session-start.sh` carries its exec bit (shipped without it in 1.23.0;
  the hook is invoked through `bash`, so behaviour was unaffected).

## [1.23.0] — 2026-10-29

### Added
- **`pipeline-init` — the pipeline written down once, at the level of the project.** Without a
  harness the results were worse and every session had to be told by hand which agents were needed
  and where. The skill (a skill, not an agent: it asks and waits, which a subagent cannot) reads the
  project — `.claude-docs/architecture.md` when `/onboard-memory` has written one, otherwise the
  manifests — and runs a signals scan (`scripts/pipeline-signals.sh`, with a byte-identical
  `.ps1` for Windows: stack, CI jobs, CODEOWNERS and PR template, migration directories, API
  schemas, files calling external services, test layout, tracker prefixes); asks at most four
  questions (typical operations, one-way doors, autonomy mode, reader and language); shows a card
  including the agents the masks name but this stack does not use; and after an explicit yes
  writes `docs/PIPELINE.md` in the user's language plus a block of at most eight lines in the
  project's `CLAUDE.md`, which every later session loads. The skeleton is universal and lives in
  `references/stages.md`: twelve stages with owners, default masks by operation × size (trivial,
  small, standard, large), two gates (after Clarify and Design, before Deliver), three autonomy
  modes (`propose`, `guided`, `autonomous`), the security-trigger list, how `NEEDS_INPUT` /
  `BLOCKED` / `OUT_OF_SCOPE` stop or reroute a run, and the delivery checklist. The filled copy is
  the project's. On a repository that already has `docs/PIPELINE.md` the skill diffs the signals
  against the recorded ones and patches, never overwrites. An optional SessionStart hook
  (`hooks/session-start.sh` and `.ps1`, not installed automatically) prints one line when a
  repository has code but no pipeline file. `test/pipeline-signals-parity.sh` (CI, pwsh 7) proves
  the two scans agree.

## [1.22.1] — 2026-10-29

### Added
- **`test/agent-lint.sh` — the contract from 1.22.0 is now enforced, not just documented.**
  For every `agents/*.md`: frontmatter present with `name` equal to the filename, a non-empty
  `description`, `model` in `opus|sonnet|haiku|inherit`, `tools` (when present) a JSON-style
  list; exactly one of each `## Input`, `## Output`, `## Handoff`, `## Fragile points` outside
  fenced code; the `### Terminal states` block byte-identical to the one in
  `docs/AGENT-CONTRACT.md`; no CR line endings. For every `skills/*/SKILL.md`: frontmatter,
  `name` equal to the directory, non-empty `description`. POSIX awk/grep/cmp only, so it runs on
  the macOS job too. Wired into the `static-bash` CI job and listed in CLAUDE.md. Resolves
  BL-011 (a typo'd `name:` used to ship silently and fail only in the user's session).

## [1.22.0] — 2026-10-29

### Added
- **An agent contract: every agent ends with `## Input`, `## Output`, `## Handoff`,
  `## Fragile points`, and shares three terminal states.** Until now the chain between agents
  lived in README prose and in file paths (`docs/qa/COVERAGE-MATRIX.md` handed e2e gaps from
  `qa-expert` to `test-automator`); the builders were referenced by no other agent and their
  report had no shape a reviewer could rely on. A subagent sees nothing of the conversation that
  produced its task, so each agent now states what the brief must carry that it cannot read from
  the repository (the decided scope, what is out of scope, the reader, the output language), what
  it reads but never modifies, what it delivers and in which order the report comes, who consumes
  the result and what they assume (every reviewer finding carries severity, `file:line`, claim and
  failure scenario because `review-verifier` marks anything less `UNPROVEN`), and where it is
  known to break. When an agent cannot deliver, it ends with exactly one of `NEEDS_INPUT` (a fact
  only the requester has would change the result; questions follow, each with the result it
  leads to), `BLOCKED` (a precondition outside the brief is unmet, named) or `OUT_OF_SCOPE` (not
  this agent's job, the owner named) on the first line, so the main loop routes on the state
  instead of parsing prose. A builder whose brief only restates a ticket ends with `NEEDS_INPUT`
  rather than guessing the deliverables. The spec, the shared block and the chain table are in
  [docs/AGENT-CONTRACT.md](docs/AGENT-CONTRACT.md); README gains «How agents chain».
  `architect`'s ADR skeleton heading becomes `## Output — ADR skeleton`, `facilitator`'s
  `## Hand off` becomes `## Handoff`; the builders', `devops-engineer`'s and `test-automator`'s
  `## When Reporting Done` sections fold into `## Output`.

## [1.21.0] — 2026-09-15

### Changed
- **`critic` is now `design-reviewer`, and reviews three kinds of input.** The name joins the
  reviewer family (`contract-reviewer`, `php-reviewer`, `js-reviewer`, `review-verifier`) and says
  what is reviewed, which a bare «critic» in the agent table did not. With the wider name come two
  inputs the six-family method fits without change: **the approach behind a PR or diff before
  merge** (the language reviewers check whether the code is correct, this pass checks whether the
  code is in the right place, what it couples and what it makes hard to undo; a PR that does not
  say why this approach over the obvious alternative is itself a finding), and **an existing ADR
  revisited against the current code** (do the assumptions it rested on still hold; the verdict is
  about the decision, never a proposal to replace it). The agent says explicitly what it is not:
  UI/UX design, mockups, visual and interaction design — «design» here is software architecture and
  technical decisions — and a sweep of the whole architecture, which stays with `architect`. The
  installer merges manifests and never deletes a file that left the release, so an install of
  1.20.0 keeps a stale `agents/critic.md` next to the new one: remove it once with
  `./install.sh --uninstall --agent critic` (or `.\install.ps1 -Uninstall -Agent critic`),
  then reinstall.

## [1.20.0] — 2026-09-15

### Added
- **`critic` — the pass a design gets while changing it is still cheap.** The set could design
  (`architect`), review code (`php-reviewer`, `python-reviewer`, `js-reviewer`,
  `contract-reviewer`) and verify findings (`review-verifier`), but nothing pressure-tested a
  decision in the window between «drafted» and «cemented into an issue». The author cannot run that
  pass on themselves: by the time a design is written down, its assumptions have stopped looking
  like assumptions. `critic` arrives cold, hunts six families of load-bearing weakness (unstated
  assumptions, failure modes, unconsidered alternatives, internal contradictions, irreversibility,
  standing operational cost), grounds each one in the actual repository rather than in the
  document's own claims, and calibrates rigor to reversibility. It does not redesign and does not
  write files: a critique that ends in a full alternative architecture is a second draft, not a
  review. Every finding must be falsifiable — a concrete state, input or sequence — because a wrong
  blocker costs a redesign that was not needed and, repeated, the author's willingness to run the
  pass at all. The agent states what it takes as input (a design in a file, an ADR, an issue or
  pasted text, plus the documents it references), speaks the severity vocabulary the reviewers
  and `review-verifier` already share (CRITICAL / HIGH / MEDIUM), and marks each finding by what
  settles it: a finding grounded in the repository (a mechanism claimed to exist, a contradiction
  with a recorded decision or a live convention) is the kind `review-verifier` can refute against
  code, while a finding about the design itself (an assumption about future load, an alternative
  never compared) has no code to check and goes to the author as a question. The verdict is
  written in the request's language; a Russian verdict routes to `explanation-patterns` for the
  shape and `ru-output-style` for the wording. Contributed by Peter Gribanov (#4).

## [1.19.0] — 2026-09-15

### Added
- **A proposal whose need shows itself in no scenario anyone can write is a proposal
  without an established need.** `explanation-patterns` gains a violation sign for
  «Потребность, Решение, Результат»: when the concrete scenario in which the need shows
  itself — who runs into it, when, what exactly they see — does not write itself, the third
  beat gets invented, and an invented beat reads as a promise. The cure is to report the
  missing scenario as missing and flag proportionality, never to fill the gap with
  something plausible. The rule sits in `SKILL.md` too (the «does not fit» column and a
  new step in «Check before delivering»), so every loader of the skill runs it, not only
  the reader of `references/frameworks.md`. `analyst-writer` runs the check in Analyze
  mode before it elaborates the solution, with three outcomes kept apart: the material
  gives the scenario (proceed); the material is silent, as compliance, contractual and
  tech-debt tasks usually are (the missing scenario becomes the first blocking question,
  the breakdown continues as conditional on the answer); the scenario cannot be written
  even in principle (the need is not established, the solution is not elaborated). So a
  task nobody needs is caught before the completeness checklist makes it look thorough,
  and a mandated task without a story in the ticket is not mistaken for one.
  Contributed by Peter Gribanov (#3).

## [1.18.1] — 2026-09-11

### Fixed
- **Pattern 52 tested the wrong thing.** As shipped in 1.18.0 it asked where the metaphor
  came from — «допустима, если так уже называют вещь в команде» — which would condemn a
  coined name for a phenomenon the research itself discovered, while leaving a
  team-blessed metaphor over something already sayable untouched. Provenance is the wrong
  axis. The test is whether the thing already had a name: renaming what an accepted term
  or a plain verb phrase already says is a second layer and comes off; naming a phenomenon
  that had no name saves the reader a paragraph every time it comes up, and is legal under
  four conditions — one per document, introduced explicitly, obvious on first reading, and
  used without variation afterwards (pattern 15). This mirrors pattern 51, which turns on
  the same question. `analyst-writer` and the skill section carry the corrected test.


## [1.18.0] — 2026-09-11

Six complaints from a non-technical reader on a real report, plus the first full
consistency review of the catalogue.

### Fixed
- **The rules were making the analyst invent words.** «No jargon in the business layer»
  and «explain through observable behaviour» had no escape hatch saying which replacement
  is legal, so an accepted term got swapped for a home-made one: a folksy coinage instead
  of a standard name, with the standard name demoted to a parenthesis in the glossary.
  That is worse than the jargon it replaced — an invented word exists only in that
  document, cannot be looked up and cannot be said to a developer. The term list step in
  `analyst-writer` now says which of the three fates applies to what: an **accepted term
  for a part of the system** keeps its name and gets a gloss; a **name of a procedure the
  author performed** goes to the appendix whole; only an **internal identifier with no
  accepted name** is replaced by a description. Inventing a substitute is never an option.
- **`ru-output-style/SKILL.md` claimed two different catalogue sizes.** The description
  said 50, the routing table still said 47 — stale since 1.17.0. Both now 52, and the
  README row with them.
- **Catalogue integrity, found by checking it programmatically rather than by reading.**
  Number **24 was never defined** (a hole inherited from the original distillation, while
  the header claimed a round count), and **27 was listed in two families at once**. The
  hole is now filled by a real pattern and the family headers are disjoint: every number
  1-52 is defined exactly once and belongs to exactly one family.

### Added
- **Patterns 24, 51, 52.** **24** разговорная замена принятому слову («Чем платим» where a
  table column already says «Риски и плата» — one thing named twice in two voices, and
  first person plural in a heading leaves the reader unsure whether these are their risks
  or the team's promises). **51** придуманный термин вместо принятого, with the tell: a
  glossary where the coinage leads and the real term sits in brackets. **52** метафора как
  имя механизма — steps of one algorithm named from four different metaphor families make
  the reader carry a private zoo and translate back before every conversation with
  engineering; one metaphor per document, and only for something the team already calls
  that.
- **`references/patterns.md`: «Разборы пограничных случаев».** The consistency review
  found seven pairs of rules that look contradictory at a glance, and each is now ruled on
  once with the axis they actually measure: 41 against the «зачем так сделано» beat
  (does the sentence add a fact or only a denial), 27 against the short-sentence rhythm
  rule (a run of fragments against one short sentence among long ones), 14 against the
  enumeration ceiling (empty words against too many), 5 against 51 (does the thing have an
  accepted name), «procedure jargon to the appendix» against 51 (name of a procedure
  against name of a part), 8 against 45 (is there a fact in the tail worth saving), and 40
  against the new one-content-once ceiling.
- **`explanation-patterns`: a shape for a decision somebody else makes.** The most common
  failure of a «что решить продукту» block is a list of situations: the author describes
  what is unclear and stops, and a described situation is not a decidable question. Six
  beats, all load-bearing, the one most often missing being «do nothing» as an explicit
  option with its own price. The giveaway that the shape is broken: the item ends on a
  description of the mess or on «we do not know».
- **`explanation-patterns`: ceiling «one content, once».** A table followed by the same
  items retold as paragraphs makes the reader work through it twice with no way to tell
  repeat from new material. Choose by whether the reader needs to compare along columns.
- **`lint-ru.sh`: a stub check for pattern 24** on the observed phrasings only. Patterns
  51 and 52 are read-checked, not machine-checked, and the pattern text says so.


## [1.17.1] — 2026-09-11

Four fixes found by running v1.17.0 against a real analytical report: the
deterministic half of the linter plus the reader pass the skill itself prescribes,
carried out by a fresh agent that had not seen the research.

### Fixed
- **Pattern 48 was 30% useful on a real document.** Nine hits, of which six were
  legitimate: four reported a limit of the author's own research («в промпте это не
  проверялось») - which `diagnosis.md` explicitly asks for - and one sat in a paragraph
  that already named the condition. An unguarded check that is wrong two thirds of the
  time teaches the author to ignore every warning, which is how the original 21
  rule-of-three false positives worked. The check now skips a line that carries the cure
  («право, пока», «работает, пока», «Проблема в том, что») or a research-limit marker
  («в исследовании», «для продукта», «в промпте», «не мерилось»). On the same report:
  9 hits down to 4, of which 2 are actionable. The pattern text now states both
  legitimate uses and says the warning is to be read, not obeyed blindly.
- **Pattern 41 missed its most common real form.** Its markers were «может возразить» and
  «вопреки распространённому», but what a reader actually stumbles on is a short «Это не
  X.» negating a hypothesis the text never raised: «Признаки считаются один раз и позже
  не пересчитываются. Это не гонка по времени.» The reader had not been thinking about a
  race and goes back to look for where it was mentioned. Now matched as a complete short
  sentence — marker to the next period with no comma between — so «Это не так, потому
  что...» stays quiet.
- **Pattern 41 and the number ceiling are now paragraph-scoped, not line-scoped.** A
  wrapped Markdown paragraph was hiding a marker that straddled a line break. Both flush
  on a blank line in Markdown and per line in HTML, where one stripped line is already one
  `<p>`.
- **Pattern 46 checked placement and claimed sufficiency.** A term glossed only in a
  `title` tooltip passes the first-use check while the paragraph text still does not
  define it — and nobody reading a printout or a PDF export sees a tooltip. The pattern,
  the skill section and the `analyst-writer` HTML contract now say a tooltip adds to the
  text rather than replacing it: the detail goes in the tooltip, what the paragraph cannot
  be read without goes in the text.

### Added
- **`explanation-patterns/references/diagnosis.md`: two section-scoped check questions**
  that produced the heaviest findings on the real report and that nothing automatic
  catches. Is it one sample throughout the section, and are switches between samples
  marked — two data sets side by side without a marker read as a typo and the reader
  starts reconciling numbers. And is one number sitting under two different claims —
  «подходят хотя бы к одному ключу» and «проходят внутрь» carrying the same share are
  different events.
- **Invented figures re-checked against the source by the recipe from `CLAUDE.md`.** The
  number intersection caught two of my own examples reusing real values, one added in this
  patch and one shipped in 1.17.0 (a decimal that also appears in the source table).
  Eyeballing would have passed both again.
- **Fixtures extended**: `warn-shape.md` gains the «Это не X» case, `clean-shape.md` gains
  the two pattern-48 exemptions plus «Это не так, потому что...» as negative controls.


## [1.17.0] — 2026-09-11

### Added
- **`explanation-patterns` skill — the shape of an explanation, as a separate axis from
  wording.** `ru-output-style` answers «does this read as AI» and, since 1.16.0, «can the
  reader parse this word». Neither catches a document that passes every local check and
  still exhausts the reader: mechanism reported without consequence, a defect stated as
  an absence, method before result. Those are shape defects, and sentence-level editing
  does not repair them. The skill picks a shape **by scale and genre**, each row carrying
  its own «does not fit»: Minto pyramid with SCQA and MECE for a whole document,
  Context-Action-Result for a narrative of your own work (explicitly *not* for explaining
  someone else's mechanism), Need-Solution-Result for a proposal, What/So-what/Now-what
  for a paragraph, mechanism plus failure condition for a defect, and share-base-
  comparison-consequence for a number. Language-agnostic; `references/frameworks.md`
  carries origin, indications and contraindications with a worked before/after per shape,
  `references/diagnosis.md` covers the genre that fails most often — explaining a broken
  mechanism, plus an absence-to-condition substitution table and the separate shape for an
  incident chronicle (trigger apart from cause).
  - **The rule that outranks the rest: the shape stays invisible.** No heading named after
    a beat («Проблема», «Результат», «Контекст»), no connective announcing one («итак, что
    это значит»), no fixed beat count per section. A framework applied visibly produces
    exactly the formulaic register `ru-output-style` bans, so the catalog ships with the
    ban that keeps it from becoming a template.
  - **Density ceilings**, because the local rules only had minimums: one «доля (N из M)»
    construction per paragraph, enumerations no longer than four homogeneous items,
    business-layer sentences under about 25 words. And **frame sentences are declared
    legal** — «само по себе это правильно», «проблема в том, что» carry no fact and carry
    the reader; a one-fact-per-sentence budget must not squeeze them out.
- **`ru-output-style`: patterns 48-50.** **48** дефект описан отсутствием («правило не
  проверяет похожесть» gives the reader a hole; «правило право, пока первая копия легла
  верно» gives them a condition to reason with — and a check that genuinely was not run is
  a limit of the research, not a property of the system); **49** оценка без порога («а трёх
  мало» with no number to compare against); **50** сырой внутренний идентификатор в прозе.
  Family «Понятность для читателя» is now 46-50.
- **`ru-output-style`: gold genre «объяснение механизма, который сломался»** — the
  three-beat shape as an imitable paragraph, with the note on why each beat is there.
- **`lint-ru.sh`: six new checks.** Patterns 48, 49 and 50, plus the ceilings and the
  framework-named heading. The number ceiling is accumulated **per paragraph** (flushed on
  a blank line in Markdown, per line in HTML where one stripped line is already one
  `<p>`), so a wrapped Markdown paragraph is judged as a paragraph.
- **`test/lint-ru-test.sh`: fixtures `warn-shape.md` and `clean-shape.md`** — the second is
  a negative control that locks in the cures (condition instead of absence, threshold
  given, id glossed, one share per paragraph, four-item enumeration, content-named
  heading). 15 fixtures total.

### Changed
- **`analyst-writer` routes to both skills instead of restating their rules.** A `Skills`
  table names what each one owns and when to read it; the comprehension mechanics and the
  structural craft now live in the skills, and what the agent keeps is what only it can
  do — naming the reader, the modes, the deliverable, tracker discipline, and the refusal
  to hand over text the reader cannot parse. The duplicated skill-location paragraph and
  the second copy of the final check are gone. The file did not shrink (239 lines against
  238), but the growth went into routing rather than into more rules, and the new craft
  went into a skill that five agents can read.
- **`analyst-writer`: «one fact per sentence» no longer outlaws frame sentences.** As
  written in 1.16.0 the rule squeezed out exactly the sentences that make facts land.
- **`analyst-writer`: the pre-delivery pass is one checklist**, with the headings-alone
  read, the per-paragraph «и что», the failure-condition check and fact integrity folded
  in.
- **`CLAUDE.md`: the no-real-material MUST NOT now carries a verification recipe.**
  Eyeballing the examples in this very release missed lifted figures and a capitalised
  domain term; the recipe is to intersect every number in the changed files with every
  number in the source material and to spell both cases out in term scans, because
  `grep -i` does not fold Cyrillic case in Git Bash here and silently misses anything
  capitalised.
- **`data-analyst` and `facilitator` route to `explanation-patterns` too**, and their
  stale references to the skill's «two-question final check» are corrected to three (it
  became three in 1.16.0 and these two were missed).


## [1.16.1] — 2026-09-10

### Fixed
- **The pattern-46 check could never fire on a real `analyst-writer` deliverable.**
  `lint-ru.sh` finds glossed terms by the exact markup `<a class="term" title="...">`,
  but nothing told the agent to emit it, so it would pick its own tooltip mechanism
  (`<abbr>`, `<span data-tip>`, footnotes) and the first-use check would stay silent on
  every term — a clean run proving nothing. The agent's Interactive HTML spec now fixes
  the markup (`<a class="term" href="#g-<slug>" title="...">` plus a glossary anchor and
  the hint styling), and both the agent's pre-delivery step and the skill's linter section
  say that any other mechanism disables the check.


## [1.16.0] — 2026-09-10

### Added
- **`ru-output-style`: patterns 43-47 and a second axis — reader comprehension.** The
  skill used to answer one question, «does this read as AI». Feedback from a
  non-technical reader on a long analytical report showed the other half: text can be
  free of every slop marker and still be unparseable, because the author owns the terms
  and the reader meets them for the first time. New patterns: **43** обобщающий
  довесок (a closing clause with no number and nothing to check, «а дальше все
  варианты ложатся на одну кривую компромисса»); **44** процесс как субъект
  («замер дал порог», «разбор восстановил механизм»); **45** деепричастие на
  стыке двух фактов, with a hard ban on gerund forms the paradigm allows and
  living Russian never says («платя», «пиша», «жгя», «могя», «бежа», «лгя»,
  «ткя», «пья», «лья», «бья»); **46** термин без раскрытия при первом
  употреблении, plus the opposite-pair sub-case («целевые и посторонние» defined
  when introduced); **47** метод впереди результата. New family «Понятность для
  читателя», new `SKILL.md` section with the first-use rule, one-wording rule,
  base-with-percentage rule and layered vocabulary, and a **third mandatory final-check
  question**: can a reader who did not take part in the work parse this without opening
  another section.
- **`ru-output-style`: gold genre «вердикт исследования для продакта»** in
  `references/gold.md` — the genre where comprehension breaks most often. The worked
  example and every figure in it are invented; the toy domain is duplicate records in a
  delivery-address directory.
- **`lint-ru.sh`: HTML first-use gloss check (pattern 46).** For every term glossed with
  `<a class="term" title="...">`, the first bare occurrence in the prose must not precede
  the glossed one; the warning reports both line numbers. The file is now read twice
  (pass 1 collects the glossed terms, pass 2 reports). This is the check that catches a
  tooltip hung on the second occurrence while the reader stumbles on the first.
- **`lint-ru.sh`: deterministic rules for patterns 43-45 and 47** — one hard ban
  (unusable gerund forms, matched with word boundaries against a punctuation-normalised
  copy of the line, so «бежать» and «платяной» do not fire) and four warnings.
- **`analyst-writer`: «объясни нетехническому специалисту» direction inside Explain** —
  build the term list before writing (gloss, plain replacement, or appendix; nothing left
  unhandled), explain mechanism through observable behaviour, give internal metrics a
  scale, one analogy per document and only after the fact, no procedure or formula names
  outside the appendix, readiness check by retelling.
- **`analyst-writer`: read-with-someone-else's-eyes pass** as a separate pre-delivery step,
  including running the linter on an HTML deliverable to verify tooltip placement.
- **`test/lint-ru-test.sh`: `NOT <substring>` directive** — negative controls, the only way
  to prove a check stays silent where it should. Four new fixtures
  (`ban-deeprichastie.md`, `clean-lookalikes.md`, `warn-newpatterns.md`,
  `html-firstuse.html`), 13 total.

### Changed
- **`analyst-writer`: comprehension mechanics given teeth.** «No unglossed jargon» was
  already in the agent and still failed in practice, so it now names the mechanism: the
  gloss hangs on the first occurrence and a trailing glossary does not replace it; a term
  keeps one wording; opposite pairs are defined at introduction; a percentage carries its
  base; the verdict runs one fact per sentence; procedure jargon lives in the appendix.
- **`lint-ru.sh`: rule-of-three heuristic no longer fires on lines carrying digits.** An
  enumeration with model names, thresholds or ids is a fact list, not a rhythmic crutch.
  On one long real report the check produced 21 hits, every sampled one false, which
  taught the author to ignore every warning; the same report now yields 2.
- **`references/patterns.md`: em dashes normalised to «-»** (58 occurrences). The catalog
  that hard-bans the long dash was using it throughout; the one remaining «—» is the
  character named in the formatting rule.
- **All examples in this release use invented domains and invented figures.** Every
  pattern, gold example and linter fixture is written on a toy case, never on real work
  material — see the MUST NOT in `CLAUDE.md`.

## [1.15.0] — 2026-08-27

### Added
- **`qa-expert` agent** — QA strategist and test-coverage auditor (docs only, never
  code). Three modes: (1) **strategy** at project/feature start — risk analysis, test-level
  assignment (unit/integration/e2e) with rationale, testability check of acceptance
  criteria, owners and exit criteria → `docs/qa/TEST-STRATEGY.md`; (2) **PR audit** —
  behavioral coverage of the changed code, assertion quality, edge/error paths, flaky
  patterns, gaps rated critical/important/nice-to-have; (3) **project audit** (designed
  for scheduling) — coverage actuality: dead/skipped/`fixme` tests, suites stale vs
  current functionality, coverage-tool runs, matrix refresh. Persists a fixed-skeleton
  feature × level coverage matrix with stable `QA-NNN` ids to `docs/qa/COVERAGE-MATRIX.md`
  (same id/retire discipline as backlog-planner) — the diff between runs IS the actuality
  check. Hands unit gaps to developers, e2e gaps to `test-automator`, environment
  blockers to `devops-engineer`.
- **`test-automator` agent** — Playwright E2E builder. Recons the existing test setup
  first (never builds a parallel suite), bootstraps missing toolchain itself
  (`@playwright/test`, browsers, config with house defaults), writes stable tests (POM,
  fixtures, `data-testid`/role locators, auto-waiting API only, `waitForTimeout` banned),
  stabilizes before declaring done (`--repeat-each` protocol, trace-driven diagnosis,
  quarantine only with an issue reference), and maintains the environment-requirements
  spec for devops at `docs/qa/ENVIRONMENT.md` (fixed skeleton: runtime, browsers/OS deps,
  test data & auth, secret names, CI execution, blockers). Destructive/financial flows
  guarded from production; honest reporting of real run results only.
- **`playwright-patterns` skill** — thin `SKILL.md` (7 core principles + quick-reference
  table) routing to `references/`: `pom.md` (layout, Page Object Model, fixtures,
  storageState auth, test data), `config.md` (baseline config with pinned
  locale/timezone/viewport, decision notes, bootstrap commands), `flaky.md`
  (identify/diagnose/cure by cause, quarantine rules), `ci-artifacts.md` (GitHub
  Actions + GitLab CI, sharding, traces, report template), `critical-flows.md`
  (financial/destructive guards, preview-then-confirm asserts, EIP-1193 wallet mocking).
  Distilled and extended from the `examples/qa/` drafts (qa-expert, test-automator,
  playwright-pro, e2e-runner, pr-test-analyzer, e2e-testing skill).

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
