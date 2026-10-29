# Statuses: rules and worked examples

Four statuses, one per finding, never two. The status answers «what happened to this finding»,
not «was the reviewer right».

## `addressed`

The code changed so the failure scenario the finding describes cannot happen any more.

Required in the report: the fix location (commit or diff hunk) and the evidence: a test that
exercises the scenario, or, when the scenario is not testable in this project, the check that was
run (a type checker, a linter rule, a manual trace named line by line).

Not `addressed`:
- a change that makes the scenario unlikely but still possible («added a log line»);
- a fix for a different scenario than the one named;
- a fix without any evidence it works.

Example. Finding: «`parse_total()` at `billing/invoice.py:51` divides by `len(items)`; an invoice
with no items raises `ZeroDivisionError` on the `/invoices/{id}` endpoint.» Fix: an early return
of `Decimal(0)` for an empty list, plus `test_parse_total_empty_items`. Status `addressed`,
where: `commit 3f2a9c1`, reason: «empty list returns 0; test added».

## `declined`

The finding is wrong, or the behaviour it flags is intended.

Required: a reason that cites something checkable. Either **code** (a guard upstream, a type that
excludes the value, a caller contract, a framework default) with `file:line`, or **a recorded
decision** (an ADR, an issue, a line in the ticket, an explicit decision in the conversation that
produced the change).

«I think it is fine», «this never happens in practice», «the reviewer misread it» are not
reasons. A decline without a checkable reason becomes `clarifying`: the question is then «what
would convince you», with the reviewer's own scenario as the thing to test.

Example. Finding: «`items` may be `None` at `billing/invoice.py:51`.» Code: `Invoice.items` is
typed `list[Item]` and populated in `Invoice.__init__` (`billing/models.py:23`); the ORM loader
never sets it to `None`. Status `declined`, reason: «`Invoice.items: list[Item]`, set in
`models.py:23`; no path assigns None (grep `items = ` in `billing/`)».

Severity does not change on a decline. If the reviewer's severity looks wrong, say so in the
reply; `review-verifier` is the place where severity gets corrected, not this skill.

## `clarifying`

A fact only the reviewer (or the author of the design) has would change the answer.

Required: the question, one sentence, and the status each answer leads to («if the admin path
is the only caller → declined; if the public API reaches it → addressed as proposed»). A question
without the two outcomes is not actionable.

Use it for:
- a finding with no `file:line` or no checkable claim (do not repair it yourself);
- an `unverified` CRITICAL finding whose fix would change behaviour visibly: ask, or advise a
  `review-verifier` pass, before touching the code;
- a fix that broke a test: the test and the finding disagree on the intended behaviour, and the
  reviewer decides which is stale;
- a decline that could not cite code or a decision.

## `skipped`

The finding is right and the fix is clear, but it does not belong in this change.

Required: the reason, and the follow-up named so it is not lost: the ticket to open, the module
owner to ask, the refactoring that must come first.

The **blast-radius guard** decides most of these. A fix is `skipped`, not made, when it would:
- touch a file the change did not already touch and the finding does not name;
- rewrite more than roughly a third of a file;
- change a public contract (a signature other modules call, an API response shape, a schema);
- require a design decision the author has not made (a new abstraction, a different data flow).

A fix that size needs its own review; folding it into a fix-up commit hides it from the reviewer
who asked for it.

Example. Finding: «input is not validated at `api/orders.py:30`»; the same unchecked field is read
in three other handlers in `api/`. Fix the named one (`addressed`), list the other three under
`skipped` with their lines and the follow-up «one validation layer for the `customer_ref` field».

## The table is the contract

The orchestrator reads the status column and acts on it:

| Status | Orchestrator's next move |
|---|---|
| `addressed` | include in the re-review diff; post the reply |
| `declined` | post the reply; the reviewer may contest it in the thread |
| `clarifying` | post the question; the finding stays open until answered |
| `skipped` | post the reply with the follow-up; create the follow-up where the project tracks work |

A row without a reason, or a status the table does not define, breaks that contract. Fill every
cell.
