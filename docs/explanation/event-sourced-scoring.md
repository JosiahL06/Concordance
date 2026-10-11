# Event-sourced scoring

<!-- OUTLINE (docs pass): type = EXPLANATION.
     Explains the single most important engineering decision in the app in
     plain language: rulings are recorded as events, and the scoreboard is
     *derived* by replaying them. Then explain the user-visible consequences:
     exact undo, crash-proof resume, auditable history, and why corrections
     re-evaluate notices instead of patching numbers. -->

## Outline

- **The idea** — a round is a list of things that happened (a correct answer on
  question 7 by seat 3, a foul on question 9, a time-out). Scores, quiz-out
  flags and alerts are *computed* from that list, never stored as the truth.
- **Consequence 1 — undo is exact.** Undoing removes the event and recomputes;
  there is no "subtract the same number again" guesswork, so a quiz-out bonus
  disappears together with the answer that caused it.
- **Consequence 2 — a crash costs nothing.** The list is written to disk as it
  happens; reopening replays it and lands on exactly the same screen.
- **Consequence 3 — rules stay testable.** Because the engine folds events
  without knowing about screens, rule scenarios are unit-tested against the
  rulebooks (this is where the golden tests come from).
- **Consequence 4 — the paper-sheet marks fall out naturally.** Interruptions,
  contests, fouls and voids are all just events with marks.
- **What this is not** — it is not a database of totals, and undoing is not
  "editing history": the journal keeps what actually happened.
- Keep it to ~400 words; the audience is a curious volunteer or new
  contributor, not an engineer reading an architecture doc (that content lives
  in the design notes).

## Related

- [Undo & corrections](../guide/undo-and-corrections.md)
- [Screens & interaction design](../design/interaction.md)
