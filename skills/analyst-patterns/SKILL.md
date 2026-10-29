---
name: analyst-patterns
description: "Business and systems analysis with a technical writer's craft: explaining technical material - research results, task breakdowns, incident post-mortems, architecture decisions - to a business reader in two registers (business layer first, technical appendix after), requirements analysis that separates facts from assumptions and checks the need's proportionality before elaborating a solution, prioritized clarifying questions grouped by addressee and ordered by blocking power, and tracker-ready task drafts (Jira/GitLab) created only after the user approves the final text. Routes the shape to explanation-patterns and Russian wording to ru-output-style, and mandates a final read with a stranger's eyes. Activate when the user asks to 'опиши итоги для бизнеса', 'объясни, чтобы было понятно нетехническому специалисту', 'объясни просто, без технических деталей', 'сделай понятное описание инцидента/исследования', 'проанализируй требования/задачу', 'сформируй вопросы по задаче', 'подготовь/заведи задачу в трекер', 'explain this incident to stakeholders', 'analyze these requirements', 'write a post-mortem for the business', or 'draft a ticket from this'. The analyst-writer agent is the fan-out form of this skill; the main loop uses the skill directly for dialogue-heavy work."
---

# Analyst Patterns

The craft of a senior analyst-writer: a business + systems analyst with a technical
writer's craft, who reads real technical material — code, logs, tickets, research notes,
incident timelines — understands it at engineering depth, and delivers text a
non-technical stakeholder can act on.

## When to Activate

- Turning a research result, task breakdown, incident or architecture decision into a
  narrative for a business reader (Explain mode)
- Breaking down requirements or a task: facts vs assumptions, gaps, contradictions,
  proportionality, clarifying questions (Analyze mode)
- Drafting tasks for a tracker from a post-mortem, a backlog or the user's words
  (Draft-task mode)
- Trigger phrases: «опиши итоги для бизнеса», «объясни нетехническому специалисту»,
  «объясни просто», «проанализируй требования», «сформируй вопросы по задаче»,
  «заведи задачу в трекер», "explain to stakeholders", "analyze these requirements"

## Reference Routing — read only what the mode needs

| Task at hand | Read |
|---|---|
| Choosing and running a mode: Explain (with the «объясни нетехническому специалисту» bar), Analyze (with the proportionality step), Draft-task | [references/modes.md](references/modes.md) |
| Forming the clarifying-question list: grouping, ordering, closed form, the ~10 cap | [references/questions.md](references/questions.md) |
| The final check before delivery: reading with a stranger's eyes, headings alone, «и что» per paragraph, nothing added or lost | [references/final-check.md](references/final-check.md) |
| Deliverable formats (Markdown, the interactive HTML spec), Russian prose floor, calibration of length and of the final chat reply | [references/deliverables.md](references/deliverables.md) |

## Operating rules

- **Two registers, one document.** Business layer first: what happened, what it means,
  what to do — no unglossed jargon, impact in business units (money, customers, hours,
  risk). Technical layer after, as an appendix for engineers: exact versions, stack
  traces, queries, code references. Never mix registers inside one paragraph.
- **Comprehension is a separate pass from style.** A term is glossed where the reader
  meets it, procedure jargon stays in the appendix, a defect is written as a condition
  rather than an absence. The mechanics live in `ru-output-style` (see Skills below);
  what this skill owns is naming the reader and refusing to deliver text they cannot
  parse.
- **Never replace an accepted term with one you invented.** «Типовая запись» instead of
  «медоид», «запасное имя» instead of «алиас» looks like care for the reader and works
  against them: the invented word exists only in this document, cannot be looked up, and
  cannot be said to a developer. The accepted term stays in the text and gets a gloss
  (pattern 51). Exiling to the appendix applies to **names of procedures you performed**
  («прогон сетки», «холд-аут», «оффлайн-переигровка») — the reader is not repeating the research.
  Replacing by a description applies only to an **internal identifier with no accepted
  name** (`story_processed=2`). Names of the things the system is made of stay.
- **Shape before wording.** The main conclusion is the first paragraph; arguments are
  grouped so they do not overlap; every paragraph answers «и что» in the reader's units.
  Which shape fits which scale — pyramid, SCQA, mechanism plus failure condition,
  Need-Solution-Result — is in `explanation-patterns`. The shape stays invisible: no
  heading named after a beat.
- **Facts / assumptions / open questions are labeled explicitly.** Never present an
  inference as a fact. Missing information becomes an open question, not plausible filler.
- **Numbers are concrete and carry their base**: «ошибка воспроизводится в 12% заказов
  (340 из 2833 за неделю)», not «часто воспроизводится». A bare percentage with no answer
  to «чего, из скольких» is a feeling, not a fact.
- **One fact per sentence in the verdict, plus frame sentences.** Four measurements in
  one breath, the second bolted on by a gerund, is how a verdict becomes unreadable — so
  facts get separate sentences and the cost of a fix gets its own. Frame sentences carry
  no fact and do not count against that budget: «само по себе это правильно», «проблема
  в том, что», «здесь всё держится на одном допущении». They are what makes the facts
  land; never cut them to satisfy the budget.
- **Source honesty.** Only claims traceable to the provided material or to code you
  actually read. If you didn't verify it, say who can.
- **Language of deliverable = language of request** (Russian request → Russian document).
  Code, paths, identifiers and error strings stay verbatim.

## Skills — both are mandatory steps, not suggestions

In the main loop, invoke them with the Skill tool. As an agent, locate with Glob
(`**/skills/<name>/SKILL.md` under `~/.claude/` or the project's `.claude/`) and Read.
Either way, follow end to end. They are the single source of truth; this skill does not
restate their rules.

| Skill | Owns | Read when |
|---|---|---|
| `explanation-patterns` | the shape: what goes first, where the «so what» lives, which framework fits which scale, density ceilings, the ban on visible scaffolding | before structuring any document or section; whenever a draft reads as correct but heavy |
| `ru-output-style` | Russian wording: slop patterns, comprehension rules (first-use gloss, defect as condition, threshold for an evaluation), the deterministic linter | before writing Russian prose, and on the saved deliverable |

Diagnosing a defect or a mechanism is the genre that fails most often. Read
`explanation-patterns/references/diagnosis.md` before writing a «почему так происходит»
section.

Before handing over any deliverable, run [references/final-check.md](references/final-check.md)
on the finished text. A stylistically clean text the reader cannot parse is as defective
as slop.
