# Concordance — Screens & Interaction Spec

Tap-flow contract for the shipped app (`lib/views/`). Describes what each
screen does; the live views are thin layouts over the shared engine view-model
(`RoundView`), so the flows below are the same for both.

## 1. Navigation graph

`HomeScreen` → `SetupScreen` → `ModernScreen` or `ClassicScreen` →
`SummaryScreen`.

- Home starts a new round or resumes a previously saved one.
- Setup picks the ruleset, teams, quizzers, and live-view variant, then pushes
  the chosen live screen; Summary is pushed on top of the live screen and its
  "Done" pops back to Home.
- Home's "Resume round" list: each row resumes a saved round and carries a
  delete affordance that asks for confirmation first (a mis-tap must not lose a
  round silently).
- A live screen's header carries a back button that returns to Home; every
  ruling autosaves, so leaving mid-match is safe and the round resumes from Home.

## 2. Global principles (locked)

≥48dp touch targets; one-tap scoring; the bottom console is the ONLY
scoring entry point; an empty Classic ledger cell navigates/selects, while a
cell holding a recorded answer opens that answer's editor; undo rewinds the
screen position; static banners only (no animation);
red/green light tints (`#FCE8E6` / `#E6F4EA`); tabular figures for scores.
Silent by default: the app never plays audio (all Material
`enableFeedback` paths are disabled) and haptics are opt-in/off-by-default,
so a fresh install cannot distract an official match; live screens also cap
OS text scaling at 1.3× to protect the no-scroll layout.

## 3. Setup flow (`lib/views/setup_screen.dart`)

- Ruleset tabs in the AppBar load the REAL presets
  (`assets/rulesets/tbq-25-26.json`, `jbq-2026.json`); tab switch updates
  the details card: N questions + value distribution, quiz/strike/foul-out
  chips, time-out + contest/appeal limits. Load failure shows an error
  state with Retry (Start disabled until presets load).
- Ruleset pick is an ordinary in-body settings row (segmented control),
  not an AppBar tab bar.
- Team name fields (default Red/Green; blank falls back to the default),
  plus a per-quizzer name field for every seated AND bench quizzer. A blank
  field falls back to "<Team> N"; quizzers are named independently of the
  team name.
- Roster steppers: "Seated" clamps to the preset's `maxActivePerTeam`
  (min `minActivePerTeam`); "Bench" clamps to `maxRosterPerTeam - seated`
  (uncapped when the book sets no roster max). Bench quizzers are named the
  same way and start behind the table.
- View pick cards: Modern ("Split-field team halves") vs Classic
  ("Paper-style scoresheet ledger"). Start button reads "START ROUND".

## 4. Live scoring — shared console contract

Applies identically to Modern and Classic.

| Tap | Source | Engine event | Result |
|---|---|---|---|
| Quizzer card / label cell | team half / ledger label | `select` (view-local, NOT journaled; no-op on inactive; re-tap deselects) | Enables CORRECT / INCORRECT / quizzer FOUL |
| CORRECT | console (needs selection) | `markCorrect` → `AnswerEvent(q, side, index, correct)` | `+value`; correct++; quiz-out check (5/TBQ, 6/JBQ) adds bonus + flag + alert; advances to next Q, clears selection, repaints immediately; forbidden by the D10 guardrails (console disables the button + shows the reason) when the quizzer or their team already answered Q, or Q already has a correct answer |
| INCORRECT | console (needs selection) | `markIncorrect` → `AnswerEvent(..., incorrect)` | `−value~/2`; strike-out at 3; clears selection, repaints; same D10 guardrails. Advances to the next Q EXCEPT when the current question is interrupted — an incorrect interrupted question is re-read to the other team, so the keeper stays on it |
| FOUL | console → dialog (quizzer foul vs team foul) | `addQuizzerFoul` / `addTeamFoul` → `FoulEvent(q, side, index?)` | `−foulDeduction` (ruleset, D9); foul-out at 3; team foul hits team total only, never a ledger cell (D9); stays on Q, clears selection, repaints. Quizzer fouls show as an `F` badge beside the score mark, never replacing it; team fouls have a `TEAM FOUL n` header button beside each team name |
| RED/GRN TO (Modern header / Classic ledger rail) | time-out controls | `takeTimeOut` → `TimeOutEvent(side)` | capped by `LimitsConfig.timeOutCap`: 3 in regulation; in overtime TBQ allows none (remaining may not be used) and JBQ allows remaining +1. Over-cap requests are denied (not journaled) and the keeper is told to assign the resulting team foul — the app never auto-fouls. Counters read `taken/displayCap`. The old shared bottom-bar duplicates were removed in the polish pass |
| Interruption | bottom bar toggle | `toggleInterruption` → `InterruptionEvent(q)` | toggles ring on current Q (marks only) |
| VOID QUESTION | bottom bar (enabled when the current question has a value) or the question editor | `voidQuestion` → `VoidQuestionEvent(q, substituteValue)` | retracts the slot's answers, leaves fouls standing (D3), and immediately reopens it as a substitute question at the same value (D4). One Undo restores the original ruling because one event carries both effects. On an already-voided question the editor offers VOID QUESTION AGAIN, which clears the current substitute answers at the same value |
| gavel (Contest / Appeal) | per-team header button beside the team name → outcome dialog | `recordChallenge` → `ChallengeEvent(q, side, successful)` | per-team match-wide tallies (D8) shown beside each team name like time-outs; 3rd-unsuccessful (TBQ) / exhausted (JBQ) alert; over-limit rejected. The old footer gavel button was removed in the polish pass — the header buttons are the only entry point |
| UNDO — label | bottom bar (disabled when empty) | `undo` → journal pop + re-fold | restores scores/cells/question/completion/alert exactly |
| Ledger cell (Classic) | grid tap | `jumpToQuestion` + `selectIfNeeded` (view state, D6/D1) for an empty cell; `changeAnswer` / `removeAnswer` for a marked cell | empty: moves screen position and selects/keeps the quizzer without toggling (the intersect of selection × current question highlights); marked: opens the answer editor. A change replaces the answer in its original journal slot; a removal returns to that Q with the quizzer selected so the corrected ruling can be recorded |
| Summary | bottom bar (enabled only at match complete) + end-of-round strip | — (navigation) | pushes `SummaryScreen(round)` |

