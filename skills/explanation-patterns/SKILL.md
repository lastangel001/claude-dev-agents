---
name: explanation-patterns
description: Shapes for delivering information so the reader can follow the reasoning - Minto pyramid and SCQA for a whole document, Context-Action-Result for a narrative, Need-Solution-Result for a proposal (and refuses to invent the need a proposal cannot show in a concrete scenario), What/So-what/Now-what for a paragraph, and mechanism plus failure condition for explaining a defect. Picks the shape by scale and genre, forbids visible scaffolding, and makes the «so what» mandatory for every fact. Language-agnostic, pairs with ru-output-style (which governs Russian wording). Activate when writing or restructuring a report, research summary, incident post-mortem, verdict, recommendation, ADR, meeting plan or backlog rationale - anything where a reader has to follow an argument, and especially when a draft reads as correct but heavy.
---

# Explanation Patterns

Rules for the *shape* of an explanation: what goes first, what the reader needs before
they can accept the next sentence, and where the «so what» lives. Language-agnostic;
`ru-output-style` governs Russian wording, this skill governs the order of thought.

The failure mode this prevents is a document that passes every local check and still
exhausts the reader. Terms are glossed, numbers carry their base, sentences are clean,
and the reader still cannot say why any of it matters. That happens when the text
reports mechanism without consequence, or states a defect as an absence, or opens with
method instead of result. Those are shape defects, and no amount of sentence-level
editing repairs them.

## When to Activate

- Writing or restructuring a report, research summary, post-mortem, verdict, or proposal
- A draft that is factually correct and reads as heavy, dense, or pointless
- A section that explains how something works and leaves the reader asking «и что»
- Trigger phrases: "структурируй", "перестрой", "тяжело читается", "непонятно зачем",
  "объясни понятно", "restructure this", "why does this matter"

## The rule that outranks the others: the shape stays invisible

The reader gets the order of thought, never the scheme the text was built from.

- **No heading named after a beat.** «Контекст», «Ситуация», «Действие», «Результат»,
  «Проблема», «Решение», «Потребность» as a section title expose the template and read
  as filled-in boilerplate. Name the heading after its content: not «Проблема» but
  «Карточка адреса живёт месяцами после сноса дома».
- **No service connective announcing a beat**: «итак, что это значит», «перейдём к
  результату», «а теперь о решении». The beat arrives through the sentence itself.
- **No fixed beat count per section.** A paragraph needs the beats its content needs;
  padding a missing beat with a vague sentence is worse than three honest beats.

A framework applied visibly produces exactly the formulaic register `ru-output-style`
bans. If the shape can be reverse-engineered from the headings, rewrite the headings.

## Pick the shape by scale and genre

| Scale | Shape | Fits | Does not fit |
|---|---|---|---|
| Whole document | Minto pyramid, SCQA in the opening | answer first, arguments grouped MECE, data at the bottom | an incident chronicle where order of events is the point |
| Section «what we did» | Context, Action, Result | retelling your own work, a timeline | explaining someone else's mechanism - there is no «our action» in it |
| Section «why it happens» | Mechanism, why it was built that way, the condition under which it lies | diagnosing a defect | describing a norm, where nothing fails |
| Section «what to do» | Need, Solution, Result | a plan item the author will carry out | diagnosis, where no solution exists yet; a need nobody can show in a concrete scenario |
| A decision someone else makes | Question, options, price and gain of each, reversibility, your recommendation, who decides by when | «что решить продукту», an ADR, anything handed over | a decision already taken - then it is a plan item |
| Paragraph | What, So what, Now what | any fact that should lead to a decision | a reference insert, an appendix entry |
| A number | Share, base, comparison, consequence | a metric in the business layer | a table, where the consequence goes in the caption |

Two rows carry most of the weight.

**Mechanism plus failure condition** is the shape for a defect. Describe the rule
neutrally, say why it was built that way (this removes the objection the reader raises
first), then name the condition under which it breaks. A defect written as an absence
(«правило не проверяет похожесть») gives the reader a hole; a defect written as a
condition («правило верно, пока первый экземпляр лёг правильно») gives them something to
reason with. See [references/diagnosis.md](references/diagnosis.md).

