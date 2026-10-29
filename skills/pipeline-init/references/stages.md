# The stage skeleton

The universal part of every pipeline is the order of stages and who owns each one. The
project-specific part is which stages are mandatory for which operation, where artifacts live,
and when to stop and ask. `pipeline-init` fills the second part; this file is the first.

## Stages, in order

| # | Stage | Owner | Input | Output | Mandatory when |
|---|---|---|---|---|---|
| 1 | Clarify | main loop (with `analyst-writer` skill, or the agent for a fan-out) | ticket, conversation | expanded requirements: deliverables, out of scope, decisions taken, open questions | always; open questions stop the pipeline here |
| 2 | Design | `architect` | requirements, repository | ADR or a short answer | a one-way door: data model, persistence engine, public API contract, service boundary, auth model |
| 3 | Pressure-test | `design-reviewer` | the design, or the approach in a diff, or an old ADR | falsifiable findings, open questions | same one-way doors; any decision expensive to reverse |
| 4 | Test strategy | `qa-expert` mode 1 | requirements, acceptance criteria | `docs/qa/TEST-STRATEGY.md`, matrix rows | a feature with more than one test level, or acceptance criteria that look untestable |
| 5 | Implement | language builder (`php-developer`, `python-developer`) or the main loop with the pattern skill | expanded requirements, Accepted ADR, test strategy | diff plus the report (what changed, which tests prove it, what ran) | always |
| 6 | Code review | `php-reviewer`, `python-reviewer`, `js-reviewer` | diff plus description or builder report | findings with severity, `file:line`, claim, scenario | always, matched to the stack |
| 7 | Contract review | `contract-reviewer` | diff plus the callee's code | four gates per crossing call | the diff changes a call that leaves the module: service, SDK, HTTP/RPC, queue |
| 8 | Security review | security pass (a dedicated agent when installed, otherwise the language reviewer's security checklist) | diff | findings | the diff touches a security trigger (below) |
| 9 | Verify findings | `review-verifier` | all findings, revision | CONFIRMED / OVERSTATED to publish, UNPROVEN as questions, REFUTED as retractions | findings go to an author or a PR |
| 10 | Address review | main loop (`address-review` skill when installed) | confirmed findings | per-finding status, fix-up diff | confirmed findings exist |
| 11 | Coverage | `qa-expert` mode 2, `test-automator` | diff, matrix | matrix diff, e2e specs | rigor `standard` and above |
| 12 | Deliver | main loop, `devops-engineer` for CI or infra | green diff | PR or release; CI change | per project |

## Operation × size → stages

Two axes decide the stage mask. The **operation** says what kind of change it is; the **size** says
how much ceremony it earns. Take the highest size any signal reaches.

Operations: `feature` (capability does not exist), `change` (works, should behave differently),
`fix` (broken), `refactor` (behaviour stays, structure improves), `greenfield` (a new service or
module from a spec), `research` (no code change expected).

| Size | Files touched | New dependency or contract | Design ambiguity |
|---|---|---|---|
| trivial | 1, a few lines | none | none |
| small | 1 file or 1 function | none | clear once the code is read |
| standard | 2–5 files | maybe an internal module | one real choice |
| large | many or cross-cutting | external dependency, public API, schema, or a spec | several open questions |

Tie-breaker: anything touching a security trigger or a public contract is at least `standard`.

Default masks (the project file overrides them):

| Operation | trivial | small | standard | large |
|---|---|---|---|---|
| feature | 5 6 9 12 | 1 5 6 9 12 | 1 2 5 6 7 9 11 12 | 1 2 3 4 5 6 7 8 9 10 11 12 |
| change | 5 6 12 | 1 5 6 9 12 | 1 5 6 7 9 11 12 | 1 2 3 5 6 7 8 9 10 11 12 |
| fix | 5 6 12 | 5 6 9 12 (first move: a failing test that reproduces the bug) | 1 5 6 9 11 12 | 1 3 5 6 7 8 9 10 11 12 |
| refactor | 5 6 12 | 5 6 12 | 3 5 6 9 12 | 2 3 5 6 7 9 11 12 |
| greenfield | — | — | 1 2 3 4 5 6 7 9 11 12 | 1 2 3 4 5 6 7 8 9 10 11 12 |
| research | 1 | 1 | 1 2 | 1 2 3 |

Stage 7 runs only if a crossing call is in the diff, stage 8 only if a trigger is touched, even
when the mask lists them: the mask says "check", the trigger says "run".

## The two gates

The pipeline stops and shows its state at two points, whatever the autonomy mode:

- **Gate 1, after Clarify (and Design when it runs).** The expanded requirements, the ADR if
  any, the stage mask chosen with the size tier stated in one line, and the active agent set
  (named: who will be spawned, who is named by the mask but not spawned at this size). Nothing
  is implemented before this is shown.
- **Gate 2, before Deliver.** The diff summary, the review verdicts, the open questions from
  `review-verifier`, and the delivery checklist (below). Nothing is pushed, merged or released
  before this is shown.

Between the gates the pipeline runs without stopping, except on a terminal state from an agent.

## Autonomy modes

| Mode | Gate 1 | Gate 2 | Everything else |
|---|---|---|---|
| `propose` | wait for approval | wait for approval | each stage transition is announced and waits |
| `guided` | wait for approval | wait for approval | stages run without stopping; a `NEEDS_INPUT` or `BLOCKED` from an agent stops and asks |
| `autonomous` | announce and continue | wait for approval | stages run; terminal states are logged and the pipeline continues with what it can; the final report lists every skipped stage |

Start a project in `propose`. Move up after a few tasks ran without manual correction.

## Security triggers

Run the security stage when the diff touches any of: authentication or authorization; handling
of user input or file uploads; database queries or query builders; file-system paths built from
input; calls to external APIs; cryptography, tokens, sessions; secrets, credentials, environment
configuration; dependency manifests or lockfiles.

## Terminal states inside a pipeline

Every agent ends with a result or with one of `NEEDS_INPUT`, `BLOCKED`, `OUT_OF_SCOPE` on its first
line (see `docs/AGENT-CONTRACT.md` in claude-dev-agents). The pipeline rule:

- `NEEDS_INPUT` stops the pipeline at that stage. The questions go to the user as is, with the
  result each answer leads to. After the answer the stage is re-run with the full brief. A second
  `NEEDS_INPUT` from the same stage on the same task means that stage belongs in the main loop,
  with the conversation.
- `BLOCKED` stops the pipeline and names what is missing. In `autonomous` mode the pipeline may
  continue with the stages that do not depend on the blocked one, and the final report lists it.
- `OUT_OF_SCOPE` reroutes to the agent or skill the state names; it is not a failure.

A state is shown to the user verbatim, never folded into a summary.

## Delivery checklist

Checked at Gate 2, each line answered yes, no, or skipped-because:

- Every stage in the mask ran, or the report says which did not and why.
- Review findings: CRITICAL and HIGH are closed or explicitly accepted by the user.
- The diff stayed inside the declared scope; any excess is named and was authorised.
- Tests prove the changed behaviour, not only that a command ran.
- Artifacts the project requires exist (ADR, matrix rows, environment spec) and are current.
- Rollback or revert path stated for anything deployed or migrated.
- Documentation that names the changed behaviour was updated or listed as drift.

## Artifacts and where they live (defaults)

| Artifact | Path | Owner |
|---|---|---|
| Pipeline | `docs/PIPELINE.md` | `pipeline-init` |
| ADRs | `docs/adr/NNNN-<slug>.md` | `architect` |
| Test strategy and matrix | `docs/qa/TEST-STRATEGY.md`, `docs/qa/COVERAGE-MATRIX.md` | `qa-expert` |
| Environment spec | `docs/qa/ENVIRONMENT.md` | `test-automator` |
| Backlog | `docs/backlog/BACKLOG.md` | `backlog-planner` |

A project that keeps these elsewhere says so in `docs/PIPELINE.md`; agents read the pipeline file
before their defaults.