**Direct correction (Classic).** A marked answer cell opens a compact editor
with `MARK CORRECT` / `MARK INCORRECT` and `REMOVE RULING`; the edit replaces
or removes the `AnswerEvent` at its original journal position, then refolds.
An answered, interrupted, or voided question header opens the question editor
(value change — including after an answer — voiding an answered question,
voiding a voided question again, or removing an interruption or void). A normal
unanswered header keeps the quick value picker. When a correction invalidates
later actions (for example, removing an interruption that enabled a re-read),
the editor lists exactly those actions and asks once before removing them. A
static `UNDO EDIT` strip restores the journal from before the edit until the
next normal scoring action. Time-outs, contests, fouls, and substitutions still
use Undo rather than direct editing. There is no separate "remove substitute
question" action: the substitute value belongs to the void, and voiding again
clears any answers on the current substitute read.

The bottom bar is the direct-action row: **Undo · Interruption · Void question ·
Substitute quizzer · Summary**. There is no More overflow; the old separate
"Read substitute question" entry point is gone because a void always re-reads at
the same value.

Console hint line states the contract: "TAP A QUIZZER, THEN CORRECT /
INCORRECT / FOUL — TEAM FOUL NEEDS NO SELECTION. CORRECT / INCORRECT
ADVANCE; FOUL STAYS.".

The console enforces D10 proactively: when the selected quizzer cannot
answer the current question under the guardrails, CORRECT/INCORRECT are
disabled and the status line reads `BLOCKED — <reason>` (FOUL stays live —
a foul is not an answer). This includes a miss on a non-interrupted
question, which is not reread and therefore closes the question to the
opposing team; only an interrupted miss reopens it.

D11 is a required next step rather than an error: when a quizzer is selected on
a question whose value is still unset, the console replaces CORRECT/INCORRECT
with three large value buttons (`10 PTS` / `20 PTS` / `30 PTS`). Choosing one
sets the value and immediately restores the ruling buttons with the new point
delta. The status line reads `... ON Qn — CHOOSE THE POINT VALUE`; the header
`SET VALUE` button and navigator value row remain available as alternate entry
points.

## 5. Modern specifics (`lib/views/modern_screen.dart`)

Split field: red left / green right, team band (live total) + quizzer
cards (score, C/I/F counts, status chip) + TAP TO SCORE affordance on the
selected card. `QuestionNavigator` strip below the console is position
display with paper marks (interruption ring, contest "C", void strike), with
a **point-value sub-row** beneath the numbers (D11): each value cell opens
the shared value dialog — tap it to set that question's 10/20/30 value. A
regulation question starts unset ("set") and cannot be scored until a value is
assigned; the value locks once the question is answered, and overtime/voided
slots read out only. The live header's `CurrentValueButton` (`N PTS` / a
prominent `SET VALUE` while unset) opens the same value dialog for the current
question. Bench quizzers appear as compact cards along the team's bench row.
`matchComplete` swaps the console for: result text + "Add overtime
question" (tie only) + "View summary".

