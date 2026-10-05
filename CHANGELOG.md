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

- **Production app (Phase 3)** — the prototype's flows now run on the real
  engine; `FakeRound` is no longer used outside `lib/prototype/`.
  - `RoundController` (`lib/app/`) owns a `RoundView` plus the view state the
    engine deliberately excludes (screen position, selection, alert
    dismissal). Correct/incorrect advances and clears selection; fouls stay
    on the question; every ruling repaints immediately.
  - Production screens (`lib/views/`): Home (new round / resume / view
    toggle), Setup, Modern, Classic, Summary, with shared widgets in
    `views/common/` composed by both live layouts.
  - `ScoreboardView` (Modern | Classic) persisted per device with
    `shared_preferences` and overridable per session from setup.
  - Autosave to SQLite (`sqlite3` + `path_provider`): rounds and journal rows,
    written on every event; resuming re-folds the journal and restores screen
    position and completion state.
  - Round summary with working PDF and CSV export through the platform share
    sheet (`pdf`, `csv`, `share_plus`).
  - Void question, read substitute question, and quizzer substitution entry
    points, closing the gaps flagged in `docs/design/interaction.md`.

### Fixed

- Classic ledger could overflow horizontally at the 1280dp design width:
  question cells now flex instead of using a computed fixed width, so the
  grid cannot overflow at any width.
- Live bottom bar overflowed once the "More" actions menu was added; the undo
  button now flexes and its label ellipsizes.
- The setup screen's Modern/Classic choice was ignored when starting a round
  (the home screen routed with its own setting); the choice now drives the
  live screen and becomes the remembered default.
- Setup no longer shows an indeterminate progress spinner (never settles in
  tests, and the project avoids decorative motion).
- **Android: the app crashed at launch with `Failed to load dynamic library
  'libsqlite3.so'`.** The `sqlite3` package alone does not bundle the native
  library; added `sqlite3_flutter_libs`, which ships it for Android/Windows/
  Linux. Verified on the `fire_hd_10` (API 30) emulator: the app now opens the
  store and creates `concordance.db`.
- Ignore `android/.kotlin/` (Gradle's Kotlin session dir).

### Changed

- Scoring console: CORRECT is green and INCORRECT red again, for at-a-glance
  clarity from across the table.
- Classic time-out rail: a used time-out now fills solid in the team color with
  white text, so used vs. available is unmistakable.
- Classic ledger: empty question cells and empty running-total cells are blank
  instead of showing a dot.

### Fixed

- Summary team cards were unreadable in **dark mode**: score, time-outs and
  fouls inherited theme colors (near-white) while the card background is a
  fixed *light* team tint. Content on a tinted surface now uses a fixed dark
  ink (`sideInk` / `sideInkMuted` in `views/common/live_chrome.dart`), applied
  to the summary cards, the summary winner banner, and the tinted text in the
  Modern and Classic live views. A dark-mode contrast test guards it.

<!-- Version link references (e.g. [0.1.0]: <repo>/compare/v0.0.1...v0.1.0)
     are added here at the first release, once the canonical repo URL exists. -->
