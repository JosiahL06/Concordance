---
description: How to handle the copyrighted rulebooks, plus the scoring-rules quick reference that drives the engine and golden tests.
version: 1.0
tags: ["rulesets", "scoring", "copyright", "tbq", "jbq"]
---

# Rulebooks & Rulesets

**Objective:** Encode Bible Quiz scoring correctly and configurably while never infringing the rulebooks' copyright.

## ⚠️ Copyright constraints (hard rules)
- Source documents in `docs/` are © My Healthy Church, licensed **"for local church use only"**:
  - `docs/25-26_TBQ-Rules.pdf` — Teen Bible Quiz, 31 pages
  - `docs/2026-jbq-rules.pdf` — Junior Bible Quiz (Official Quiz Guidelines), 22 pages
- `docs/*.pdf` is gitignored. **Cline MUST NOT** commit the PDFs, commit long verbatim excerpts of their text, or put substantial rulebook prose into the repo (including README/comments/tests). Facts and numeric rules needed to implement scoring ARE fine; prose is not. Extracted text MUST go to `/tmp` only.
- Read them by streaming to stdout — no files created:
  ```sh
  pdftotext -layout docs/25-26_TBQ-Rules.pdf - | sed -n '174,215p'
  pdftotext -layout docs/2026-jbq-rules.pdf - | grep -n -i 'scoring' 
  ```

## Scoring quick reference (verify against the PDFs before encoding!)
Every number below MUST be re-checked against the rulebook when building the ruleset configs and golden tests — the rulebooks change per season and informal summaries have been wrong before (an early web-sourced summary of TBQ was flatly outdated).

**AG Teen Bible Quiz (TBQ 25-26)** — 2 teams per match, 20 questions: eight 10-pt, nine 20-pt, three 30-pt.
- Correct: **+full point value**; Incorrect: **−half** of the question's value.
- 5 correct → **quiz out, +20 bonus**; 3 incorrect → **strike out**; foul: **−5**, 3 fouls → **foul out**; coach/assistant/inactive fouls: **−5 to team**.
- Scorekeeper also records: interrupted questions, time-outs (notify on 4th), contests w/ success-failure (notify on 3rd unsuccessful).

**AG Junior Bible Quiz (JBQ 2026)**
- Correct: **+full value**; Incorrect: **−half**.
- 6 correct → **quiz out, +10 bonus, leaves match**; 3 incorrect → **strike out, leaves**; foul: **−5** (mark "F"), 3 fouls → **foul out**; other-person fouls: **−5 to team**.
- Scorekeeper records: time-outs (notify on 4th), **Coach's Appeals** (2 per team max).

## Engine contract
- Both rulebooks MUST be expressible purely through the ruleset config schema (see `.clinerules/architecture-and-conventions.md` decision 2) — if a rule cannot be expressed, extend the SCHEMA, never fork the engine.
- Golden unit tests MUST be derived directly from worked scenarios in the PDFs (e.g., "30-pointer answered wrong ⇒ −15"; "fifth correct answer ⇒ +30 then +20 quiz-out bonus").
