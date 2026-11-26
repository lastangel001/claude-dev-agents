# Practices — named exercises with a source

A **method** (`methods.md`) is a way to do the work of a stage: analyse, generate, choose. A
**practice** is a named, packaged exercise with fixed steps, materials and an artifact it leaves
on the wall: an opening, a check-in, an energizer, a debrief, a closing. Methods are picked by
situation type; practices are picked from a library and run as written.

The library behind this file is the «Библиотека фасилитатора» at facilab.ru (191 cards on
2026-11-26). `practices-index.md` lists every card; the short list below covers the practices
that fit most working sessions and gives enough of the mechanics to choose between them.

## Rules

1. **A named practice is looked up, never reconstructed.** When the user names a practice
   («Три числа», «Стена опыта», «Lean Coffee»), find it in `practices-index.md`, open its card
   and build the stage from the card. A practice rebuilt from its name reads plausibly and is a
   different exercise: the participants do something the owner did not ask for.
2. **Every opening, closing and energizer in a plan is a practice from the library**, named in
   the scenario with its card id. Improvise only when nothing in the index fits, and then say in
   the plan that the stage is the author's own design, not a known practice.
3. **Read the card before writing the stage.** The short list and the index are for choosing.
   The card holds the materials, the wording of the instruction, the timing of each step and the
   debrief questions.
4. **Adaptations are declared.** A card assumes a group size and a time; a real session rarely
   matches. Shortening is allowed, silently changing is not. Next to the stage write what was
   changed against the card: time, group size, steps dropped. A typical adaptation for a team
   of three to six: rounds in pairs with a partner change become one round of the whole group.
5. **A practice the index does not know** may be new on the site or come from another source.
   Check the live list (below); if it is not there, ask the user where the practice comes from
   instead of guessing.
6. **The artifact is part of the choice.** A practice that leaves sheets, a chart or a column of
   stickers on the wall feeds the next stage and the after-phase; a purely verbal one does not.
   Put the artifact into the scenario's «Визуализация» column.

## Opening a card

- Page: `http://facilab.ru/cards/<id>`. The site is a single-page app, so a plain page fetch
  returns an empty shell.
- Text of the card: `http://facilab.ru/api/cards/<id>.json`. The mechanics are in
  `description_text` (HTML), group size in `people`, duration in `time`, the purpose in
  `announcement`, when to use it in `useit`.
- Live list of all cards: `http://facilab.ru/api/cards.json?type=visible`; by stage:
  `http://facilab.ru/api/tags/<n>/cards.json?type=visible` with n from 1 to 8 (opening, vision,
  analysis, ideas, choice, action plan, closing, other).
- The index is a snapshot. When a card id is missing from it or the card reads differently from
  the gloss, the card wins.

## Short list

One line of mechanics per practice, in this file's own words. Group size and time are the
card's; «leaves» is the artifact.

### Opening, acquaintance, check-in

| Practice (id) | Group, time | Mechanics | Leaves |
|---|---|---|---|
| Три числа (48) | 6+, 15-20 min | Each writes three numbers that matter in their life on a sheet, the facilitator shows an example first; stories in pairs with partner changes; sheets go on the wall under a team heading; debrief on what repeats, what surprised, what unites | wall of sheets |
| 10 / 10 / 10 (54) | 3+, 15-20 min | Three answers in writing: a dream at ten, life ten years ago, life in ten years; shared in small groups, then in changing pairs | personal sheets |
| Волшебная шкатулка (170) | 5-30, 15 min | A box of odd objects; each takes one without much thought and says who they are, why this object and how it links to the topic; the facilitator goes first | nothing |
| Погода настроения (135) | 5-15, 5 min | A poster with weather zones; on arrival each draws their mood on a round sticker and places it; the facilitator's sticker is the sample; repeated at the end it shows the shift | mood poster |
| Welcome доска (127) | 5-30, 15 min before start | A prepared board that early arrivals fill in: name, contact, how I can help; for colleagues, hobby and expectations instead | board, photographed |
| ИПОЗ (122) | 10-20, 15 min | Anonymous slips: explorer, shopper, vacationer or prisoner of this meeting; tally on a flipchart and discuss what the split means for the session | tally chart |
| Блиц-опрос (123) | 5-15, 10 min | A question answerable in one to three words, a minute to think, a fast round; works as a check-in, a switch of attention or a check-out | optional list |
| OARRS (66) | 3+, 15-20 min | Opening in a fixed order: the outcome stated by the client, the agenda, the rules, the roles | flipchart of outcome, agenda, rules |
| Визуализация: маршрут сессии (81) | any, 5 min | The programme presented as a route: step cards stuck to a template one by one, a marker moves as the session goes | route map |
| Три корзины (73) | 5+, 10-20 min | Participants write their questions on stickers and sort them into three baskets: burning now, will burn tomorrow, not burning but worth noting | three sorted lists |

