# Reply drafts for the review threads

One reply per finding, in the language the review was written in. The orchestrator posts them
after the user has seen the table; this skill drafts, it does not post.

## Tone

- Say what changed or why not, in one to three sentences. No thanks, no «great catch», no
  apology; the reviewer wants the state, not the mood.
- Name the commit or the hunk for `addressed`; name the code or the decision for `declined`;
  ask one question for `clarifying`; name the follow-up for `skipped`.
- Keep the reviewer's own terms for the scenario so the thread stays searchable.
- Russian replies follow `ru-output-style` (no long dash, no «не просто X, а Y», figures with
  their base). English replies: plain, no filler.

## Templates

### `addressed`

EN:
> Fixed in `<commit>`: <what changed in one clause>. Covered by `<test name>` / verified by <check>.

RU:
> Исправлено в `<commit>`: <что изменилось>. Проверяется тестом `<test name>` / проверено <чем>.

### `declined`

EN:
> Keeping as is: <the guard / type / contract>, see `<file:line>`. <One clause on why the scenario cannot occur.> If you have a path that reaches it, I will fix it.

RU:
> Оставляю как есть: <защита / тип / контракт>, см. `<file:line>`. <Почему сценарий не возникает.> Если есть путь, которым он достижим, поправлю.

When the reason is a recorded decision:

EN:
> Intended: decided in <ADR-0007 / issue #42 / the ticket>: <the decision in one clause>. Happy to revisit there if the decision should change.

RU:
> Так задумано: решение в <ADR-0007 / задаче #42 / тикете>: <решение одной фразой>. Если решение надо пересмотреть, лучше там.

### `clarifying`

EN:
> Before changing this: <the question>? If <answer A>, I will <status/fix>; if <answer B>, <status>.

RU:
> Прежде чем менять: <вопрос>? Если <ответ A>, сделаю <что>; если <ответ B>, <что>.

For an `unverified` CRITICAL finding:

EN:
> This one is CRITICAL and has not been through verification; I would rather confirm the path before changing behaviour here. Can you name the input or state that triggers it?

RU:
> Находка CRITICAL и не прошла верификацию; до правки хочу подтвердить путь. Какой вход или состояние её вызывает?

### `skipped`

EN:
> Agreed, but out of scope for this change: <why, one clause>. Follow-up: <ticket / owner / the refactoring that comes first>. Not fixing it here so it gets its own review.

RU:
> Согласен, но за рамками этого изменения: <почему>. Дальше: <задача / владелец / что сначала>. Здесь не правлю, чтобы правка прошла своё ревью.

## What not to write

- A reply that restates the finding without a status.
- «Will fix later» without a named follow-up.
- A decline that argues taste («I prefer it this way»).
- Anything about severity in an `addressed` reply; the fix speaks.
