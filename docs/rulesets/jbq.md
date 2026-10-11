# JBQ preset (Junior Bible Quiz, 2026)

**Ruleset id:** `jbq-2026` → [`assets/rulesets/jbq-2026.json`](https://github.com/JosiahL06/Concordance/blob/main/assets/rulesets/jbq-2026.json)

Junior Bible Quiz is one of the two rulesets built into Concordance. This page
lists the numbers it uses to keep score.

## The match

- **Two teams.**
- **Twenty questions**: ten worth 10 points, seven worth 20, and three worth
  30.
- **Seated quizzers**: at least one and at most four per team, with up to eight
  quizzers on a team's roster in total.
- The rulebook also fixes where the values may fall — no 30-point question at
  either end of the match, none back to back, and at least three 20s and one 30
  in each half. The app shows a notice if a value breaks these, but it never
  stops you. See [Alerts](../guide/alerts.md).

## Answers

- **Correct:** the full value of the question.
- **Incorrect:** half the value taken off — a 30-point question answered wrong
  is −15.

## Quizzing out, striking out, fouling out

- **Quiz out:** a quizzer's sixth correct answer. It adds a **+10** bonus, and
  the quizzer **leaves the match**.
- **Strike out:** a quizzer's third incorrect answer, and the quizzer leaves the
  match.
- **Foul:** −5, shown as an **F** on the quizzer. A quizzer's third foul is a
  foul out. A foul by someone other than a quizzer — a coach, for example — is
  charged to the team.

## Time-outs and Coach's Appeals

- **Time-outs:** three per team in regulation, with the app notifying on a
  fourth request.
- **Coach's Appeals:** two per team. Each is recorded as successful or
  unsuccessful, and further appeals are refused once a team's allowance is
  used.

## Overtime

If the match is level after twenty questions, overtime begins with one 10-point,
one 20-point, and one 30-point question, then continues with 20-point questions
until the tie is broken. Any time-outs a team has left carry into overtime,
plus one extra.

## What is the same as TBQ

Junior Bible Quiz and Teen Bible Quiz share a good deal: two teams, twenty
questions, the shape of correct and incorrect scoring, the number of wrong
answers that strike a quizzer out, and the way fouls work. Of note, a quizzer
who quizzes out or strikes out **leaves the match** in Junior Bible Quiz,
whereas in Teen Bible Quiz a quizzer who quizzes out stays in.

The full list of differences is in the table on the
[TBQ preset](tbq.md#how-tbq-differs-from-jbq) page.

!!! warning "Rulebooks govern"
    These are the numbers the preset uses. The official JBQ rulebook is the
    authority, and nothing on this page restates it.

## Related

- [TBQ preset](tbq.md)
- [Rulesets](index.md)
