# Fouls, contests, interruptions & time-outs

**Goal:** record everything that happens besides a correct or incorrect answer.

## Interruptions

An **interruption** is when a quizzer buzzes in before the question has finished
being read. Record it with the **Interruption** button in the bottom console,
which marks the current question. On the question navigator, an interrupted
question gets a circle around its number — the same encircled mark the paper
scoresheet uses.

An interruption also changes what happens next: if an interrupted question is
answered wrong, it is read again to the other team and you stay on it rather
than moving on.

## Fouls

A foul takes five points off. There are two kinds:

- A **personal foul** is charged to one quizzer. Tap **FOUL**, then choose the
  quizzer. Their score shows an **F** beside it.
- A **team foul** is charged to the whole team — a coach's foul, for instance.
  Tap **FOUL** and choose the team option; no quizzer needs to be selected.

A third personal foul fouls that quizzer out. Fouls survive a void: if a
question is thrown out later, the fouls charged on it stay in place.

## Contests and Coach's Appeals

A **contest** (Teen Bible Quiz) or a **Coach's Appeal** (Junior Bible Quiz) is a
challenge to a ruling. Both are handled the same way in the app. Each team has a
button beside its name in the header — tap it and record whether the challenge
succeeded or failed, and that team's tally goes up.

The ruleset sets a limit, and the app tells you when a team reaches it: the
third unsuccessful contest in Teen Bible Quiz, or the second appeal in Junior
Bible Quiz. Once a team has used its allowance, further challenges from that
team are refused. See [Alerts](alerts.md).

## Time-outs

Each team's time-outs are counted separately. Use the red or green time-out
button beside that team's name; the count goes up by one. When a team reaches
the limit — three in the regulation part of a match — the app notifies you.

A request past the limit is refused rather than counted. The app then tells you
to assess the resulting team foul yourself, because the scorekeeper makes that
call, not the app.

Overtime works differently in each ruleset. In Teen Bible Quiz, no time-outs may
be taken. In Junior Bible Quiz, any time-outs a team has left carry over, plus
one extra.

## Voiding a question

If a question is thrown out and read again, use the void action in the **More**
menu. Voiding takes back the points from answers on that question and corrects
the affected quizzers' correct and incorrect counts, and it works out again
whether anyone's quiz-out or strike-out has changed as a result. It leaves the
fouls on that question alone. The replacement question keeps the same question
number and the same value.

## The marks, in one table

| Action | Where it is | Mark on the navigator | What it changes |
| --- | --- | --- | --- |
| Interruption | Console button | A circle around the number | A mark only; affects how a wrong answer is re-read |
| Personal foul | Console → **FOUL** → quizzer | An **F** by that quizzer's score | Five points off the quizzer; a third foul fouls them out |
| Team foul | Console → **FOUL** → team | No cell mark | Five points off the team total |
| Contest / Appeal | Button beside the team name | A slash on the question | Records success or failure and counts toward the team's limit |
| Time-out | Time-out button beside the team name | No mark | Adds one to that team's count; notifies at the limit |
| Void | **More** menu | The question is struck through | Takes back the answer points and re-checks quiz-out and strike-out; keeps fouls |

## Related

- [Question navigator](question-navigator.md)
- [TBQ preset](../rulesets/tbq.md) · [JBQ preset](../rulesets/jbq.md)
