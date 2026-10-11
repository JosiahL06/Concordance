# Score answers

<!-- OUTLINE (docs pass): type = HOW-TO, the core task of the app.
     This page is the busiest one in the wiki — it must be scannable:
     a short "the loop" section, then a table of every scoring action. -->

**Goal:** record what happened on a question, correctly and in one tap.

## To cover

- **The loop**, in three steps: 1) point value for this question → 2) which
  quizzer → 3) Correct or Incorrect. Say explicitly that value-then-answer is
  the order the console expects.
- **Point values** — where they come from (the ruleset), that 10/20/30 are
  TBQ's default spread, and how the value is changed (before scoring, not
  after — after is an undo + redo).
- **Correct vs Incorrect** — what each does to the team total and to the
  individual quizzer's count; the incorrect = −half rule is a *ruleset* fact,
  so state it once here and link to the ruleset page.
- **Which quizzer** — tapping the quizzer (seat) first vs the answer first;
  the interruption case (a quizzer buzzes before the question is finished).
- **When a quizzer quizzes out / strikes out** — the action is auto-detected
  and announced; the scorekeeper does not press anything extra (link Alerts).
- **Errors of input** — the "wrong quizzer" and "wrong value" recovery recipes
  (both are Undo + redo; do not invent a correction mode).
- A one-line note that each tap is written to disk immediately.
- Avoid documenting tabs/swipes (there are none) — the console is the only
  scoring surface, per the interaction spec.

## Related

- [Undo & corrections](undo-and-corrections.md)
- [Fouls, contests, interruptions & time-outs](fouls-contests-interruptions-timeouts.md)
