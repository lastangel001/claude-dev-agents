---
name: address-review
description: "The author's side of a code review: takes a list of findings (the «Publish these» list from review-verifier, or a reviewer's raw output marked unverified) plus the branch, decides per finding addressed / declined / clarifying / skipped, applies the smallest fix inside the diff's scope, runs the project's lint and tests on the touched files, commits fix-ups when the pipeline's autonomy mode allows, and returns a per-finding table plus reply drafts for the PR threads. Never posts to GitHub or GitLab and never re-runs the reviewer itself: the orchestrator does both. Activate when the user asks to close, answer or apply review findings; triggers: «закрой замечания ревью», «ответь на ревью», «примени находки», «поправь по ревью», «address the review», «fix what the reviewer found», «apply the review findings», «respond to review comments»."
---

# address-review

Closes the loop the reviewers open. A reviewer produces findings, `review-verifier` keeps the ones
that survive, and until now nobody consumed that list in a fixed form: the fixes happened «somehow»
and the reviewer learned of them by re-reading the whole diff. This skill takes the list, answers
every entry with one of four statuses, makes the fixes, and hands back a table the orchestrator
can act on.

A skill, not an agent: it runs in the main loop, with the conversation that produced the code, so
the decisions behind the code are at hand when a finding challenges them.

## Input

- **The findings.** Preferably `review-verifier`'s `## Publish these` section: each entry with
  severity, `file:line`, claim, failure scenario and the reviewer's fix direction. A reviewer's raw
  output is accepted too; every such finding is marked `unverified`, and for a CRITICAL one the
  report advises a `review-verifier` pass before the fix, because a confident fix for a refuted
  finding is a regression. Prose input is normalised into a numbered list first and echoed back.
- **The branch or diff** the findings were written against, checked out. If the working tree is
  on another branch or dirty with unrelated changes, stop and say so; do not fix on top of
  someone else's work.
- **The autonomy mode**, from `docs/PIPELINE.md` (`## Gates and autonomy`) when the project has
  one; default `propose`.
- **The reply language** for the PR threads: the language the review was written in, unless the
  project file says otherwise.

## Phase 0 — normalise

One numbered entry per finding: `id · severity · file:line · claim · fix direction · source
(verified | unverified)`. An entry without a `file:line` or without a claim that can be checked
goes straight to `clarifying` with the question «which code, which input, which wrong outcome».
Do not repair a vague finding into a precise one: that would be answering your own finding.

## Phase 1 — decide, one status per finding

| Status | Means | Required |
|---|---|---|
| `addressed` | the code changed so the scenario can no longer happen | the fix, and the test or check that shows it |
| `declined` | the finding is wrong or the current code is intended | a reason that cites code (a guard, a type, a caller contract) or a recorded decision (ADR, issue, a line in the conversation). A decline with no such reason is not allowed: it becomes `clarifying` |
| `clarifying` | a fact only the reviewer has would change the answer | the question, and which status each answer leads to |
| `skipped` | the right fix exists but is out of this change's scope | why: the blast-radius guard below, a design change, another owner's module. Named as follow-up, not forgotten |

Severity is the reviewer's, kept as received (or as `review-verifier` corrected it). Do not
downgrade a finding to justify `declined` or `skipped`.

Full rules and worked examples: [references/statuses.md](references/statuses.md).

## Phase 2 — fix

- The smallest change that closes the scenario. No refactoring on the way, no style changes in
  lines the finding does not name.
- Inside the diff's scope: the files the change already touched, plus a file the finding itself
  names. A fix that would touch other files, or rewrite more than a third of a file, is
  `skipped` with that reason; a follow-up that size deserves its own review.
- When a finding is a symptom of a wider defect (the same unchecked input in four handlers), fix
  the named one, note the others under `skipped` with their locations, and say so in the reply.
- Match the project's conventions as the builders do; a fix-up that fails the project's linter
  is not a fix.

## Phase 3 — verify

Detect the project's lint and test commands from its manifests (or `docs/PIPELINE.md`) and run
them on the touched files, then the test files that cover them. A fix that breaks a test is
reverted and the finding becomes `clarifying`, with the failing test named: either the test
encodes the intended behaviour and the finding is wrong, or the test is stale, and that is the
reviewer's call. Report what ran, with the result lines; name what could not run.

## Phase 4 — commit, by mode

- `propose`: stop here with the diff and the commit text ready; the user commits or says so.
- `guided` and `autonomous`: commit the fix-ups. One commit per finding when two or more
  CRITICAL or HIGH findings were addressed (each commit names the finding id and `file:line`),
  otherwise one commit for all. Commits are local and reversible; **push, PR update and thread
  replies stay with the orchestrator** at Gate 2 in every mode.

## Phase 5 — report

```markdown
## Review addressed — <branch> @ <revision>

| id | severity | file:line | status | where | reason / question |
|---|---|---|---|---|---|
| 1 | HIGH | src/x.py:42 | addressed | a1b2c3d | null guard added; test_x_none covers it |
| 2 | MEDIUM | src/y.py:10 | declined | — | the caller contract (services/z.py:88) guarantees a non-empty list |
| 3 | CRITICAL | src/w.py:7 | clarifying | — | unverified: which input reaches this branch? If any → fix as proposed; if only admin → declined |
| 4 | LOW | src/v.py:3 | skipped | — | the same pattern in 3 other handlers; fix belongs in one change |

Ran: ruff check src/x.py src/y.py (clean); pytest tests/test_x.py tests/test_y.py (14 passed)
Not run: mypy (not configured)

Ready for re-review: yes — fix-up commits a1b2c3d, d4e5f6a. Open: #3 (clarifying), #4 (follow-up).
```

Then the **reply drafts**, one per finding, in the review's language, from
[references/replies.md](references/replies.md). The orchestrator posts them after the user has
seen them; this skill never calls the GitHub or GitLab API.

The last line is always «Ready for re-review: yes | no» with what is open. Re-running the
language reviewer on the fix-up diff is the orchestrator's move, per the project's pipeline row;
this skill does not spawn it.

## What this skill does not do

- Review the rest of the diff, or fix defects nobody reported. A defect noticed on the way is
  listed under «Noticed, not in the findings» for the reviewer, not fixed silently.
- Argue severity. A finding that looks overstated is `addressed` or `declined` on its claim; the
  severity stays, and the disagreement goes in the reply.
- Post, push, merge, or resolve threads.

## Reference routing

| Need | Read |
|---|---|
| Status rules, the blast-radius guard, worked examples | [references/statuses.md](references/statuses.md) |
| Reply drafts per status, tone, language | [references/replies.md](references/replies.md) |
| What `review-verifier` guarantees on its output | `agents/review-verifier.md` → `## Handoff` |
