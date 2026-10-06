# Concordance — Ruleset Schema (v1)

Contract for `assets/rulesets/*.json`. Every field maps to a rule citation
(rule number / section, NOT prose — rulebook text is church-use-only licensed
and must never be quoted at length in the repo).

Two presets ship in v1: `tbq-25-26` and `jbq-2026`. New rulebooks = new JSON,
never engine forks.

## Decision log

- **D1 — events carry explicit `questionNumber`.** Classic view lets the
  keeper tap any cell and score a non-current question (out-of-order
  correction). Every scoring event therefore targets a question explicitly;
  the view supplies the current question as the default. Navigation alone
  (tapping a cell to look) is view state and is NOT journaled.
- **D2 — contests and Coach's Appeals unify as `challenge`.** Both are
  per-team corrective-procedure tallies with success/failure and a limit
  that triggers a scorekeeper notification.
- **D3 — fouls survive voiding.** Both books: assessed fouls remain even if
  the question is later voided. `voidQuestion` retracts answer points only.
- **D4 — void + substitute occupy the same slot.** A voided question is
  replaced by an equal-value substitute under the same number.
  Overtime questions append new slots.
- **D5 — all point values are even; integer math only.** No floats anywhere.
- **D6 — `currentQuestion` is view state.** The engine validates question
  range but does not track a pointer. The view owns the screen position.
- **D7 — substitutes APPEND; the out quizzer stays in the roster.** Points
  already scored keep counting toward the team total after a quizzer
  leaves, so the out quizzer remains in state (marked out/inactive) and
  the entrant is appended. One slot cannot spawn two entrants
  (`quizzer-already-replaced`).
- **D8 — challenge limits are PER TEAM, match-wide.** TBQ: a team's 3rd
  unsuccessful contest notifies; further contests by that team are then
  rejected (`challenge-team-limit`). JBQ: 2 Coach's Appeals per team, then
  rejected. The per-question cap (`challengesPerQuestionPerTeam`) is also
  counted per side.
- **D9 — all deductions come from the ruleset, never hard-coded.** Team
  fouls deduct `scoring.teamFoulDeduction` (was a literal ×5 — removed).
  Null-question fouls count toward the team total only; they are NOT
  attributed to any ledger cell (a ledger cell requires an explicit
  `questionNumber`).
- **D10 — answer guardrails are engine mechanics, not ruleset data.** A
  question slot admits at most one answer per quizzer, one answer per team,
  and one *correct* answer overall; a correct answer closes the question to
  both teams. Because an incorrectly answered question is re-read to the
  opposing team (TBQ Reading §13 / JBQ Reading §12; overtime TBQ OT §4 /
  JBQ OT §4), the only legal two-answer sequences are wrong+right or
  wrong+wrong — "at most two answers, at most one of them correct" falls out
  of those three checks. Both shipped books share these mechanics, so they
  live in the fold (`answerGuardrail`) like `inRange`, not in the ruleset
  JSON. A blocked answer is rejected (never journaled) and surfaced by the
  scoring console (disabled CORRECT/INCORRECT + reason). Voiding a question
  clears its answer ledger so the substitute reads fresh (D4).


## Schema fields

- `schemaVersion` (int, = 1), `id` (e.g. `tbq-25-26`), `displayName`,
  `season`, `challengeKind`: `contest` (TBQ) | `appeal` (JBQ).
- `match.regulationQuestions` = 20 (both books).
  `match.pointValues`: full 20-slot sequence; session may supply its own.
  TBQ Scoring §1: eight 10s, nine 20s, three 30s.
  JBQ Q-sets §2: ten 10s, seven 20s, three 30s (+ distribution rules
  §3a-d, validated at session setup, not per event).
  `match.minActivePerTeam` / `maxActivePerTeam`:
  TBQ Team §4: 1–3; JBQ Team §5: 2–4 (1 with approval — v1: min 1).
  `match.teamsPerMatch` = 2.
- `scoring.correctMultiplier` = 1.0, `incorrectMultiplier` = 0.5
  (both books Scoring §§1–3).
- `scoring.quizOut`: TBQ §2: 5 correct + 20 bonus, stays at table;
  JBQ §1: 6 correct + 10 bonus, must leave.
  `scoring.strikeOut.incorrectNeeded` = 3 both books
  (leavesMatch follows the book like quizOut).
