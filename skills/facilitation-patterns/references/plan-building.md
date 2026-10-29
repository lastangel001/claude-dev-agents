# Building a meeting plan end to end

You help a meeting owner turn a fuzzy intent ("we need to align the team", "let's brainstorm
Q3 priorities") into a concrete, runnable session: clear goals, a sharp main question, a timed
scenario, the questions to ask the group, how to run it, and what to do afterwards so the
result is not lost. This file is the procedure and the deliverable's skeleton; the craft behind
each step lives in the sibling references and is pointed to, not repeated.

## Craft rules for the plan

- **One deliverable: a Markdown meeting plan.** Default path `docs/sessions/<slug>-plan.md`
  (slug from the meeting name), unless the user gave a path.
- **Output language = the request's language.** A Russian request → a Russian plan; an English
  request → an English plan. Keep canonical terms recognizable (главный вопрос / the main
  question). File names and any code stay ASCII/English.
- **Missing inputs become assumptions, not inventions.** When key inputs are missing (real goal,
  audience, time budget, desired outcome, client's role), do NOT stall and do NOT invent facts
  about the group or the business. Instead: state your assumptions explicitly, design against
  them, and put the open items in a dedicated **«Вопросы заказчику» / "Questions for the
  client"** block so the owner can confirm or correct before the session. A missing input the
  design can absorb (audience, client's role, time budget) becomes an assumption plus a question
  in that block.
- **Design for the real goal, not the stated format.** If the request asks for a brainstorm but
  the underlying need is a decision, say so and design accordingly. If facilitation is the wrong
  tool (see "When facilitation fits — and when it doesn't" in `facilitation-101.md`), flag it
  instead of producing a hollow plan. A goal that is already a decision is not facilitation;
  a request with no goal at all, or a goal that is already a decision, ends with a
  recommendation of another format rather than a hollow plan.
- **Numbers and timing must add up.** The scenario's per-stage minutes sum to the total time
  budget. Always include a program-minimum and program-maximum (what to cut if short, what to
  add if there's slack).
- **Honest, not padded.** A 45-minute sync gets a tight plan; do not inflate it with
  ceremony. Depth matches the meeting, never the other way around.
- **Russian prose style.** When the plan is in Russian, its narrative prose — контекст,
  лайфхаки, риски, «после сессии», your final chat reply — must not read as AI-generated. The
  single source of truth is the `ru-output-style` skill; following it is a mandatory step, not
  a suggestion: the full pattern catalog (`references/patterns.md`), the gold example for the
  genre (`references/gold.md` — meeting-plan fragment here), the three-question final check,
  and the deterministic linter on the saved plan (`bash <skill-dir>/scripts/lint-ru.sh
  <plan.md>` — fix every BAN before delivering, warnings are a judgment call). For the shape
  of the plan's prose — the order of thought in контекст and риски, and the ban on headings
  named after a template beat — read the `explanation-patterns` skill. **The question bank is
  exempt from the rhetorical-question ban** — questions addressed to the group are the
  deliverable, not rhetoric. The bans govern the narrative prose around them. Final check
  before delivering: (1) what still reads as AI-generated — rewrite it, don't synonymize;
  (2) the style pass must not have added or lost a single fact, name, number, timing, or quote.

## Step 0 — classify the complexity level (calibration axis)

Before anything else, place the meeting on one of three levels and scale your whole design to it:

- **Base meeting / working session** — operational tasks: status, coordination, gathering
  input, a concrete decision inside an existing strategy. Role: *master of the process*
  ("мастер на все руки"). Keep it lean: a couple of techniques, tight timeboxes.
- **Strategy session / brainstorm (штурм)** — strategy, vision, complex problems, change.
  Hours to days, deeper methodology, key stakeholders. Role: *process architect* — design a
  coherent arc (sequence of activities, each with its own purpose).
- **Global dialogue / community participation** — cross-org, cross-sector, cross-culture
  systemic dialogue. Role: *conductor* — inclusion, legitimacy, conflicting interests; the
  point is a process that is inclusive, transparent and legitimate to all sides.

State the level in the plan; it determines method depth, group size handling, and the role you
advise the facilitator to play. The level table with design depth per level is in
`facilitation-101.md` ("Three complexity levels").

## The goals pyramid (Global Dialog) — pick the target level

Sessions climb four levels; the target level fixes the depth and the shape of the main question.
The four levels, with the rational and existential goal per level and a worked example, are in
`facilitation-101.md` ("The goals pyramid"). For each level give both the rational goal ("what
to achieve") and the existential goal ("what experience participants get").

## The main question (главный вопрос)

The construction (main part + «Чтобы что…»), the verb ladder (можем → следует → необходимо →
должно), the checklist and worked examples are in `questions.md` ("The main question"). In the
plan it goes into the «Шапка» as «{основная часть}, чтобы {…}?» and is agreed with the client
before the session.

## Questions to the group (Strachan's principles)

Strachan's six principles, the self-check before asking, risk laddering and a starter question
bank by stage are in `questions.md`. The plan's question bank is written per stage,
Strachan-clean and risk-laddered, including the main question.

## Client's role (роли заказчика) — A / B / C

- **A** — owns the decision; collects the group's wisdom but decides afterwards (may use a
  "golden like" to mark priorities). Tell the group up front that the output feeds a leadership decision.
- **B** — wants a true consensus the leader is part of; participates as an equal, speaks last,
  controls verbal/non-verbal signals so as not to dominate.
- **C** — only frames the session and sponsors it; participants are autonomous; the leader has
  an advisory voice. Good for mature, self-managing teams.

Reflect the role in the design and especially in the main-question verb.

## Session lifecycle — before / during / after

Facilitation is three role aspects across three phases: **process master** · **dialogue
architect** · **lifecycle coordinator**.
- **Before:** clarify goals with the client (interview the owner + 1–2 future participants +
  1–2 stakeholders), prepare and pre-send materials, select participants.
- **During:** opening (state goal, format, timing, how results will be used) → activities
  (hold the format/regulations, push "deeper", concretize, structure the output) → close
  (summarize, name owners for actions, restate how results are used, thank the group).
- **After (mandatory):** capture and systematize outcomes into a document, distribute it,
  confirm owners and deadlines, and ensure the decisions are actually implemented. Without the
  after-phase the work goes "в песок" (down the drain). Always include an after-phase plan.

The five preparation steps, the full opening / running / closing checklist and the after-phase
are detailed in `preparation.md`.

## Real-time interventions (the "in the moment" model)

A facilitator's live moves, scaled by phase: **process** (agenda, roles), **reflection**
(probing questions, checking the process), **conflict** (addressing disagreement/distrust),
**safety** (rules, no discrimination), **teaching** (a method on the spot), **self-disclosure**
(sharing to lower barriers), **task completion** (delegate, track), **humor** (defuse tension),
**idea support** (encourage unconventional ideas), **encouragement** (recognize contributions).
Early in a session, process + safety dominate; mid-session, reflection/conflict/teaching/closure
rise. Reading the room — non-verbals, energy — matters as much as knowing techniques.

Common disruptions and moves: **passivity** → ask, invite by name, manage turn-taking;
**over-activity** → thank, give others the floor; **argument** → hear each side, stay neutral,
restate the goal, summarize; **side-talk** → pause, eye contact, invite to share;
**latecomers** → start on time, thank those present, don't shame. (The fuller disruption table
is in `preparation.md`, "Handling disruptions live".)

## Method selection (match the situation type)

Three situation types and their methods (full catalog: pick by "when to use"): the situation
type → method shortlist (analysis / options / choice), every method's when-to-use and how-to-run,
and the comparison cheat-sheet are in `methods.md`, which is the canonical source. Alternate
formats (whole group ↔ pairs ↔ small groups ↔ presentation ↔ voting) to keep energy
and avoid groupthink.

## Process (how you build a plan)

1. Parse the request and any provided context; restate the meeting in one line.
2. **Classify the complexity level** (base / strategic / global).
3. Set the **rational and existential goals** and the **target pyramid level**.
4. Determine the **situation type** (analysis / options / choice) and the Path-to-Action shape.
5. **Select methods** for the level and each stage (with a one-line "why this method here").
6. Build the **scenario grid** with timing; add program-minimum and program-maximum; alternate formats.
7. Write the **question bank** per stage (Strachan-clean, risk-laddered), including the main question.
8. Forecast difficulties (**Голова / Руки / Сердце** — knowledge / skills / motivation) with
   preventive actions; list likely disruptions + in-the-moment moves; add facilitator lifehacks.
9. Plan the **after-phase** (capture, distribute, owners, follow-through).
10. List **assumptions** and **questions for the client**.

## Output format — the meeting plan (fixed skeleton, adapt depth to level)

```markdown
# План встречи: {название}

> Уровень сложности: {базовая / стратегическая / глобальный диалог} · Дата: {если есть}

## Шапка
- **Контекст:** {1–3 строки — зачем встреча, что ей предшествует}
- **Ожидаемый результат:** {конкретный артефакт/решение}
- **Участники:** {кол-во, роли, роль заказчика A/B/C}
- **Время:** {общая длительность}
- **Рациональная цель:** {что достичь}
- **Экзистенциальная цель:** {какой опыт получат участники}
- **Уровень пирамиды:** {взаимопонимание / альтернативы / решение / дорожная карта}
- **Главный вопрос:** «{основная часть}, чтобы {…}?»

## Сценарий
| Этап | Время | Содержание / Вопросы | Механика | Визуализация |
|------|-------|----------------------|----------|--------------|
| Открытие | 10 мин | … | … | … |
| … | … | … | … | … |
| Завершение | … | … | … | … |

_Программа-минимум:_ {что убрать при нехватке времени}.
_Программа-максимум:_ {что добавить при избытке}.

## Банк вопросов по этапам
- **{этап}:** {2–4 открытых вопроса}

## Лайфхаки ведущего
- {3–6 практических подсказок под этот формат}

## Риски и профилактика
| Сфера | Риск | Профилактика / интервенция |
|-------|------|----------------------------|
| Голова/Руки/Сердце | … | … |

## После сессии
- {фиксация итогов, рассылка, ответственные, контроль реализации}

## Допущения и вопросы заказчику
- **Допущения:** {что предположил при нехватке вводных}
- **Вопросы заказчику:** {что подтвердить до сессии}
```

Adapt — drop or merge blocks the meeting doesn't need; never exceed what the level warrants.

What the owner takes from the plan: the main question to agree with the client before the
session, and the open questions under «Вопросы заказчику», to be answered before the session
is run, not after.

## What goes wrong

- A goal that is already a decision («get the team to accept the new process»): the plan
  dresses an announcement as a session. Name it as not facilitation and recommend another
  format instead of designing a brainstorm around a closed question.
- A missing time budget: the scenario's minutes rest on an assumed total, and the
  program-minimum has nothing real to cut from. Put the assumed budget first under
  «Допущения»; it is the one assumption that invalidates every row of the scenario.
- The level misclassified: a strategy session planned as a base meeting gets two techniques
  and no arc; a status sync planned as strategic gets ceremony nobody needs. State the level
  and the reason so the owner can correct it.
