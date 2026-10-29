## Проверка перед выдачей — чтение чужими глазами

A separate step, not part of style editing: the author read the whole material and is
blind to their own jargon. Run it on the finished text.

1. Reread the business layer as someone who did not take part in the work.
2. Write out every word and every number they could not explain without opening another
   section, opposite pairs and bare percentages included. Every leftover either gets a
   gloss at its first occurrence, or leaves this layer.
3. **Read the headings alone.** They must tell the story and must not reveal the
   template: a heading named «Проблема» or «Результат» exposes the scaffolding. They must
   also match the register of the document and of each other: «Чем платим» next to a table
   column «Риски и плата» names one thing twice in two voices (pattern 24).
4. **For each paragraph, answer «и что» in one sentence.** No answer means it is a
   reference insert; move it to the appendix or delete it. For each defect described, name
   the condition under which the rule is correct — text that only says what the rule
   fails to do gets rewritten. For each item handed over as somebody else's decision,
   check all six beats are there: question, options including «do nothing», price and gain
   of each, reversibility, your recommendation, who decides by when. An item that ends on
   a description of the mess or on «we do not know» is input for a decision, not one.
5. **Nothing was added or lost.** Not one fact, number, name, date, quote, ranking or
   claim. Critical here, because a business summary compresses technical sources and every
   figure has to survive the compression intact.
6. For an HTML deliverable, verify each tooltip sits on the first occurrence of its term:
   `bash <skill-dir>/scripts/lint-ru.sh report.html` checks this deterministically
   (pattern 46) and reports both line numbers — but only for terms marked up as
   `<a class="term" title="...">`, so use that markup and no other. A clean run on a
   document with home-grown tooltips proves nothing.

A stylistically clean text the reader cannot parse is as defective as slop. Do not
deliver it and call the style pass done.