### Keeping the process

| Practice (id) | Group, time | Mechanics | Leaves |
|---|---|---|---|
| Парковка (144) | 2-100, 30 min in total | A separate sheet for valuable items that are off the current topic; reviewed before the close, each item gets an owner or is dropped | parking sheet |
| Me We Us (4) | 5+, 20-30 min | Everyone writes alone, then compares in a small group, then the groups report to the room; the default shape for any question where quiet people must be heard | group lists |

### Looking back: review, retro, causes

| Practice (id) | Group, time | Mechanics | Leaves |
|---|---|---|---|
| Стена опыта (21) | 3-15, 30-100 min | Four sentence stems: «я заметил», «я почувствовал», «я понял», «я предлагаю»; one statement per sticker, posted under the four headings; those who wish comment | four columns |
| Что? И что? И что теперь? (104) | 5-30, 1 h | Three passes over a shared experience: what happened, what it means, what follows; each pass alone, then in small groups, then together | three lists |
| Круги и суп (168) | 5-15, 1 h | Three concentric circles: what the team controls, what it can influence, what it cannot change; problems are placed in a circle, actions are planned for the inner two | circle chart |
| Гистограмма удовлетворённости (79) | 5-12, 30-40 min | Events of the period on cards of three colours (pleased, neutral but important, upset) stacked in three columns; the heights give the picture before the talk | histogram |
| ППН (151) | 3-50, 1 h | A template with three fields: stop, continue, start; groups fill it with stickers and present | filled template |
| Роза, бутон, шип (156) | 5-30, 1.5-2 h | Three sticker colours: what works, what has potential, what hurts; stickers are clustered into themes | clustered wall |
| Пять «почему» (121) | 5-15, 1-1.5 h | The question «why» repeated down one causal chain until a cause the group can act on | cause chain |
| Pre-mortem (212) | 3-12, 1.5-2 h | The project is declared failed in advance; each writes why it failed; reasons are clustered and turned into preventive steps | risk clusters |
| Анти-цель (203) | 4-10, 1 h | The group lists how to guarantee failure, marks what of that it already does and decides what to stop | stop list |

### Choosing

| Practice (id) | Group, time | Mechanics | Leaves |
|---|---|---|---|
| Светофор (109) | 10-50, 15 min | Ideas are sorted by three colours: red to stop, yellow to park or keep, green to start | three zones |
| COCD Box (120) | 5-20, 30 min | A 2x2 of originality against feasibility: do now, wow, how; protects the bold ideas that a plain vote kills | 2x2 chart |
| Оценка NUF (185) | 3-50, 1 h | Each idea scored on three scales: new, useful, feasible; the sum ranks the list and shows where an idea is weak | score table |
| Lean Coffee (98) | 5-30, 1 h | No agenda: topics on stickers, a dot vote orders them, each gets a timebox and a continue-or-stop vote; three columns track the flow | board of three columns |

### Closing, feedback, gratitude

| Practice (id) | Group, time | Mechanics | Leaves |
|---|---|---|---|
| Плюс / Дельта (114) | 5-50, 10-45 min | Two columns: what was good and worth repeating, what to change next time; change, not criticism | two columns |
| Говорящая дверь (110) | 5-30, 10 min | Three smileys on the door from happy to upset; each writes feedback on a sticker and puts it at the matching level on the way out | door of stickers |
| Спина к спине (171) | 10-50, 10+ min | Pairs stand back to back, hear a debrief question, turn and answer in turn; repeated with new questions | nothing |
| Спиральный дневник (49) | 3+, 15-30 min | A sheet in four quadrants; a spiral drawn in silence to slow down, then a sentence stem completed in each quadrant | personal sheets |
| Круг признательности (166) | 5-10, 30 min | A tight circle, the facilitator included; each person hears what the colleagues value in them | nothing |

## Choosing a practice

- **Start from the purpose of the stage**, then filter by group size and by the minutes the
  scenario can spare. An opening that takes a fifth of the session is too long.
- **Trust level decides the opening.** A group that barely knows each other gets a factual
  practice (numbers, objects, a board). Personal disclosure practices need a team that already
  talks.
- **A closing practice answers one question**: how the session went (feedback), what each takes
  away (reflection) or what the people gave each other (gratitude). Pick the one the
  existential goal calls for.
- **The facilitator takes part in acquaintance practices and goes first.** The first answer sets
  the length and the depth of all the others.
