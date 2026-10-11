# TBQ preset (Teen Bible Quiz, 25-26)

<!-- OUTLINE (docs pass): type = REFERENCE. Facts only — a numbers table, no
     rulebook prose (church-use-only licence). Cite rule sections by number.

     ⚠️ BEFORE PUBLISHING: re-check every number below against
     docs/25-26_TBQ-Rules.pdf (stream with pdftotext; never commit extracts)
     and against assets/rulesets/tbq-25-26.json. The numbers below are the
     working values used by the app; they must match the preset exactly. -->

**Ruleset id:** `tbq-25-26` → [`assets/rulesets/tbq-25-26.json`](https://github.com/JosiahL06/Concordance/blob/main/assets/rulesets/tbq-25-26.json)

## Outline

- **Format** — 2 teams, 20 questions: eight 10-point, nine 20-point,
  three 30-point.
- **Answers** — correct: + full question value. Incorrect: − half the question
  value (30-pointer ⇒ −15).
- **Quiz out** — 5th correct answer ⇒ +20 bonus.
- **Strike out** — 3rd incorrect answer.
- **Fouls** — −5; 3 fouls ⇒ foul out. Coach / assistant / inactive-person fouls
  are assessed to the team (−5).
- **Time-outs** — the scorekeeper is notified at the limit; a 4th request is
  denied and penalised as a team foul (the app prompts, it does not auto-assess).
- **Contests** — recorded with success/failure; notified at the 3rd unsuccessful
  contest.
- **Substitutions & voids** — a substitute takes the voided question number.
- **Comparison table**: what changes vs JBQ (thresholds, bonus, question mix) —
  readers arriving from JBQ should see the differences at a glance.

!!! warning "Rulebooks govern"
    These are the numbers the preset encodes. The official TBQ rulebook is the
    authority; nothing on this page paraphrases it.
