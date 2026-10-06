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
  - Team header buttons beside each team name in both live views: `TEAM FOUL n`
    (team-only tally) and contest/appeal (TBQ unsuccessful/3, JBQ
    used/2), with side-scoped entry dialogs. Personal fouls are per-quizzer
    and show on the cells, so the header counts team fouls only.
- Home "Resume round" list: delete a saved round via `RoundStore.deleteRound`,
  guarded by a confirmation dialog so a mis-tap cannot silently lose a round.

### Changed

- Overtime is now automatic and deterministic: a tie after the final question
  appends the next overtime question from the ruleset sequence (TBQ: 10-point
  substitutes; JBQ: 10/20/30 then 20s) with a notice to the keeper. There is
  no longer a button to enter overtime. Undo reverts the overtime question
  and the ruling that forced it.
- Live screens follow the app theme (system / light / dark) from a single
  shared seed instead of forcing light mode; a theme toggle (system → light
  → dark) is present on Home, Setup, both live headers, and Summary, and the
  choice is persisted per device.
- Scoring console: CORRECT is green and INCORRECT red again, for at-a-glance
  clarity from across the table.
- Classic time-out rail: a used time-out now fills solid in the team color with
  white text, so used vs. available is unmistakable.
- Classic ledger: empty question cells and empty running-total cells are blank
  instead of showing a dot.

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
- An incorrect answer on an *interrupted* question no longer auto-advances:
  interrupted questions are re-read to the other team, so the keeper stays on
  the question (with a notice) rather than moving on.
- The footer Contest/Appeal gavel button was removed — the per-team header
  buttons are now the single challenge entry point, and the duplicate dialog
  path in `LiveBottomBar` is gone.
- Storage failures are actionable: if the SQLite store cannot be opened, the
  home screen explains the failure and offers a retry instead of leaving a
  dead disabled button.
- Summary team cards were unreadable in **dark mode**: score, time-outs and
  fouls inherited theme colors (near-white) while the card background is a
  fixed *light* team tint. Content on a tinted surface now uses a fixed dark
  ink (`sideInk` / `sideInkMuted` in `views/common/live_chrome.dart`), applied
  to the summary cards, the summary winner banner, and the tinted text in the
  Modern and Classic live views. A dark-mode contrast test guards it.
- **Live views still had dark-mode contrast gaps.** Two opposite mistakes
  remained in `ModernScreen` / `ClassicScreen`:
  - Side labels and buttons that draw on *dark* theme surfaces (the Modern team
    header name, the Classic time-out rail caption and unused `TO` buttons, and
    the shared `RED TO` / `GREEN TO` bottom-bar buttons) used the fixed deep
    red/green, which is dark-on-dark and nearly invisible. They now use
    `sideAccent(side, scheme)`, which keeps the same deep accent in light mode
    and swaps to a lightened variant (`redAccentDark` / `greenAccentDark`) in
    dark mode (≥4.5:1 against the dark surfaces).
  - Ledger text that sits on the *fixed light* team tints (the Classic `SCORE`
    totals, `RUNNING` label and per-team totals) inherited the theme's
    `onSurface` and so rendered near-white on pale tints. It now uses the fixed
    dark `sideInk` / `sideInkMuted`, matching the summary fix.
  - `test/views/live_contrast_test.dart` asserts both directions in dark mode
    (the bugs are invisible in light mode) plus the light-mode accent identity.
- **Notifications repeated on every later ruling.** A quizzer's quiz-out (or
  strike-out / foul-out) was re-announced on each subsequent answer by any
  quizzer, because `RoundController` re-derived the alert from the engine's
  *currently active* notices (`collectNotices`), which stay true for the rest
  of the round. The controller now remembers which notices it has already
  surfaced (`_announced`, keyed by code + message) and only shows each one
  once, so dismissing the banner no longer brings it back and later rulings
  stay quiet. The 4th time-out notice had the same defect through a second,
  duplicated code path in `takeTimeOut`; that path now flows through the same
  once-per-message gate, so the engine's notice is the single source.
  Regression tests: `test/app/round_controller_test.dart` ("notices do not
  repeat" group).
- **A quizzer's out was never announced again after it was undone.** The
  once-per-notice gate remembered a notice forever, so after undoing the answer
  that made a quizzer quiz out (or strike/foul out) and later re-scoring them
  out at another question, no banner appeared. The controller now re-arms a
  notice whenever its condition stops holding (`_reconcileAnnounced`), so it
  fires again the next time it happens — which matters once quizzer
  substitutions are in play. The resume path also settles already-journaled
  outs (`markCurrentNoticesSeen`), so a resumed round does not replay settled
  history.
- **Time-outs could be taken past the team allotment (4/3, 5/3, …).** Both
  rulebooks cap a team at 3, with a 4th *request* denied and penalized as a
  team foul. `TimeOutEvent` is now rejected at the cap in the engine (never
  journaled, so undo/persistence are unaffected); `RoundController.takeTimeOut`
  returns false and prompts the keeper to assign the team foul through the
  normal foul path. The app deliberately does **not** auto-assess the foul.
  `docs/design/interaction.md` and `docs/ruleset-schema.md` updated; the
  golden/controller tests rewritten to the cap semantics.
- **Overtime time-outs now follow each rulebook** (`LimitsConfig.timeOutCap`).
  TBQ Time-outs §4 voids any remaining time-outs in overtime, so no team
  time-out may be taken (`overtimeTimeOutsCarry` false, `overtimeExtraTimeOuts`
  0 — both already in the preset). JBQ Time-outs §§4–5 carry remaining
  time-outs over *and* grant one extra, so the overtime cap is 3 + 1 = 4
  (`carry` true, `extra` 1 — already in the preset). The engine resolves the
  cap from whether overtime questions have been appended; the live counters
  display `taken/displayCap` (never below what was taken, so a TBQ team that
  used two reads "2/2"), and the overtime announcement states the rule. The
  free one-minute overtime time-out both books declare is the Quizmaster's, not
  a team time-out, so it is not counted.
- **Personal fouls no longer erase the score mark.** `RoundView.cellOutcome`
  was last-write-wins, so a foul on an answered cell replaced `+20`/`−10`
  with `F`. The cell read is now split: `cellOutcome` returns the answer
  mark only and `cellHasFoul` reports the foul; the Classic ledger shows the
  score plus a capital-F badge pinned to the cell's top-right corner (the
  cell `Stack` expands so the badge anchors to the cell, with the score
  wrapped in `Center`) — foul-only cells keep the bare `F` — and the
  summary/CSV notes list both. `TeamView` additionally exposes `teamFouls`,
  `challengesUsed`, and `unsuccessfulChallenges` for the header tallies.
  Tests: `test/views/classic_polish_test.dart`.
- **Polish pass (bottom bar, headers, marks, gating).** The shared
  bottom-bar `RED/GRN TO` duplicates are removed (Modern takes time-outs
  from a header button; Classic keeps its ledger rail); Summary is disabled
  until the match completes; interrupted questions ring the Classic column
  header like the paper circle; the selected-quizzer × current-question
  intersect highlights; the More menu disables void once the current
  question is voided and substitute-question until a void exists.
  `docs/design/interaction.md` updated; global edit/undo dialogue deferred
  to post-v1 (single-step undo + `undoLabel` covers v1).

<!-- Version link references (e.g. [0.1.0]: <repo>/compare/v0.0.1...v0.1.0)
     are added here at the first release, once the canonical repo URL exists. -->
