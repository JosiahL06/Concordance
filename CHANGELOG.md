# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Initial Flutter project scaffold (v3.47.6 / Dart 3.13.5) with Android,
  Windows, and Linux targets.
- Android package `org.concordance.app` with launcher label "Concordance".
- Primary-target configuration for the Amazon Fire HD 10 (2023): landscape
  1920×1200, Android 11 / API 30 baseline, GMS-free dependency policy, and a
  matching `fire_hd_10` test emulator.
- Project documentation: README (setup & platforms), TODO roadmap, and
  development rules in `.clinerules/`.
- License: GNU Affero General Public License v3.0 only (AGPL-3.0-only).

- **Dual-mode live-scoring prototype** (`lib/prototype/`): Direction A
  "Modern" (split-field) and Direction B "Classic" (paper-style scoresheet
  ledger), selectable from the prototype home; validated on the `fire_hd_10`
  emulator at 1920×1200 landscape.
- New Round setup screen: ruleset tabs loaded from the real presets, team
  names, roster steppers clamped to each preset, Modern/Classic view pick,
  fresh-start and seeded-demo flows.
- Round summary screen: result banner, team cards, per-quizzer breakdown,
  question-by-question review; PDF/CSV export shown as prototype-inert
  affordances.
- Tap-flow contract (`docs/design/interaction.md`) mapping every prototype
  action to its future engine event and `RoundView` read.
- **Scoring engine** (`lib/engine/`, pure Dart, no Flutter imports):
  - Event-sourced round model — scoring actions are journaled events;
    state is derived by folding, so undo is pop + re-fold and the journal
    is the persistence unit.
  - `RoundView` view-model serving both Modern and Classic reads
    (per-cell ledger marks, per-question deltas, running totals).
  - Ruleset-as-data schema (`docs/ruleset-schema.md`, decisions D1–D9)
    with validation returning structured `RuleViolation`s (never throws).
  - Built-in presets `tbq-25-26` and `jbq-2026` (`assets/rulesets/`),
    encoded from the official rulebooks.
  - Scorekeeper notifications: quiz/strike/foul-out, 4th time-out request,
    3rd unsuccessful contest (TBQ), exhausted Coach's Appeals (JBQ).
  - Overtime/void/substitute-question/quizzer-substitution support.
  - 22 golden tests worked from both rulebooks (`test/engine/`), including
    full-regulation-match simulations with hand-computed expectations.

<!-- Version link references (e.g. [0.1.0]: <repo>/compare/v0.0.1...v0.1.0)
     are added here at the first release, once the canonical repo URL exists. -->
