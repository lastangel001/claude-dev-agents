# Agent contract

Every agent in `agents/` ends with four fixed sections and shares one vocabulary of terminal
states. The contract is what lets agents chain without the main loop re-explaining each link:
a builder knows what a reviewer will read, a reviewer knows what `review-verifier` requires, and
the main loop can route on a state instead of parsing prose.

The headings are literal, so a lint can check them. The contents are specific to the
agent: no generic filler, every line something the caller or the next link can act on.

## The four sections

### `## Input`

What must be true before the agent can work:

- **In the brief.** The facts the agent cannot discover from the repository: what was decided,
  what is out of scope, who reads the result, the language of the output. If a brief is missing one
  of them and the agent cannot proceed without it, the agent ends with `NEEDS_INPUT` (see below)
  rather than guessing.
- **In the repository.** Files or artifacts that must exist (an ADR with `Status: Accepted`, a
  previous coverage matrix to diff against, a diff to review).
- **Read-only.** What the agent reads but never modifies, stated explicitly.

An agent that already has an `## Input` section earlier in the file keeps it there and does not
duplicate it at the end.

### `## Output`

What the caller gets, in a shape the next link can consume:

- The deliverable and its format (a file at a fixed path, a response in a fixed skeleton).
- The report at the end of a run: what was built or found, what was run, what was skipped and
  why. Figures only from tools actually run; no invented metrics.
- The **terminal states** block, verbatim from the vocabulary below.

### `## Handoff`

Who consumes the output and what they assume:

- The next agent or skill in the chain, named, and the form it expects (for example: every
  finding carries severity, `file:line`, claim and failure scenario, because `review-verifier`
  rejects anything less as `UNPROVEN`).
- What the agent must therefore never omit.
- What it hands back to the user instead of the next agent (questions, decisions).

### `## Fragile points`

Where the agent is known to break, so the caller can guard against it: stale findings written
against an older revision, a diff that hides the caller side of a changed interface, a brief that
restates the ticket instead of the decisions taken since.

## Terminal states

When the agent cannot deliver the result, it ends with exactly one of these on the first line of
its response, then the detail. The state is for the caller to route on: the main loop shows it to
the user as is and never folds it into a summary.

- `NEEDS_INPUT` — a fact only the requester has would change the result. List the questions and,
  for each, which result each answer leads to. Do not guess, do not deliver a result built on the
  guess.
- `BLOCKED` — something outside the brief stops the work: a tool or file is unavailable, a
  precondition is unmet (name it: the ADR is `Proposed`, the callee's repository is not checked out,
  the coverage tool is not configured).
- `OUT_OF_SCOPE` — the request is not this agent's job. Name the agent or skill that owns it.

A subagent cannot ask a question and wait; the state is how it asks. A second `NEEDS_INPUT` from
the same agent on the same task means the work belongs in the main loop, with the conversation.

The block every agent carries under `## Output`:

```markdown
### Terminal states

When you cannot deliver the result, end with exactly one of these on the first line, then the
detail. The caller routes on it; never fold it into a summary.

- `NEEDS_INPUT` — a fact only the requester has would change the result. List the questions and,
  for each, which result each answer leads to. Do not guess.
- `BLOCKED` — something outside the brief stops the work: a tool or file is unavailable, a
  precondition is unmet. Name it.
- `OUT_OF_SCOPE` — the request is not this agent's job. Name the agent or skill that owns it.
```

## The chain this contract serves

| Agent | Takes from | Hands to |
|---|---|---|
| `architect` | brief, repository | `design-reviewer` (pressure-test), builders (ADR as input) |
| `design-reviewer` | design, diff or ADR | author (design-level findings), `review-verifier` (repo-grounded ones) |
| `backlog-planner` | repository | user, `analyst-writer` (task drafts) |
| `qa-expert` | brief, diff or repository | builders (unit gaps), `test-automator` (e2e gaps), `devops-engineer` (environment) |
| `php-developer`, `python-developer`, `js-developer` | expanded requirements, ADR, test strategy | language reviewer, `contract-reviewer` when a call crosses a boundary |
| `php-reviewer`, `python-reviewer`, `js-reviewer` | diff plus description | `review-verifier` |
| `contract-reviewer` | diff plus callee code | `review-verifier` |
| `root-cause-investigator` | symptom, revision, where to run things | builders (failing test, cause, blast radius), `analyst-writer` (timeline, chain), `qa-expert` (regression gap) |
| `security-reviewer` | diff on a security trigger, deployment context | `review-verifier`; «rotate» to the user on a leaked secret |
| `review-verifier` | findings list, revision | author or PR (confirmed), open questions (unproven), retractions (refuted) |
| `test-automator` | coverage matrix gaps | `qa-expert` (matrix update), `devops-engineer` (`docs/qa/ENVIRONMENT.md`) |
| `devops-engineer` | brief, `docs/qa/ENVIRONMENT.md` | user |
| `data-analyst` | dataset | user, `analyst-writer` (business narrative) |
| `analyst-writer` (fan-out form of the `analyst-patterns` skill) | material, decisions, reader, shared glossary | user, tracker (after approval) |

## Adding an agent

Write the body first, then the four sections, then check the four headings are present. If the
`## Handoff` section names an agent, that agent's `## Input` must accept what is handed; update
both sides in the same release.
