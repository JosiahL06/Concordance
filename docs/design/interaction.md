# Concordance — Interaction Spec (Phase 1 → Phase 3 contract)

Tap-flow contract for the live-scoring prototype. Describes what the
built screens DO (verified against `lib/prototype/`); Phase 3 replaces
`FakeRound` with the engine + `RoundView` without changing these flows.

## 1. Navigation graph

`PrototypeHome` → `SetupScreen(demo: false|true)` → `DirectionAScreen`
or `DirectionBScreen` → `SummaryScreen(round)`.

- Home has START A NEW ROUND (fresh, Q1 zeros) and "Load demo round
  (mid-match)" (seeded Q13-in-progress, same ruleset logic as live play).
- Both go through setup so ruleset tabs + view pick are in every flow.
- Setup `_start` pushes the chosen live screen; Summary pushes on top of
  the live screen; Summary "Done" pops until the first route (home).
- System back from a live screen returns to setup; the round object is
  discarded (Phase 3: autosave makes this a resume instead).
- Production home's "Resume round" list each row taps to resume and carries a
  delete affordance that first asks for confirmation (a mis-tap must not lose
  a round silently).
- A live screen's header carries a back button that returns to the starting
  screen (Home); every ruling autosaves, so leaving mid-match is safe and the
  round resumes from Home.

## 2. Global principles (locked)

≥48dp touch targets; one-tap scoring; the bottom console is the ONLY
scoring entry point; Classic ledger cells navigate, never score;
undo rewinds the screen position; static banners only (no animation);
red/green light tints (`#FCE8E6` / `#E6F4EA`); tabular figures for scores.

## 3. Setup flow (`setup_screen.dart`)

- Ruleset tabs in the AppBar load the REAL presets
  (`assets/rulesets/tbq-25-26.json`, `jbq-2026.json`); tab switch updates
  the details card: N questions + value sequence, quiz/strike/foul-out
  chips, time-out + contest/appeal limits. Load failure shows an error
  state with Retry (Start disabled until presets load).
- Team name fields (default Red/Green; blank falls back to the default).
- Roster steppers clamp to the preset's `maxActivePerTeam`
  (min `min(1, 3)`); seat chips read "<Team> 1..N" with add/remove
  (remove hidden at count 1).
- View pick cards: Modern ("Split-field team halves") vs Classic
  ("Paper-style scoresheet ledger"). Start button label is dynamic:
  "START ROUND" fresh, "START DEMO ROUND" demo (demo shows a banner:
  a Q13-in-progress match is loaded; JBQ shows no quiz-out chip because
  its threshold is 6 — proof thresholds come from the preset).

## 4. Live scoring — shared console contract

Applies identically to Modern `_scoringZone` and Classic `_console`.

| Tap | Source | FakeRound → future engine event | Result |
|---|---|---|---|
| Quizzer card / label cell | team half / ledger label | `select` (view-local, NOT journaled; no-op on inactive; re-tap deselects) | Enables CORRECT / INCORRECT / quizzer FOUL |
| CORRECT | console (needs selection) | `markCorrect` → `AnswerEvent(q, side, index, correct)` | `+value`; correct++; quiz-out check (5/TBQ, 6/JBQ) adds bonus + flag + alert; advances to next Q, clears selection, repaints immediately; forbidden by the D10 guardrails (console disables the button + shows the reason) when the quizzer or their team already answered Q, or Q already has a correct answer |
| INCORRECT | console (needs selection) | `markIncorrect` → `AnswerEvent(..., incorrect)` | `−value~/2`; strike-out at 3; clears selection, repaints; same D10 guardrails. Advances to the next Q EXCEPT when the current question is interrupted — an incorrect interrupted question is re-read to the other team, so the keeper stays on it |
| FOUL | console → dialog (quizzer foul vs team foul) | `addQuizzerFoul` / `addTeamFoul` → `FoulEvent(q, side, index?)` | `−foulDeduction` (ruleset, D9); foul-out at 3; team foul hits team total only, never a ledger cell (D9); stays on Q, clears selection, repaints. Quizzer fouls show as an `F` badge beside the score mark, never replacing it; team fouls have a `TEAM FOUL n` header button beside each team name |
| RED/GRN TO (Modern header / Classic ledger rail) | time-out controls | `takeTimeOut` → `TimeOutEvent(side)` | capped by `LimitsConfig.timeOutCap`: 3 in regulation; in overtime TBQ allows none (remaining may not be used) and JBQ allows remaining +1. Over-cap requests are denied (not journaled) and the keeper is told to assign the resulting team foul — the app never auto-fouls. Counters read `taken/displayCap`. The old shared bottom-bar duplicates were removed in the polish pass |
| Interruption | bottom bar toggle | `toggleInterruption` → `InterruptionEvent(q)` | toggles ring on current Q (marks only) |
| gavel (Contest / Appeal) | per-team header button beside the team name → outcome dialog | `recordChallenge` → `ChallengeEvent(q, side, successful)` | per-team match-wide tallies (D8) shown beside each team name like time-outs; 3rd-unsuccessful (TBQ) / exhausted (JBQ) alert; over-limit rejected. The old footer gavel button was removed in the polish pass — the header buttons are the only entry point |
| UNDO — label | bottom bar (disabled when empty) | `undo` → journal pop + re-fold | restores scores/cells/question/completion/alert exactly |
| Ledger cell (Classic) | grid tap | `jumpToQuestion` (view state, D6/D1) | moves screen position and selects the quizzer; the intersect of selection × current question highlights; scoring there targets that Q explicitly |
| Summary | bottom bar (enabled only at match complete) + end-of-round strip | — (navigation) | pushes `SummaryScreen(round)` |

