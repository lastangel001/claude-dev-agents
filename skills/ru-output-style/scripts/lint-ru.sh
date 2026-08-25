#!/usr/bin/env bash
# lint-ru.sh — deterministic AI-slop linter for Russian prose (ru-output-style skill).
#
# Checks generated Russian text against the skill's hard bans (exit 1 on any hit)
# and warns on the soft markers (AI-lexicon frequency, rule-of-three, monotone
# sentence rhythm). Deterministic on purpose: a regex catches a long dash with
# 100% recall where model self-review does not.
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
      -v bom="$BOM" '
  function ban(code)  { bans++;  printf "%s:%d: BAN  %s\n", fname, FNR, code }
  function warn(code) { warns++; printf "%s:%d: WARN %s\n", fname, FNR, code }
  # Both case variants checked where a sentence can start with the marker.
  function has(s) { return index(line, s) }

  BEGIN { bans = 0; warns = 0; buf = "" }

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
    if (match(line, /, [^ ,.:;!?()]+ и [^ .,!?]/) || \
        match(line, /, [^ ,.:;!?()]+ [^ ,.:;!?()]+ и [^ .,!?]/)) warn("pravilo tryokh (evristika: X, Y i Z)")

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
    if (amaxrun >= 3) {
      warns++
      printf "%s: WARN anafora: %d predlozhenij podryad nachinayutsya s \"%s\"\n", fname, amaxrun, aword
    }

    printf "lint-ru: %s - %d ban(s), %d warning(s)\n", fname, bans, warns
    if (bans > 0) exit 1
    if (strict && warns > 0) exit 1
    exit 0
  }' "$f"
  rc=$?
  set -e
  [ "$rc" -eq 0 ] || FAIL=1
done
exit $FAIL
