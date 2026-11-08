# Undo & corrections

**Goal:** fix a mis-tap without disturbing anything else that has already
happened.

## Where Undo is

Undo is a large button in the bottom console, on both live screens. It is always
on screen, never hidden behind a long press, and its label tells you what it is
about to take back — for example, *UNDO — Red 2 correct*.

## What Undo does

Undo rewinds the most recent ruling. Two things happen together:

- The ruling is taken back, and the scores, the quizzer's counts, and any
  notices are worked out again from what is left.
- The screen moves back to the question that ruling belonged to, so you are
  looking at the thing you are changing.

Undo is exact, not approximate. If you undo a correct answer that had quizzed a
quizzer out, the quiz-out bonus goes away along with it, because the bonus only
ever came from that answer. See
[Event-sourced scoring](../explanation/event-sourced-scoring.md) for why.

## Going further back

Undo is not limited to the last tap. Press it again to step back one ruling at a
time, right to the start of the round. Every ruling is kept in the round's saved
history, so there is nothing you can spoil by going back.

## Correcting an older question

On the Classic screen, tap a cell that already holds an answer to edit it:
**MARK CORRECT** / **MARK INCORRECT** changes the ruling in place, and **REMOVE
RULING** clears it and puts you back on that question with the quizzer selected,
ready to record the corrected ruling. Tapping an empty cell only moves you there.

Tap a question's header number to edit the question itself: change its value,
void an answered question, remove an interruption, or remove a void/substitute.
The app keeps the correction in its original place in the round history, so
later re-reads and substitutions still line up. If a correction would invalidate
later actions, it lists exactly which ones before removing them.

After any of these edits, an **UNDO EDIT** strip appears. It puts the round back
the way it was before the edit, and it disappears once you record the next normal
ruling. If you only need to step back one ruling, the regular **Undo** button
still does that.

## When not to use Undo

Undo takes back a *ruling*. It is not the way to throw out a question or to
handle a contest — those have their own actions and buttons. If a question is
voided and read again, that is a void, not an undo. See
[Fouls, contests, interruptions & time-outs](fouls-contests-interruptions-timeouts.md).

## Related

- [Event-sourced scoring](../explanation/event-sourced-scoring.md)
- [Fouls, contests, interruptions & time-outs](fouls-contests-interruptions-timeouts.md)
