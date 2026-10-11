# Rulesets

<!-- OUTLINE (docs pass): type = brief EXPLANATION index for the ruleset
     section. Explain the ruleset-as-data idea in a few sentences and route to
     the TBQ/JBQ pages and the schema.

     COPYRIGHT GUARD: this section may state numeric rules and cite rule
     numbers/sections, but must NOT reproduce rulebook prose. The PDFs are
     licensed for local church use only and are never committed or published.
     Always send readers to the official rulebooks for the rules themselves. -->

**Goal:** understand how Concordance knows the rules, and which numbers are
built in.

## To cover

- **Ruleset-as-data** — question counts, point values, multipliers,
  quiz-out/strike/foul limits and notification limits all live in a
  configuration file, not in code; new seasons are new files, never app
  updates to the engine.
- **Two presets ship today**: [TBQ 25-26](tbq.md) and [JBQ 2026](jbq.md).
  Older rulesets are never deleted, so a past season's round can still be
  scored exactly as it was played.
- **How a ruleset is selected** — per round, at setup.
- **Where the numbers come from** — the official rulebooks; state clearly that
  this wiki records only the numeric facts needed to score, and that the
  rulebooks govern.
- **Adding a ruleset** — point at the schema and the contributing guide; no
  code changes required.
- A short statement of the project's copyright policy for rule text.

## Related

- [Ruleset schema](../design/ruleset-schema.md)
- [TBQ preset](tbq.md) · [JBQ preset](jbq.md)
