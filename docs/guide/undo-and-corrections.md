# Undo & corrections

<!-- OUTLINE (docs pass): type = HOW-TO + a short explanation of *why* it is
     this way (the app is event-sourced, so undo is exact, not "approximately
     reverse"). Keep the theory brief and link the explanation page. -->

**Goal:** fix a mis-tap without disturbing anything else that has happened.

## To cover

- **Where Undo is** — prominent, always visible; ≥48 dp; never long-press-only.
- **What Undo does** — rewinds the most recent ruling *and* the screen position
  together, so the keeper is looking at the thing being undone.
- **What Undo does not do** — it never edits history; it retracts an event and
  re-evaluates derived state (scores, quiz-out/strike-out flags, notices).
  This is why undoing a quiz-out also removes the bonus.
- **Repeated undo** — how far back it goes (the whole round), and that it is
  safe because rounds are saved as a journal.
- **Correcting an old question** — the Classic ledger lets you navigate to a
  past question and score it; explain that the question number is carried with
  the ruling.
- **When *not* to undo** — voiding/contesting a question is a different
  procedure (link), not an undo.
- Screenshots: before/after pair showing scores and the notice changing.

## Related

- [Event-sourced scoring](../explanation/event-sourced-scoring.md)
- [Fouls, contests, interruptions & time-outs](fouls-contests-interruptions-timeouts.md)
