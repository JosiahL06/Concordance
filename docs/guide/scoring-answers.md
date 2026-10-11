# Score answers

**Goal:** record what happened on a question, correctly and with one tap.

## The loop

Every answer follows the same three steps, in this order:

1. **Set the value** for the question — **10**, **20**, or **30**.
2. **Tap the quizzer** who answered.
3. **Tap CORRECT** or **INCORRECT**.

The console expects that order. Until a question has a value and a quizzer selected,
the CORRECT and INCORRECT buttons stay switched off.

## Setting the value

The app does not guess what each question is worth — it asks you. Tap the value
row under the question numbers, or the **SET VALUE** button at the top of the
screen, and choose **10**, **20**, or **30**. The value row works the same way
on both live screens.

Teen Bible Quiz questions are a mix of ten-point, twenty-point, and thirty-point
questions; Junior Bible Quiz has its own mix. The ruleset decides how many of
each there are.

You set the value *before* scoring. Once a question has been answered, its value
locks, because changing it afterwards would change a score already given. If you
set the wrong value, undo the answer first and set it again.

If a value breaks a rule of the ruleset — a thirty-point question at the start
of a Junior Bible Quiz match, for example — the app shows a notice, but it never
stops you. See [Alerts](alerts.md).

## Correct and incorrect

Select a quizzer first, then tap:

- **CORRECT** adds the question's full value to the team total and to that
  quizzer's own score. The app then moves on to the next question.
- **INCORRECT** takes away half the question's value — a thirty-point question
  answered wrong is −15. This is the rulebook's rule, and it is the same in both
  built-in rulesets; see [Rulesets](../rulesets/index.md). The app also moves on
  to the next question, *unless* the question was interrupted, in which case it
  is read again to the other team and you stay on it.

Three incorrect answers strike a quizzer out.

## Choosing the quizzer

Tap a quizzer's card (Modern) or the label beside their row (Classic) to select
them. The selected quizzer is highlighted, and the **CORRECT**, **INCORRECT**,
and **FOUL** buttons come alive. Tap the quizzer again to deselect. Tapping a
quizzer who is not at the table does nothing.

## When the app will not let you score

Some answers do not make sense on a given question — a second correct answer on
the same question, for instance, or two answers from the same team. When that
happens, the **CORRECT** and **INCORRECT** buttons switch off and a line under
the console explains why. A foul is always allowed, because a foul is not an
answer.

## When a quizzer quizzes out or strikes out

You do nothing extra. When a quizzer reaches the ruleset's number of correct
answers — five in Teen Bible Quiz, six in Junior Bible Quiz — the app adds the
quiz-out bonus for you and shows a notice. The same is true of a third incorrect
answer and a third foul. See [Alerts](alerts.md).

## Fixing a mistake

If you tapped the wrong quizzer or the wrong button, tap **UNDO** and enter the
right one. Undo takes back only the most recent ruling. See
[Undo & corrections](undo-and-corrections.md).

## Saving

There is nothing to save. Each tap is written to the tablet the moment you make
it. See [Autosave & recovery](autosave-and-recovery.md).

## Related

- [Undo & corrections](undo-and-corrections.md)
- [Fouls, contests, interruptions & time-outs](fouls-contests-interruptions-timeouts.md)