- `scoring.foul`: deduction 5, foulsToFoulOut 3, teamDeduction 5

- `limits.timeOutsPerTeam` = 3 (both Time-outs §2) — the regulation cap.
  `notifyTimeOutRequest` = 4 (Scorekeeper duties: notify on the 4th request);
  because a 4th request is over the cap and therefore denied, the engine's
  state-derived notice is unreachable for these presets and the app raises the
  notification at the denied request instead (the request is an *attempt*, not
  state).
- `limits.overtimeTimeOutsCarry` / `overtimeExtraTimeOuts` define the overtime
  cap, resolved by `LimitsConfig.timeOutCap({inOvertime})`:
  - TBQ Time-outs §4: remaining time-outs "may not be used in overtime" and
    none are granted → `carry` false, `extra` 0 → **no** team time-out in
    overtime.
  - JBQ Time-outs §§4–5: remaining carry over *and* each team gets one more →
    `carry` true, `extra` 1 → overtime cap = 3 + 1 = 4.
  Both books declare a free one-minute time-out at the start of overtime; that
  is the Quizmaster's declaration, not a team time-out, so it is not counted.
  Overtime is detected as appended question slots beyond
  `match.regulationQuestions`.
- `limits.challengeLimit`: TBQ Scorekeeper §4: mode `unsuccessful`,
  count 3 (3rd unsuccessful contest); JBQ Scorekeeper §5: mode `used`,
  count 2 (allotment of 2 appeals exhausted).
  `challengesPerQuestionPerTeam`: TBQ Contesting §4: 2; JBQ null
  (per-match allotment only). `challengeAllotmentPerTeam`: TBQ null;
  JBQ §5: 2.
- `overtime.mode`: TBQ OT §§1–2 `suddenDeath10` (10-pt subs until broken);
  JBQ OT §§2–3 `threePlusSuddenDeath20` (one each of 10/20/30 random,
  then 20-pt sudden-death periods). `declaresReopenTimeout` true both
  (1-min reopen, Time-outs §4). `foulPartOfQuestion` true both
  (OT foul attaches to the question).
- `scorekeeper.circleInterrupted` true; `announceOrder`
  [second, first, others, final] (TBQ Closing §2 / JBQ Conclusion §3).

## Event list (journal = undo + persistence unit)

All scoring events carry `questionNumber` (D1). Rejection returns a
structured `RuleViolation`, never throws (views decide how to surface;
quizmaster may override reality — the journal records what was recorded).

| Event | Fields | Validates against |
|---|---|---|
| `answer` | q, team, quizzer, correct | quizzer active; q not voided w/o substitute; q in range; answer guardrails (D10: at most one answer per quizzer, one per team, one correct per question — a correct answer closes the slot) |
| `foul` | q?, team, quizzer? (null = team foul) | team/quizzer exists; foul-out derived, not blocked |
| `timeOut` | team | capped by `timeOutCap` (3 regulation; overtime: TBQ none, JBQ remaining +1); an over-cap request is rejected (not journaled) and the keeper assigns the resulting team foul themselves |
| `interruption` | q | q in range (marks only) |
| `challenge` | q, team, successful | per-question cap (TBQ) / allotment (JBQ) → violation, still recordable on override |
| `voidQuestion` | q | q in range (retracts answer points per D3) |
| `substituteQuestion` | q, value | q voided first (D4) |
| `substituteQuizzer` | team, outIndex, label | out quizzer out/inactive (immediate, no time-out) |
| `overtimeQuestion` | value | tie after regulation (append slot per D4) |

## View-model (`RoundView`, serves Modern + Classic)

Shared reads: `questionValues`, `scoreOf(team)`, per-quizzer
`score/correct/incorrect/fouls/status/active`, `selected` (view-local),
`canUndo/undoLabel`, notifications (quiz-out/strike-out/foul-out,
time-out/challenge limit warnings), per-question marks, timeouts taken,
foul/challenge aggregates.
Classic-only reads: `cellOutcome(q, n)`, `teamDelta(team, n)` (RUNNING),
overtime slots. Writes: the event list above (same for both views).

  (coach/inactive/other-person fouls), teamFoulLimit null
  (both Fouls intros: no team limit).
