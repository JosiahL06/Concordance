# Tournaments

A tournament tracks one team across a fixed number of matches. Each match is a
normal Concordance round with its own journal, undo, summary, and export; the
tournament adds a saved team, a match slate, and aggregate statistics.

Tournament mode is intended for a scorekeeper following one team through an
event. The opponent is entered for each match. A full multi-team bracket or
league table is not part of this first version.

## Start a tournament

1. On the home screen, choose **START A TOURNAMENT**.
2. Name the tournament and choose the number of matches.
3. Pick the ruleset. The whole tournament uses this ruleset.
4. Enter your team's name, seated quizzers, bench quizzers, and seat order.
5. Choose **CREATE TOURNAMENT**.

The team profile is now the default for every match. Member names are stored as
stable identities, so substitutions, seat changes, and later roster edits do not
break their totals.

## The tournament dashboard

The dashboard shows:

- match progress, win/loss/tie record, and team points
- every scheduled match, with its opponent, side, result, and status
- **START MATCH**, **CONTINUE MATCH**, or **VIEW** for each match
- team totals: matches, record, points for/against, differential, average,
  quiz-outs, team fouls, time-outs, and contests
- individual totals: matches, points, correct, incorrect, fouls, quiz-outs, and
  average points

Only completed matches count toward the record and aggregate totals. An
in-progress match stays visible in the slate but is excluded until it has a
result.

## Start a match

1. From the dashboard choose **START MATCH** for the next slot.
2. Pick **Red** or **Green** for your team.
3. Confirm or adjust the lineup for this match: choose a seat, bench, or
   not playing for each member. The changes apply to this match only.
4. Enter the opponent's name and roster in the other team column.
5. Choose **Modern** or **Classic** for the live view.
6. Choose **START MATCH**.

The theme and haptics switches are in the match setup header, just like the
normal setup screen. The chosen live view becomes the app's remembered view.

The live scoring screen is unchanged. Returning from the live screen takes you
back to the tournament dashboard, where the match is marked complete once it has
a result.

If the app closes mid-match, reopen the tournament from the home screen and use
**CONTINUE MATCH**.

To correct a completed match, use the edit icon on its row. That opens the
normal live scoring screen with the saved journal, so the usual correction
tools (Undo, cell editing, question editing) are available. The summary remains
the read-only view. Tournament totals recompute when you return to the
dashboard.

## Resetting and deleting

- **Reset match** deletes that match's round and returns the slot to not
  started. Use it when a match was started by mistake. The confirmation explains
  that the round journal is deleted.
- **Delete tournament** removes the tournament and every round it created. This
  cannot be undone. The delete action is available both on the tournament
  dashboard and on the tournament's row on the home screen.

Tournament rounds do not appear in the standalone **Resume round** list; open
them through their tournament dashboard instead.

## Export results

The bottom of the tournament dashboard has an **Export results** section. It
shares the tournament as:

- a **PDF score sheet** with the match slate, team totals, and individual
  totals
- a **CSV file** with the same team, match, and individual data

Both use the platform share sheet where file sharing is available, just like
the match summary export. On Linux (and older Windows versions where file
sharing is unavailable), they open a **Save as** dialog instead. The export
enables once at least one match is complete; in-progress and not-started matches
remain visible in the match table but do not count toward totals.

## Statistics notes

- A match counts as complete when every question slot has an answer and the
  teams are not tied. A tie leaves overtime pending, so it is not counted until
  the overtime result exists.
- Individual totals follow the stable member identity, not the seat number. A
  quizzer who moves between seat and bench keeps their totals.
- Quiz-outs are counted from the quizzer's final status in a completed match.
  Editing a completed round through the normal correction tools recomputes the
  tournament totals.
- Per-match points use the same scoring rules as the round summary, including
  quiz-out bonuses and foul deductions.

## Current limitations

- A per-match lineup change is not saved back as the tournament's default
  lineup; the saved team remains the starting point for the next match.
- Opponents are entered per match; there is no saved opponent library or
  predefined schedule.
- Matches are started in order. There is no bracket generation or multi-team
  standings table.
