# Event-sourced scoring

This page explains the most important idea behind the app, in plain terms.

## The idea

A round is a list of the things that happened: a correct answer on question 7 by
the quizzer in seat 3, a foul on question 9, a time-out for the Red team. The
scores, the quiz-out flags, and the notices are all worked out *from* that list.
The list is the truth; the numbers on the screen are a summary of it.

## Why undo is exact

Because the scores are worked out from the list, undoing something means taking
it out of the list and working the scores out again. There is no guesswork about
how much to subtract to put things back. If you undo a correct answer that had
quizzed a quizzer out, the bonus was only ever there because of that answer, so
it disappears with it and the quizzer's totals come out right again.

## Why a crash never loses data

The list is written down as it grows. If the app closes unexpectedly, opening it
again reads the list back and works out the very same scores, on the very same
question. Everything that was on the screen is still there.

## Why the scoresheet marks come so naturally

Interruptions, contests, fouls, and voids are just more items in the list.
Because the app already knows what happened on every question, drawing the
paper-like marks on the navigator is simply a matter of reading the list back.

## What this is not

The app does not store a running total and nudge it up and down. It stores what
happened and works the total out. Undo is not "editing history" either: the list
is a record of what you recorded, and undo removes the most recent entry.

## Where to go next

If you only want to know what to do when you make a mistake, read
[Undo & corrections](../guide/undo-and-corrections.md). For the technical
description aimed at people working on the code, see the design notes.

## Related

- [Undo & corrections](../guide/undo-and-corrections.md)
- [Screens & interaction design](../design/interaction.md)