**What / So what / Now what** makes the consequence mandatory at paragraph scale. A fact
with no «so what» is a fact the reader has to justify on the author's behalf, and they
will not.

**A decision handed to someone else** is the shape most often written as a list of
situations: the author describes what is unclear and stops. A described situation is not
a decidable question. All six beats are load-bearing, and the one most often missing is
«ничего не делать» as an explicit option with its own price. See
[references/frameworks.md](references/frameworks.md).

## Every fact carries its consequence

- **Ask «и что» after each paragraph.** No answer means the paragraph is a reference
  insert; move it to the appendix or delete it.
- **The consequence is in the reader's units**: money, customers, hours, complaints,
  risk, a decision they now have to make. «Карточка живёт 90 дней» is not a consequence.
  «Оператор отправляет курьера по адресу, которого больше нет» is.
- **A comparison makes a number mean something.** A share with no baseline is noise: the
  base says how many, the comparison says whether it is a lot.
- **Consequence, not evaluation.** Not «это критично», but what happens if nobody acts.

## Ceilings: dense is a defect even when every rule is satisfied

Local rules have minimums. These are the maximums, and without them the correct text
becomes unreadable.

- **One «share (N of M)» construction per paragraph.** Three in a row is a table written
  as prose - keep the first, move the rest into an actual table.
- **An enumeration longer than four homogeneous items leaves the prose.** Use a list, a
  table, or a generalisation with the exception: «почти все медиа и соцсети, кроме чатов
  и отзывов» beats eleven source types in one sentence.
- **A business-layer sentence stays under about 25 words.** Longer belongs in the
  technical layer, where a reader has signed up for it.
- **One content, once: a table or prose, never both.** A table followed by the same items
  retold as paragraphs makes the reader work through it twice, and on the second pass they
  cannot tell whether it is new material or a repeat. Choose by one question: does the
  reader need to compare along columns? Yes - table, and the prose around it says only
  what the table cannot (why these options, which one you recommend). No - prose.
- **Frame sentences are legal and do not count against a fact budget.** «Само по себе это
  правильно», «проблема в том, что», «здесь всё держится на одном допущении» carry no
  fact and carry the reader. A rule of one fact per sentence must not squeeze them out -
  they are what makes the facts land.

## Check before delivering

1. **Read the headings alone.** They must tell the story and must not reveal a template.
2. **For each paragraph, answer «и что» in one sentence.** If you cannot, the paragraph
   has no place in this layer.
3. **For each defect described, find the failure condition.** If the text only says what
   the rule fails to do, rewrite it as the condition under which the rule is correct.
4. **For each plan item, write the scenario in which the need shows itself**: who runs
   into it, when, what exactly they see. If it does not write itself, the need is not
   established. Report the gap as a gap with the mark «проверить соразмерность»; never
   fill it with a plausible scenario, that is how plan items against events that do not
   happen get built.
5. **Count the density**: shares with bases per paragraph, items per enumeration,
   words in the longest business-layer sentence.
6. **Have someone who did not do the work read it** - or a fresh agent with one task:
   for every paragraph in the «why» section, say whether the text states why the rule
   exists and under what condition it breaks. Self-review does not catch this; the author
   knows the answer and reads it into their own text.

## Reference Routing

| Task at hand | Read |
|---|---|
| A shape in detail: origin, what it is for, where it fails, worked example (Minto, SCQA, MECE, CAR, Need-Solution-Result, PREP, What/So-what/Now-what, Toulmin warrant) | [references/frameworks.md](references/frameworks.md) |
| Explaining a defect, a mechanism, an incident: the three-beat shape, defect-as-absence cure, worked example | [references/diagnosis.md](references/diagnosis.md) |
| Russian wording, slop patterns, the deterministic linter | the `ru-output-style` skill |

## Out of scope

Code and identifiers, tables and axis labels, legal and academic register (their shape is
the genre), and wording itself. A shape defect and a wording defect are repaired
separately; fixing prose style does not fix the order of thought, and restructuring does
not clean the sentences.
