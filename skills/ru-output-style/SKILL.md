---
name: ru-output-style
description: Style guard for Russian prose written for humans — findings, verdicts, summaries, report text, meeting plans, chat replies. Hard-bans the telltale AI-slop patterns (negative parallelisms «не просто X, а Y», long dash «—», math signs in prose, rule of three, «подводя итог» closings, chopped drama, colon reveals) and routes to a distilled catalog of 37 patterns with cures. Activate when writing Russian выводы, findings, резюме, verdict text, отчёт prose, план встречи, or any Russian text a person will read. Not for code, commit messages, English text, or legal/academic register (канцелярит там — жанр).
---

# Russian Output Style (ru-output-style)

Rules for writing Russian prose that does not read as AI-generated. Scope: the prose a
human reads — findings, verdicts, summaries, plan narratives, final chat replies. Out of
scope: code, identifiers, commit messages, English text, legal/academic documents.

The core failure mode is not bad grammar — it is a recognizable *pattern cluster*:
negative parallelisms, the long dash everywhere, the rule of three, a «подводя итог»
closing. One marker means nothing; three from different families read as machine output.
Prevent the cluster at write time instead of editing it out later.

## When to Activate

- Writing key findings / выводы / вердикт in a Russian report
- Writing a Russian meeting plan, summary, announcement, or README prose
- Final chat replies in Russian that carry conclusions
- Trigger phrases: "сформулируй выводы", "напиши по-русски", "итоги", "резюме",
  "ключевые находки", "опиши результаты"

## Hard bans — rewrite on sight

Finding any of these in your own draft is an automatic fail; rewrite before delivering:

- **Негативные параллелизмы**: «не просто X, а Y», «не только X, но и Y» — и любые
  перестановки того же контраста («как X, так и Y» с тем же смыслом — тот же слоп)
- **Длинное тире «—»** — использовать короткое «-»
- **Математические и кодовые знаки в прозе**: `= > < → + vs &` — писать словами
  (в коде, таблицах и подписях осей — можно)
- **Правило трёх**: «качество, надёжность и эффективность» — одно точное слово
  или конкретика
- **Риторические вопросы** в утвердительной прозе
- **Двоеточия-подводки**: «Самое интересное: ...», «Деталь, которая всё меняет: ...» —
  раскрытие писать обычным предложением
- **Рубленый драматизм**: «Без X. Без Y. Только Z.»
- **Разделители «---»** между абзацами — границы задают заголовки
- **Резюмирующие закрытия**: «подводя итог», «в заключение», «в целом можно сказать»

## Forbidden swaps — a synonym is not a cure

Slop replaced by related slop is still slop. Do not:

| Было | Так нельзя | Лечение |
|------|-----------|---------|
| «не только X, но и Y» | «как X, так и Y», «и X, и Y» | два простых предложения или одно без противопоставления |
| «—» везде | «:» или «;» везде механически | точка, запятая или «-» по смыслу |
| «ключевой» | «важнейший», «центральный», «критический» | удалить или конкретика: чем именно важен |
| правило трёх | новая тройка из других слов | одно точное слово |
| фальшиво-глубокий финал | метафора поизящнее | закончить на последнем конкретном предложении |

## Quick rules for findings and verdicts

- **Число вместо оценки.** Не «канал X демонстрирует ключевую роль в ошибках», а
  «41% ошибок (127 из 310) приходит из канала X».
- **Главное — первым предложением.** Без анонсов («давайте разберёмся», «вот что
  нужно знать») и без пересказа заголовка первой строкой.
- **Предложения разной длины.** Монотонный ритм (все по 12-15 слов) — маркер сам по себе.
- **Не отчитываться о процессе.** Читателю — что изменилось или что найдено, не
  методология и не «была проведена работа».
- **Одно смягчение на предложение максимум.** «Возможно, в некоторых случаях это,
  скорее всего, сработает» — каскад хеджирования, оставить одно слово или убрать все.
- **Чистый текст не трогать.** Сухой текст без паттернов — это просто сухой текст;
  повторная стилистическая правка его ухудшает.

## Reference Routing — read only what the task needs

| Task at hand | Read |
|---|---|
| Full catalog: 37 patterns by family (канцелярит, AI-словарь, структура, коммуникация, ритм) with markers and cures | [references/patterns.md](references/patterns.md) |

## Attribution

Distilled from [smixs/humanizer-ru](https://github.com/smixs/humanizer-ru) (MIT), which
builds on [blader/humanizer](https://github.com/blader/humanizer), the Wikipedia essays on
signs of AI writing, and Ильяхов «Пиши, сокращай». humanizer-ru is the full editor skill
(3-phase audit/fix/verify pipeline, deterministic linter, detect mode) — install it
separately when the task is *editing existing text*; this skill is the write-time
prevention subset.
