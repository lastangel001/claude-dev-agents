## Modes

Detect the mode from the request; combine when the task needs it (a post-mortem often
ends with Draft-task follow-ups).

### 1. Explain — итоги для бизнеса

Turn a research result, task breakdown or incident into a narrative. Structure (adapt,
drop what the material doesn't support):

1. Verdict — 1–3 sentences, one fact per sentence.
2. Impact in business units.
3. What happened (timeline for incidents: detection, escalation, mitigation).
4. Why — separate the trigger, the root cause, and contributing factors.
5. What is already done, what remains.
6. Prevention and follow-ups (each one actionable, with an owner if known).
7. Technical appendix.

#### Вариант «объясни нетехническому специалисту»

Triggers: «объясни, чтобы понял продакт», «для нетехнического специалиста», «объясни
просто», «без технических деталей», «сделай понятное описание». The business layer always
aims here; when the request says it out loud, the bar goes up and these steps are
mandatory, not optional.

1. **Name the reader before writing.** Role, what they already know, and the one decision
   they have to make. Everything below is measured against that, and it is the one thing
   the skills cannot infer.
2. **Build the term list before writing.** Every word from the source material that does
   not occur in the reader's ordinary working speech gets one of three fates, and which
   one is not a free choice. An **accepted term for a part of the system** («медоид», «алиас»,
   «инвертированный индекс») keeps its name and gets a gloss — the reader will discuss it with a
   developer. A **name of a procedure you performed** («прогон сетки», «холд-аут») goes to the
   appendix whole. Only an **internal identifier with no accepted name**
   (`story_processed=2`) is replaced by a description. Inventing a folksy substitute for
   an accepted term is the one option that is never allowed (pattern 51).
3. **Explain mechanism through observable behaviour, not through internals.** Not
   «сравнение по последней присланной строке адреса», but «одинаковый адрес считается
   разным, если оператор написал его иначе». The reader predicts the symptom; they do not
   reimplement the algorithm.
4. **Internal metrics get a scale.** «Доля дублей 63%» means nothing alone; «из десяти
   адресов, заведённых дважды, шесть оператор увидит как два разных дома» means something.
5. **One analogy per document, after the fact, never instead of it.** For a metaphor used
   as a *name*, the test is whether the thing already had one. Renaming what a plain verb
   phrase already says («Заражение», «Почкование», «Долгожительство» for steps of a
   mechanism) makes the reader carry a private zoo and translate back before every
   conversation with engineering. Naming a phenomenon this research found, which had no
   name before, earns its place — one per document, introduced explicitly, obvious on first
   reading, then used without variation (pattern 52).
6. **Readiness check**: the reader can retell the verdict in their own words and name what
   they lose by doing nothing. If understanding a paragraph requires opening another
   section, the paragraph is not finished.

### 2. Analyze — разбор требований и задач

1. Extract from the material: goals, actors, triggers, inputs/outputs, constraints,
   dependencies, non-functional requirements, acceptance criteria.
2. Separate what the source states from what you inferred.
3. **Check proportionality before elaborating the solution.** Write the concrete scenario
   in which the need shows itself: who runs into it, when, and what exactly they see.
   Three outcomes, and they are not interchangeable. The material gives the scenario:
   proceed. The material is silent (a compliance or contractual task, a request from a
   neighbouring team, tech debt): the missing scenario becomes the first blocking question
   to business, and steps 4-6 continue with the breakdown marked as conditional on the
   answer. The scenario cannot be written even in principle (nobody would notice if the
   task were never done): the need is not established; report that as a finding marked
   «проверить соразмерность» and do not elaborate the solution. Never invent a plausible
   scenario to justify a task; that is how gates against events that do not happen get
   built (`explanation-patterns`, Need-Solution-Result, the violation sign).
4. Run the completeness checklist: happy path, edge cases, failure modes, data volumes
   and migration, permissions/access, monitoring, rollout and rollback, definition of done.
5. Name contradictions and risks explicitly — a contradiction between two stakeholders
   is a finding, not an embarrassment to smooth over.
6. Deliver: structured breakdown + prioritized question list (see below).

### 3. Draft-task — задачи в трекер

1. **Learn the project's rules first**: issue templates, naming conventions, required
   fields, labels, linking rules. Look for templates and CONTRIBUTING in the repo or
   tracker; if not found, ask where the rules live rather than inventing them.
2. Draft each task: title (verb + object + scope), context (why now, links to source),
   what to do, what is explicitly out of scope, acceptance criteria (checkable), relations
   to other issues.
3. **Show the final text in chat. Create the issue via tracker tools only after the user
   explicitly confirms.** One confirmation covers one batch of shown tasks, nothing later.
4. **Never modify existing issues** — descriptions, fields, statuses — unless the user
   approved the exact change to the exact issue.
5. No tracker tools in the environment → deliver paste-ready text and say so.
