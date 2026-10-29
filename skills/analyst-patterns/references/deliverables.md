## Deliverables

Default format: Markdown. Switch to HTML when the user asks or when interactivity earns
its place (formulas the reader tweaks, a business/tech toggle, a long sortable table).

### Interactive HTML spec

- **Self-contained**: inline CSS, inline vanilla JS, no CDNs, no frameworks; opens from
  disk. `<meta charset="utf-8">` in `<head>` — mandatory for non-ASCII documents.
- **Escape everything data-derived** — titles, labels, quoted log lines — so a stray `<`
  or `&` never breaks or injects into the page.
- **Glossed terms use one fixed markup**: `<a class="term" href="#g-<slug>" title="<gloss
  in 3–7 words>">термин</a>`, with the full definition under `id="g-<slug>"` in a glossary
  section. Style it as a hint, not a link (`a.term{text-decoration:none; border-bottom:1px
  dotted; cursor:help}`). This is not a stylistic preference: `lint-ru.sh` finds glossed
  terms by exactly this markup and cannot verify first-use placement without it. Any other
  tooltip mechanism silently disables the check.
- **A tooltip adds to the text, it does not replace it.** A term the paragraph's meaning
  rests on is explained in the paragraph itself — nobody reading a printout or a PDF export
  sees a `title`. The tooltip carries the detail; the text carries what the paragraph
  cannot be read without. The pattern-46 check verifies where the gloss sits, never whether
  it is enough.
- **Formulas**: MathML (native in modern browsers) or inline SVG. Never external
  renderers (KaTeX/MathJax from CDN violate self-containment).
- **Controls that earn their place**: tabs for the business/technical registers,
  collapsible sections for appendices, what-if inputs and sliders that recompute a formula
  in JS, client-side table sort for long tables. No interactivity as decoration.
- **Graceful degradation**: with JS off the full content is still readable — controls go
  dead, nothing disappears.
- **Visual system**: palette once as CSS custom properties in `:root`; default base
  palette — accent `#4f8eff` (links `#2775ff`), positive `#76b41b`, negative `#ff4961`,
  warning `#ffa630`, text `#292f37`/`#4c515c`/`#979ca9`, lines `#cbcfd8`, backgrounds
  `#fff`/`#f6f6f7`/`#f2f7ff`. One accent family, contrast readable (WCAG AA-ish),
  survives ~760px width.
- **If the document needs a chart**, follow data-analyst discipline: every value and the
  chart geometry computed (script or explicit arithmetic), axis from 0, value labels on
  every bar/point, legend when more than one series.

## Calibration

Match length to the material: a single-incident post-mortem is 1–2 pages, not 10. A
requirements breakdown for a one-sprint task fits one screen of Markdown. Never pad to
look thorough.

Final chat reply: deliverable path(s), the verdict in 2–4 lines, the count and top of the
open questions, and — in Draft-task mode — the status of each task (draft awaiting
confirmation / created, with link).

## Russian prose style

When the document is in Russian, its prose — verdicts, findings, narrative, your final
chat reply — must not read as AI-generated. `ru-output-style` (see Skills) is the single
source of truth: the pattern catalog, the gold example for the genre, and the linter on
the saved file (`bash <skill-dir>/scripts/lint-ru.sh document.md` — handles `.md` and
`.html`; fix every BAN before delivering, warnings are a judgment call).

A finding is a number, not an assessment: «41% ошибок (127 из 310) приходит из канала X»,
not «канал X демонстрирует ключевую роль в ошибках». Exemption: questions addressed to
people and verbatim quotes from sources.

If the skill is not installed, say so when handing over the deliverable instead of
implying the check ran. These four bans are a floor, not a substitute for fifty patterns:

- «не просто X, а Y», «не только X, но и Y» и любые перестановки этого контраста
- длинное тире «—»; знаки `= > < → + vs` в прозе — словами (в таблицах можно)
- правило трёх, «подводя итог», «важно отметить», «ключевой»
- неупотребимые деепричастия: «платя», «пиша», «жгя», «могя», «бежа», «лгя»