Console hint line states the contract: "TAP A QUIZZER, THEN CORRECT /
INCORRECT / FOUL — TEAM FOUL NEEDS NO SELECTION. CORRECT / INCORRECT
ADVANCE; FOUL STAYS.".

The console enforces D10 proactively: when the selected quizzer cannot
answer the current question under the guardrails, CORRECT/INCORRECT are
disabled and the status line reads `BLOCKED — <reason>` (FOUL stays live —
a foul is not an answer). This includes a miss on a non-interrupted
question, which is not reread and therefore closes the question to the
opposing team; only an interrupted miss reopens it.

## 5. Modern specifics (`direction_a_screen.dart`)

Split field: red left / green right, team band (live total) + quizzer
cards (score, C/I/F counts, status chip) + TAP TO SCORE affordance on the
selected card. `QuestionNavigator` strip below the console is position
display with paper marks (interruption ring, contest "C", void strike).
`matchComplete` swaps the console for: result text + "Add overtime
question" (tie only) + "View summary".

## 6. Classic specifics (`direction_b_screen.dart`)

Ledger grid geometry: 20×48 + 140 label + 64 total = 1164dp, fits 1280
(shrinks only for overtime columns). Title row per team: name, `TEAM FOUL n`
and contest/appeal header buttons with tallies (unsuccessful/used challenges
+ limit; personal fouls are per-quizzer, on the cells), live score. Quizzer rows: tappable 48dp cells
showing `+value` / `−half` (personal fouls add an `F` badge beside the mark,
never replacing it; foul-only cells show a bare `F`) with contest/interruption rings;
interrupted questions also ring the column header; selected quizzer × current
question intersect highlights. RUNNING
row = signed per-question team delta (empty cells "·"). Vertical TIME OUT
1/2/3 rail per team. Same console + bottom bar as Modern (Summary gated until
the match completes; More menu guards void/substitute state).

## 7. Alerts, limits, overtime

- `AlertBanner` shows `lastAlert` until dismissed (dismiss is view state,
  not journaled). Fired by: quiz/strike/foul-out, 4th time-out request,
  3rd unsuccessful contest (TBQ), appeals exhausted (JBQ), tie after Q20.
- After Q20: leader → match complete; tie → needs-overtime alert.
  "Add overtime question" appends the engine-defined value (TBQ: 10-pt
  sudden death; JBQ: 10/20/30 then 20s) and re-opens scoring.
- PROTOTYPE GAPS (engine already supports; Phase 3 adds UI): void /
  substitute question and quizzer substitution have no entry points yet.

## 8. Summary (`summary_screen.dart`)

Result banner (WINNER/TIE + tabular score + ruleset/demo tag), team cards
(score, time-outs, challenges, per-quizzer breakdown), individual results
table, question-by-question review (cells + INTERRUPTED/CONTESTED tags),
PDF/CSV buttons show "available in the full app" (prototype-inert),
Done returns home.
