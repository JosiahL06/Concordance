# Rulesets

**Goal:** understand how Concordance knows the rules, and which numbers are
built in.

## Rules as data, not code

Everything that changes from one rulebook to another lives in a ruleset file
rather than in the app's code. That means how many questions there are, what
they are worth, how a correct answer is scored, how many wrong answers strike a
quizzer out, and the limits on time-outs and challenges.

Because of this, a new season is a new ruleset file, and the app does not need
updating to score it. Rulesets are never removed, so a round from a past season
can still be scored exactly the way it was played.

## The two built-in rulesets

- **Teen Bible Quiz** for the 2025-26 season → [TBQ preset](tbq.md)
- **Junior Bible Quiz** for 2026 → [JBQ preset](jbq.md)

## Choosing a ruleset

You choose the ruleset when you set up a round, on the tabs at the top of the
setup screen. The choice applies to that round.

## Where the numbers come from

The numbers in a ruleset come from the official rulebooks. This wiki records
only the numbers needed to keep score — it does not restate the rules
themselves. The official rulebooks are the authority, and where this wiki and a
rulebook disagree, the rulebook wins.

## A note on the rulebooks

The rulebooks are copyrighted and licensed for local church use only. They are
not copied into or published with this app or this wiki. What you will find here
are the numbers the app needs, together with a pointer to the official book for
the rules themselves.

## Adding a ruleset

A new ruleset is a single file, and no changes to the app are needed to support
it. The format is described on the
[Ruleset schema](../design/ruleset-schema.md) page, and the
[contributing guide](../CONTRIBUTING.md) explains how to add one.

## Related

- [Ruleset schema](../design/ruleset-schema.md)
- [TBQ preset](tbq.md) · [JBQ preset](jbq.md)
