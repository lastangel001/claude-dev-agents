---
name: ru-output-style
description: Style guard for Russian prose written for humans — findings, verdicts, summaries, report text, meeting plans, chat replies. Hard-bans the telltale AI-slop patterns (negative parallelisms «не просто X, а Y», long dash «—», math signs in prose, rule of three, «подводя итог» closings, chopped drama, colon reveals), routes to a distilled catalog of 42 patterns with cures plus gold examples per genre, ships a deterministic linter (scripts/lint-ru.sh), and mandates a final fact-integrity check. Activate when writing Russian выводы, findings, резюме, verdict text, отчёт prose, план встречи, or any Russian text a person will read. Not for code, commit messages, English text, or legal/academic register (канцелярит там — жанр).
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

## Что сохранять — человеческие детали не вычищать

Правка стиля не должна стерилизовать текст. Признаки живого автора, которые нельзя
трогать как «шум» (даже если абзац переписывается целиком):

- **Конкретные странные детали** — точный адрес, необычная цитата, частный случай,
  который «портит» стройность. Именно они делают текст достоверным.
- **Смешанные оценки и неразрешённое напряжение** — «решение быстрое, но команда
  ему не доверяет». Не сглаживать в однозначный вывод, которого в данных нет.
- **Датированные отсылки и живую лексику автора** — если исходник или образец
  говорит «прод лёг», не переводить в «наблюдалась деградация сервиса».
- **Неровный ритм и самопоправки** — авторское «точнее, не совсем так» — признак
  мышления, не мусор.
- **Осознанное первое лицо** — «я проверил», «мы решили» не заменять безличным
  пассивом.

## Финальная проверка перед выдачей

Перед выдачей русской прозы — два обязательных вопроса к собственному черновику:

1. **Что здесь всё ещё звучит как ИИ?** Пройтись по жёстким запретам и семьям
   каталога; найденное переписать, а не синонимизировать (см. «Forbidden swaps»).
2. **Не изменились ли факты?** Правка стиля не имеет права добавить или потерять
   ни одного факта, имени, числа, даты, цитаты, ранжирования или утверждения.
   Каждая цифра в тексте — из источника; недостающее помечается как неизвестное,
   а не досочиняется.

Если файл сохранён на диск — прогнать детерминированный линтер и исправить все
BAN (WARN — по здравому смыслу, это эвристики):

```bash
bash scripts/lint-ru.sh <файл.md>        # markdown / plain text
bash scripts/lint-ru.sh report.html      # HTML: теги, script/style и таблицы пропускаются
```

Линтер лежит рядом со скиллом (`scripts/lint-ru.sh` относительно этого файла),
выход 1 — есть жёсткие нарушения. Он детерминированный: длинное тире или «не просто»
ловит со 100% полнотой, чего самопроверка модели не гарантирует.

## Reference Routing — read only what the task needs

| Task at hand | Read |
|---|---|
| Full catalog: 42 patterns by family (канцелярит, AI-словарь, структура, коммуникация, ритм) with markers and cures | [references/patterns.md](references/patterns.md) |
| Gold examples: эталонные абзацы по жанрам (finding, вердикт, резюме, план встречи, ответ в чате) — прочитать пример своего жанра перед написанием | [references/gold.md](references/gold.md) |
| Deterministic post-write check of a saved file | run [scripts/lint-ru.sh](scripts/lint-ru.sh) |

## Attribution

Distilled from [smixs/humanizer-ru](https://github.com/smixs/humanizer-ru) (MIT), which
builds on [blader/humanizer](https://github.com/blader/humanizer), the Wikipedia essays on
signs of AI writing, and Ильяхов «Пиши, сокращай». The fact-integrity questions in the
final check and the preserve-human-details list are adapted from blader/humanizer's
verification phase. humanizer-ru is the full editor skill (3-phase audit/fix/verify
pipeline, detect mode) — install it separately when the task is *editing existing text*;
this skill is the write-time prevention subset plus its own deterministic linter.
