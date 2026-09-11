#!/usr/bin/env bash
# lint-ru.sh — deterministic AI-slop linter for Russian prose (ru-output-style skill).
#
# Checks generated Russian text against the skill's hard bans (exit 1 on any hit)
# and warns on the soft markers (AI-lexicon frequency, rule-of-three, monotone
# sentence rhythm). Deterministic on purpose: a regex catches a long dash with
# 100% recall where model self-review does not.
#
# In HTML mode it also runs a comprehension check (pattern 46): for every term
# glossed with <a class="term" ...>TEXT</a>, the first bare occurrence of TEXT in
# the prose must not precede the glossed one. The file is read twice for that -
# pass 1 collects the glossed terms, pass 2 does all the reporting.
#
# Density and shape checks (patterns 48-50 plus the ceilings documented in the
# explanation-patterns skill) run as warnings: defect-as-absence, evaluation
# without a threshold, a raw internal id in prose, three "share (N of M)"
# constructions in one paragraph, an enumeration longer than four homogeneous
# items, and a heading named after a framework beat.
#
# Usage:
#   lint-ru.sh [--strict] [--html] FILE...
#     --strict   warnings also fail (exit 1)
#     --html     strip tags/script/style/tables first (auto for *.html, *.htm)
#
# What is scanned: prose only. Skipped automatically: YAML frontmatter, fenced
# code blocks, inline `code` spans, Markdown table rows; in HTML mode also
# <script>/<style> bodies, tags themselves and <table> content (signs like > <
# = % are legitimate in tables, axis labels and legends per the skill).
#
# Exit codes: 0 clean · 1 hard ban found (or warning with --strict) · 2 usage.
#
# Portability: POSIX awk + bash, no GNU-only flags; runs on Git Bash, macOS, Linux.
set -euo pipefail

STRICT=0
HTML_FLAG=0
FILES=()
while [ $# -gt 0 ]; do
  case "$1" in
    --strict) STRICT=1 ;;
    --html)   HTML_FLAG=1 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "unknown flag: $1" >&2; exit 2 ;;
    *) FILES+=("$1") ;;
  esac
  shift
done
[ "${#FILES[@]}" -gt 0 ] || { echo "usage: lint-ru.sh [--strict] [--html] FILE..." >&2; exit 2; }

# UTF-8 byte sequences built with printf — \x escapes in awk are not POSIX.
EMDASH="$(printf '\342\200\224')"   # —
ENDASH="$(printf '\342\200\223')"   # –
ARROW="$(printf '\342\206\222')"    # →
DARROW="$(printf '\342\207\222')"   # ⇒
EMOJI4="$(printf '\360\237')"       # lead bytes of U+1F000+ (😀 📊 🚀 ...)
DINGB1="$(printf '\342\234')"       # ✀..✿ block (✅ ✨ ✔)
DINGB2="$(printf '\342\235')"       # ❀..➿ block (❌ ❗)
WSIGN="$(printf '\342\232')"        # ⚠ and misc symbols block
BOM="$(printf '\357\273\277')"
LAQUO="$(printf '\302\253')"        # open guillemet
RAQUO="$(printf '\302\273')"        # close guillemet