**Small menus.** Contest outcome, foul assignment, and point-value selection
all use the same compact rounded dialog shell as the substitution board:
strong title, icon-led option cards, 48dp targets, and the live 1.3x text cap.
Point-value cards show large numeric values with hover and press feedback, and
the Classic question editor uses those same cards instead of pill buttons. The
console's CORRECT / INCORRECT / FOUL labels use the same large bold type as the
console value buttons.

**Quizzer identity.** Every seated row/card carries a small team-tinted
`RED n` / `GREEN n` title pill beside the quizzer's name. The badge uses the
pale team tint with team-colored text and border; the name is bolder and is the
identity. A substitution transfers the title badge to the entrant while both
names stay with their quizzers.

## 6. Classic specifics (`lib/views/classic_screen.dart`)

Ledger grid geometry: 20×48 + 140 label + 64 total = 1164dp, fits 1280
(shrinks only for overtime columns). Title row per team: name, `TEAM FOUL n`
and contest/appeal header buttons with tallies (unsuccessful/used challenges
+ limit; personal fouls are per-quizzer, on the cells), live score. Quizzer rows: tappable 48dp cells
showing `+value` / `−half` (personal fouls add an `F` badge beside the mark,
never replacing it; foul-only cells show a bare `F`) with contest/interruption rings;
interrupted questions also ring the column header; selected quizzer × current
question intersect highlights. Each **column header** carries the question's
point value under its number (D11). A normal unanswered slot opens the quick
value picker; an answered, interrupted, or voided slot opens the question
editor (value change, void or void-again, interruption removal, or void
removal).
A **BENCH** row lists a team's bench quizzers below its rows as compact
content-sized cards (bench `B` badge, bold name, running total, out status when
applicable), scrolling horizontally only when the bench is long. Vertical TIME
OUT 1/2/3 rail per team. The
ledger sizes its rows to the screen (no scrolling mid-game). Same console +
bottom bar as Modern (Summary gated until the match completes; the footer's
VOID QUESTION button acts on the current question and the answered-question
editor exposes the same action).

## 7. Alerts, limits, overtime

- `AlertBanner` shows `lastAlert` until dismissed (dismiss is view state,
  not journaled). Fired by: quiz/strike/foul-out, 4th time-out request,
  3rd unsuccessful contest (TBQ), appeals exhausted (JBQ), tie after Q20,
  and a broken question-set value stipulation (D12: value totals, a 30 at an
  end, consecutive 30s, or a half short of its 20/30 minimum — JBQ). A value
  notice fires once when the offending value is entered and re-arms on undo;
  nothing is ever blocked.
- After Q20: leader → match complete; tie → overtime question is appended
  automatically (TBQ: 10-pt sudden death; JBQ: 10/20/30 then 20s) with a
  notice and scoring re-opens.
- All notices (save failures, last-edit undo, the transient `AlertBanner`, the
  persistent substitution prompt, and the end-of-round strip) render in one slot
  directly above the scoring console, so a notice always appears in the same
  prominent place.
- Substitution is one **swap board**, not two dialogs. The footer's
  "Substitute quizzer" button opens a centered surface with Red/Green team tabs,
  an **At the table** column and a **Bench** column. Tap the outgoing seated
  quizzer, then an eligible bench quizzer; a live summary reads
  `Alice (seat 1) → bench · Carol → seat 1`, and a single confirm button applies
  the swap. Ineligible bench quizzers stay visible but dimmed with their status,
  and empty states cover no bench / no eligible bench. The entrant takes the
  outgoing quizzer's **seat**, so the seated order is unchanged apart from the
  swap (`SubstituteQuizzerEvent` carries stable `outIndex` + `benchIndex`). The
  rotated-out quizzer sits on the bench with their running total, and the export
  lists a Position column.
- A seated quizzer who quizzes out while their team has an eligible bench
  quizzer raises a **persistent substitution prompt** in the notice slot:
  `Red bench ready: Carol (30 pts) can replace Red 2. [SUBSTITUTE] [×]`.
  It survives later transient alerts until the keeper substitutes, dismisses it,
  or undoes the quiz-out. While it is visible it replaces the duplicate quiz-out
  alert for that quizzer; dismissing it clears both. `SUBSTITUTE` opens the swap board with the team locked
  and the outgoing quizzer preselected; the keeper only picks the entrant and
  confirms. If no eligible bench exists, no prompt is shown.

## 8. Summary (`lib/views/summary_screen.dart`)

Result banner (WINNER/TIE + tabular score + ruleset tag), team cards
(score, time-outs, challenges, per-quizzer breakdown), individual results
table, question-by-question review (cells + INTERRUPTED/CONTESTED tags),
PDF/CSV export buttons (share sheet via `share_plus`), Done returns home.
