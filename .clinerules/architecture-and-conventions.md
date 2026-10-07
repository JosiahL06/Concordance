---
description: Architecture decisions, coding conventions, UI principles, and definition-of-done for Concordance development.
version: 1.0
tags: ["architecture", "conventions", "testing"]
---

# Architecture & Conventions

**Objective:** Preserve the planned architecture and the quality bar (modern, touch-first, test-first scoring logic) across sessions.

## Stack
Flutter (stable channel) → Dart. Material 3. Local persistence via SQLite (package choice — drift vs sqflite — TBD at Phase 2; MUST be pure-local, no network permissions added). No state-management framework chosen yet; when chosen, document it here.

## Architecture decisions (locked)
1. **Event-sourced scoring engine as pure Dart** (`lib/engine/` or similar), completely decoupled from UI: scorekeeper actions (correct/incorrect answer, foul, time-out, interruption, contest/appeal, void) are *events*; state (team/individual scores, question progression, quiz-out/strike-out/foul-out flags) is *derived* by folding events. This makes undo/correction trivial and rules testable.
2. **Ruleset-as-data, not ruleset-as-code.** A config schema must capture everything that varies between rulebooks (question count + point values, correct/incorrect multipliers, quiz-out threshold + bonus, strike/foul rules, limit notifications). The engine MUST remain ruleset-agnostic; presets (`tbq`, `jbq`) are configuration files loaded at session start.
3. **Offline-only:** the app MUST NOT gain network code, accounts, or telemetry in v1.
4. **Autosave is non-negotiable:** every scoring event persists immediately (SQLite); a round MUST survive app kill/restart mid-match.

## Code conventions
- Follow `flutter_lints` (already in `analysis_options.yaml`); `flutter analyze` MUST be clean.
- Dart style: `dart format` defaults, **80-col** ruler; widget files named `*_screen.dart` / `*_widget.dart`; engine code MUST NOT import Flutter widgets (pure Dart, unit-testable).
- `pubspec.lock` IS committed (application, pin dependencies). New pub dependencies MUST be: open-source licensed, GMS-free, offline-compatible.
- Tests live in `test/`: engine logic → **unit tests with golden scenarios derived from the rulebooks**; screens → widget tests for scoring flows. A feature is not done without tests.

## UI principles (the product's whole point)
- Usable in seconds by a trained-up volunteer: **large touch targets (≥48dp)**, one-tap scoring actions, **prominent undo**, no hidden gestures, no long-press-only affordances.
- Landscape tablet first (Fire HD 10: 1280×800 logical dp); Material 3 with automatic dark/light; haptic feedback on scoring taps is **opt-in and off by default** (per-device toggle next to the theme switch); **the app never plays audio** — all Material `enableFeedback` paths are disabled app-wide (`buildTheme` + silent `QuietDialogOption`/`QuietMenuItem` + silent InkWells), so an official match is never distracted by tablet noises. Only TalkBack's own speech (when the OS enables it) can make sound; alerts auto-fire when a quizzer hits quiz-out/strike-out/foul-out.
- The paper score sheet's marks (circled interruptions, contest slashes, F fouls) have digital equivalents in the question navigator.
- **Readability beats aesthetic flair** (user directive): this is a data-display tool — no fancy animations or decorative motion, Material defaults only; bold, legible typography for scores.
- **Red team vs. green team** is decided by the physical quiz box: quizzers are Red 1, Red 2, Green 1, Green 2, … Use *light* color coding (tints + accents, not garish fills) so officials can tell the sides at a glance.
- **Scoresheet-mimicry is a fallback, not the starting point:** design clean/modern first; if veterans find it unintuitive versus the traditional paper page, reintroduce scoresheet structure in a later pass.
- **Dual live-scoring views ("Modern" + "Classic"):** the live scoring
  screen ships in two variants — Modern (Direction A: split-field,
  spatial) and Classic (Direction B: scoresheet ledger). Both are thin
  layouts over the SAME engine view-model (`RoundView`); no scoring logic
  may live in either view. Shared widgets (score type, console, undo,
  alerts, time-out controls, mark glyphs) live in `common/`; per-view
  layout files compose them. A `ScoreboardView` setting (persisted
  per-device, overridable per session) selects the variant. Setup and
  Summary screens are mode-agnostic (single implementation).

## Definition of done (every task)
1. `flutter analyze` clean, 2. `flutter test` passing, 3. long steps backgrounded & verified, 4. visual check on `fire_hd_10` emulator (screenshot) when UI changed, 5. `TODO.md` updated, 6. notable changes recorded in `CHANGELOG.md` under
   `[Unreleased]`, 7. changes summarized for the user to commit (see working
   agreement).