FAIL=0
for f in "${FILES[@]}"; do
  [ -f "$f" ] || { echo "lint-ru: no such file: $f" >&2; FAIL=1; continue; }
  html=$HTML_FLAG
  case "$f" in *.html|*.htm) html=1 ;; esac

  set +e
  # LC_ALL=C forces byte mode: in a UTF-8 locale gawk rejects the raw byte-prefix
  # vars (emoji4 etc.) as invalid multibyte data and the emoji check never fires
  # (caught by CI on ubuntu). Byte mode keeps fixed-string matching exact everywhere.
  LC_ALL=C awk -v fname="$f" -v html="$html" -v strict="$STRICT" \
      -v emdash="$EMDASH" -v endash="$ENDASH" -v arrow="$ARROW" -v darrow="$DARROW" \
      -v emoji4="$EMOJI4" -v dingb1="$DINGB1" -v dingb2="$DINGB2" -v wsign="$WSIGN" \
      -v bom="$BOM" -v laquo="$LAQUO" -v raquo="$RAQUO" '
  function ban(code)  { bans++;  printf "%s:%d: BAN  %s\n", fname, FNR, code }
  function warn(code) { warns++; printf "%s:%d: WARN %s\n", fname, FNR, code }
  # Both case variants checked where a sentence can start with the marker.
  function has(s) { return index(line, s) }
  # Word-boundary match against nline, the punctuation-normalised copy of the
  # line: " slovo " then matches at line start, after a comma, inside quotes.
  # Needed because index(line, " bezha") also fires inside " bezhat".
  function wb(s) { return index(nline, " " s " ") }
  # How many "share (N of M)" constructions the string carries. Locals declared
  # as extra parameters so they cannot collide with the globals above.
  function triples(str,   c, pr) {
    c = 0; pr = str
    while (match(pr, /\([0-9][0-9 ]* из [0-9][0-9 ]*\)/)) { c++; pr = substr(pr, RSTART + RLENGTH) }
    return c
  }
  # Paragraph-scoped checks are accumulated and flushed: on a blank line in
  # Markdown, and every line in HTML, where one stripped line is already one
  # <p>/<li>. A wrapped Markdown paragraph would otherwise hide a marker that
  # straddles a line break.
  function flushpara(   dt, seg) {
    if (numacc >= 3) {
      warns++
      printf "%s:%d: WARN peregruz chisel: 3+ konstruktsii \"dolya (N iz M)\" v odnom abzatse\n", fname, numline
    }
    # pattern 41, short form: "Это не X." negating a hypothesis the text never
    # raised. Required to be a complete short sentence - from the marker to the
    # next period with no comma between - so "Это не так, потому что..." is quiet.
    if (index(para, "Это не ") > 0) {
      seg = substr(para, index(para, "Это не ") + 12, 45)
      dt = index(seg, ".")
      if (dt > 0 && index(substr(seg, 1, dt), ",") == 0) {
        warns++
        printf "%s:%d: WARN zashchita ot nevydvinutykh vozrazhenij: \"Eto ne X\" (pattern 41)\n", fname, paraline
      }
    }
    numacc = 0; numline = 0; para = ""; paraline = 0
  }

  BEGIN { bans = 0; warns = 0; buf = "" }

  # --- pass 1 (HTML only): collect terms glossed with <a class="term"> ------
  NR == FNR {
    if (!html) next
    tmp = $0
    while (match(tmp, /<a[^>]*class="term"[^>]*>/)) {
      rest = substr(tmp, RSTART + RLENGTH)
      cut = index(rest, "</a>")
      if (cut <= 0) { tmp = rest; continue }
      tt = substr(rest, 1, cut - 1)
      gsub(/<[^>]*>/, "", tt)
      gsub(/^[ \t]+/, "", tt); gsub(/[ \t]+$/, "", tt)
      if (length(tt) >= 4 && !(tt in glossline)) glossline[tt] = FNR
      tmp = substr(rest, cut + 4)
    }
    next
  }

  {
    line = $0
    if (FNR == 1 && index(line, bom) == 1) line = substr(line, length(bom) + 1)

    # --- structural skips -------------------------------------------------
    if (FNR == 1 && line ~ /^---[ \t]*$/) { fm = 1; next }
    if (fm) { if (line ~ /^---[ \t]*$/) fm = 0; next }
    if (line ~ /^[ \t]*(```|~~~)/) { fence = !fence; next }
    if (fence) next
    if (line ~ /^[ \t]*\|/) next                    # Markdown table row

    if (html) {
      if (index(line, "<script")) inscript = 1
      if (inscript) { if (index(line, "</script>")) inscript = 0; next }
      if (index(line, "<style"))  instyle = 1
      if (instyle)  { if (index(line, "</style>"))  instyle = 0; next }
      if (index(line, "<table")) intable++
      if (intable > 0) { if (index(line, "</table>")) intable--; next }
      gsub(/<[^>]*>/, " ", line)                    # strip tags, keep text
      gsub(/&nbsp;/, " ", line)
    }

    gsub(/`[^`]*`/, " ", line)                      # inline code spans

    # punctuation-normalised copy for the word-boundary checks (see function wb)
    nline = " " line " "
    gsub(/[.,;:!?()\[\]"]/, " ", nline)
    gsub(laquo, " ", nline); gsub(raquo, " ", nline)

    # pattern 46: remember where each glossed term is first used in the prose
    if (html) {
      for (t in glossline)
        if (!(t in firstuse) && index(line, t)) firstuse[t] = FNR
    }

    # separator line between paragraphs (frontmatter already consumed above)
    t = line; gsub(/[ \t]/, "", t)
    if (t ~ /^-+$/ && length(t) >= 3) { ban("razdelitel \"---\""); next }

    # --- hard bans --------------------------------------------------------
    if (has(emdash) || has("&mdash;")) ban("dlinnoe tire (em dash)")
    if (has(endash) || has("&ndash;")) ban("srednee tire (en dash)")
    if (has(arrow) || has(darrow) || has("->") || has("=>")) ban("strelka v proze")
    if (has(" vs ") || has(" vs. ")) ban("\"vs\" v proze")
    if (has("не просто") || has("Не просто")) ban("negativnyj parallelizm: ne prosto X, a Y")
    if (has("не только") || has("Не только")) ban("negativnyj parallelizm: ne tolko X, no i Y")
    if (has(", так и ")) ban("negativnyj parallelizm: kak X, tak i Y")
    if (has("подводя итог") || has("Подводя итог")) ban("rezyumiruyushchee zakrytie: podvodya itog")
    if (has("в заключение") || has("В заключение")) ban("rezyumiruyushchee zakrytie: v zaklyuchenie")
    if (has("в целом можно сказать")) ban("rezyumiruyushchee zakrytie: v tselom mozhno skazat")
    if (has("Самое интересное:")) ban("dvoetochie-podvodka")
    if (has("надеюсь, это поможет") || has("Надеюсь, это поможет")) ban("artefakt chat-bota")
    if (has("дайте знать") || has("Дайте знать")) ban("artefakt chat-bota")
    if (has("отличный вопрос") || has("Отличный вопрос")) ban("podobostrastie")
    if (has(emoji4) || has(dingb1) || has(dingb2) || has(wsign)) ban("emoji/dingbat v proze")
    # pattern 45: gerund forms the paradigm allows and living Russian never says
    if (wb("платя") || wb("Платя") || wb("пиша") || wb("Пиша") || wb("жгя") || wb("могя") || \
        wb("бежа") || wb("лгя") || wb("ткя") || wb("пья") || wb("лья") || wb("бья")) \
      ban("neupotrebimoe deeprichastie: platya/pisha/zhgya/... (pattern 45)")

    # --- soft warnings (AI-lexicon) ----------------------------------------
    if (has("является") || has("представляет собой")) warn("izbeganie svyazki: yavlyaetsya / predstavlyaet soboj")
    if (has("ключев") || has("Ключев")) warn("peregruzhennoe slovo: klyuchevoj")
    if (has("важно отметить") || has("Важно отметить") || has("следует отметить") || \
        has("стоит отметить") || has("Стоит отметить")) warn("shablonnyj perekhod: vazhno/sleduet/stoit otmetit")
    if (has("демонстрирует") || has("свидетельствует") || has("способствует") || \
        has("подчёркивает") || has("подчеркивает")) warn("AI-glagol: demonstriruet/svidetelstvuet/sposobstvuet/podcherkivaet")
    if (has("осуществля")) warn("kantselyarit: osushchestvlyat")
    if (has("в рамках") || has("В рамках")) warn("kantselyarit: v ramkakh")
    if (has("в современном мире") || has("на сегодняшний день") || \
        has("как известно") || has("не секрет")) warn("stop-slova: v sovremennom mire / na segodnyashnij den / ...")
    if (has("играет важную роль")) warn("shtamp: igraet vazhnuyu rol")
    if (has("данный") || has("данного") || has("данном") || has("данную") || has("данная") || \
        has("Данный") || has("Данная")) warn("kantselyarit: dannyj (vmesto etot)")
    if (has("по сути") || has("По сути") || has("в конечном счёте") || has("в конечном счете") || \
        has("В конечном счёте") || has("если копнуть")) warn("psevdoglubina")
    if (has("давайте разберёмся") || has("давайте разберемся") || has("погрузимся") || \
        has("Давайте разберёмся")) warn("anons vmesto dela")
    if (has("может возразить") || has("вопреки распространённому") || has("вопреки распространенному") || \
        has("может показаться, что") || has("Может показаться, что")) warn("zashchita ot nevydvinutykh vozrazhenij")
    if (has("на момент написания") || has("На момент написания") || has("насколько известно") || \
        has("Насколько известно") || has("по состоянию на сегодня")) warn("disklejmer o granitsakh znanij")
    # pattern 45 (soft half): a second independent fact bolted on with a gerund
    if (line ~ /[0-9]/ && (wb("платя") || wb("давая") || wb("обеспечивая") || wb("показывая") || \
        wb("демонстрируя") || wb("снижая") || wb("повышая") || wb("увеличивая") || \
        wb("сокращая") || wb("принося") || wb("теряя") || wb("выигрывая"))) \
      warn("deeprichastie kak nositel fakta (pattern 45)")

    # pattern 44: a work stage sitting in the subject slot ("progon dal filtr")
    if ((wb("прогон") || wb("Прогон") || wb("разбор") || wb("Разбор") || wb("обход") || \
         wb("Обход") || wb("срез") || wb("Срез") || \
         wb("замер") || wb("Замер") || wb("расчёт") || wb("Расчёт")) && \
        (wb("дал") || wb("дала") || wb("показал") || wb("показала") || wb("выявил") || \
         wb("восстановил") || wb("подтвердил") || wb("обнаружил"))) \
      warn("protsess kak subjekt (pattern 44)")

    # pattern 43: closing clause with no number and nothing to check
    if (has("кривую компромисса") || has("кривой компромисса") || has("ложатся на одну") || \
        has("это уже вопрос") || has("дальше всё сводится") || has("дальше все сводится") || \
        has("сводится к балансу")) \
      warn("obobshchayushchij dovesok (pattern 43)")

    # pattern 47: the method opens the sentence instead of the result
    if (has("По прогону") || has("По замеру") || has("По расчёту") || has("По выгрузке") || \
        has("По итогам прогона") || has("По результатам замера") || has("В прогоне") || \
        has("В замере")) \
      warn("metod vperedi rezultata (pattern 47)")

    # pattern 48: a defect stated as an absence instead of a condition. Two uses
    # of the same wording are legitimate and get skipped: the line already names
    # the condition (the cure is present), or it is reporting a limit of the
    # research rather than a property of the system. On a real report those were
    # 6 of 9 hits, and the unguarded check taught the author to ignore it.
    p48ok = has("право, пока") || has("верно, пока") || has("работает, пока") || \
            has("Само по себе это правильно") || has("Проблема в том, что") || \
            has("в исследовании") || has("для продукта") || has("в промпте") || \
            has("замер не покрывал") || has("не входит в замер") || \
            has("не мерилось") || has("не мерили")
    if (!p48ok && (has("без проверки") || has("Без проверки") || has("без учёта") || \
        has("без всякой") || has("без всякого") || has("не проверяет") || \
        has("не проверяется") || has("не проверялось") || has("не проверялся") || \
        has("не проверялись") || has("не измерялась") || has("не измерялось"))) \
      warn("defekt opisan otsutstviem, nuzhno uslovie (pattern 48)")



    # pattern 49: an evaluation of quantity with no threshold to compare against
    if (has("этого мало") || has("этого много") || has("этого не хватает") || \
        has("слишком долго") || has("слишком мало") || has("слишком много") || \
        has("слишком часто") || has("а трёх мало") || has("а двух мало") || \
        has("не хватает совсем")) \
      warn("otsenka bez poroga (pattern 49)")

    # pattern 50: a raw internal identifier used in prose
    if (match(nline, /(тег|теге|тегу|тега|id|ID|номер|номере) [0-9][0-9][0-9][0-9][0-9]/)) \
      warn("syroj vnutrennij identifikator v proze (pattern 50)")

    # ceiling: three or more "share (N of M)" constructions in one paragraph
    tn = triples(line)
    if (tn > 0 && numline == 0) numline = FNR
    numacc += tn
    if (paraline == 0 && line !~ /^[ \t]*$/) paraline = FNR
    para = para " " line
    if (html || line ~ /^[ \t]*$/) flushpara()

    # ceiling: an enumeration longer than four homogeneous items in one sentence
    if (match(line, /([^ ,.:;!?()]+, ){3,}[^ ,.:;!?()]+ и /)) \
      warn("perechislenie dlinnee chetyryokh odnorodnykh - v spisok ili tablitsu")

    # invisible-shape rule: a heading named after a framework beat
    t2 = line
    gsub(/^[ \t]*#+[ \t]*/, "", t2)
    gsub(/^[ \t]+/, "", t2); gsub(/[ \t]+$/, "", t2)
    if (line ~ /^[ \t]*#+[ \t]/ && (t2 == "Контекст" || t2 == "Ситуация" || \
        t2 == "Действие" || t2 == "Результат" || t2 == "Проблема" || \
        t2 == "Решение" || t2 == "Потребность" || t2 == "Осложнение")) \
      warn("zagolovok po imeni takta - forma dolzhna ostavatsya nevidimoj")

    # Rule of three is a rhythmic crutch only when the three items are words, not
    # data: an enumeration carrying digits (model names, thresholds, ids) is a fact
    # list, and firing there taught authors to ignore every warning - 21 hits, all
    # false, on one long analytical report.
    if (line !~ /[0-9]/ && (match(line, /, [^ ,.:;!?()]+ и [^ .,!?]/) || \
        match(line, /, [^ ,.:;!?()]+ [^ ,.:;!?()]+ и [^ .,!?]/))) warn("pravilo tryokh (evristika: X, Y i Z)")

    buf = buf " " line
  }

  END {
    # --- rhythm metrics on the accumulated prose ---------------------------
    n = split(buf, sents, /[.!?]+/)
    total = 0; minw = 100000; run = 1; maxrun = 1; prev = -100
    afirst = ""; arun = 1; amaxrun = 1; aword = ""
    for (i = 1; i <= n; i++) {
      w = 0; first = ""
      m = split(sents[i], words, /[ \t]+/)
      for (j = 1; j <= m; j++) if (words[j] != "") { w++; if (first == "") first = words[j] }
      if (w < 3) continue                    # headers, list stubs, noise
      total++
      if (w < minw) minw = w
      d = w - prev; if (d < 0) d = -d
      if (d <= 2) { run++; if (run > maxrun) maxrun = run } else run = 1
      prev = w
      # anaphora: 3+ consecutive sentences opening with the same word (pattern 39);
      # skip list markers, digits and one-letter tokens
      if (length(first) >= 3 && first !~ /^[-*0-9#>]/) {
        if (first == afirst) { arun++; if (arun > amaxrun) { amaxrun = arun; aword = first } }
        else arun = 1
        afirst = first
      } else { afirst = ""; arun = 1 }
    }
    if (total >= 6 && minw > 8) {
      warns++
      printf "%s: WARN ritm: net ni odnogo korotkogo predlozheniya (do 8 slov) na %d predlozhenij\n", fname, total
    }
    if (maxrun >= 4) {
      warns++
      printf "%s: WARN ritm: %d predlozhenij podryad odnoj dliny (+-2 slova) - monotonnost\n", fname, maxrun
    }
    flushpara()                            # last paragraph, no trailing blank line

    # pattern 46: gloss attached to a later occurrence than the first bare use
    for (t in glossline) {
      if ((t in firstuse) && firstuse[t] < glossline[t]) {
        warns++
        printf "%s:%d: WARN termin \"%s\" raskryt pozzhe pervogo upotrebleniya (gloss na stroke %d) (pattern 46)\n", \
          fname, firstuse[t], t, glossline[t]
      }
    }
    if (amaxrun >= 3) {
      warns++
      printf "%s: WARN anafora: %d predlozhenij podryad nachinayutsya s \"%s\"\n", fname, amaxrun, aword
    }

    printf "lint-ru: %s - %d ban(s), %d warning(s)\n", fname, bans, warns
    if (bans > 0) exit 1
    if (strict && warns > 0) exit 1
    exit 0
  }' "$f" "$f"
  rc=$?
  set -e
  [ "$rc" -eq 0 ] || FAIL=1
done
exit $FAIL
