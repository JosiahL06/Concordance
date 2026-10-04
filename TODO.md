# Concordance — v1 Roadmap

## Target hardware
- **Primary: Amazon Fire HD 10 (2023, 13th gen)** — Fire OS 8 (Android 11, API 30),
  1920×1200 landscape, sideloaded APK (no Google Play services — keep deps GMS-free).
  Test AVD: `fire_hd_10` (API 30 AOSP image, no Google APIs). Flutter default
  `minSdk = 24` covers it with room to spare (also Fire OS 7 / Android 9).
- Secondary: Windows laptops (touchscreen), generic Android tablets.

## Phase 0 — Toolchain & scaffold
- [x] Flutter 3.47.6 + JDK 17 + Android SDK installed (user-level, `~/sdk/`)
- [x] Project scaffolded (`android`, `windows`, `linux` targets)
- [x] AGPL-3.0 LICENSE, .gitignore, VS Code config
- [x] CHANGELOG.md initialized (Keep a Changelog 1.1.0)
- [x] Verify Android debug build (`app-debug.apk` builds, installs & runs on emulator)

## Phase 1 — UI design & sign-off
- [x] Two visual directions for the live scoring screen (screenshots on `fire_hd_10`)
- [x] User picks a direction → **keep both**: Modern (A: split-field) + Classic (B: scoresheet ledger)
- [x] Build out all three screens (setup, live scoring in both modes, summary)
- [x] Hands-on validation (Linux desktop + `fire_hd_10` screenshots) + revision rounds
- [x] Interaction spec written (`docs/design/interaction.md`) — tap-flow contract
      for Phases 2–3

## Phase 2 — Scoring engine (pure Dart, test-first)
- [x] Rulebook extraction pass (facts matrix from both PDFs, `/tmp` only)
- [x] Ruleset-as-data schema (`docs/ruleset-schema.md`) + `questionNumber`-on-event decision
- [x] `RoundView` view-model interface first (serves both Modern + Classic)
- [x] Event-sourced round model (answer/foul/time-out/contest events)
- [x] TBQ 25-26 preset + JBQ 2026 preset from the official rulebooks
- [x] Golden unit tests worked from both rulebooks + dual-mode consistency test
      (22 tests: scoring, bookkeeping/notifications, full-match sims, presets)
- [x] Read API shaped by the Phase 1 interaction spec (`RoundView` exposes every
      read the spec's console contract needs: scores, per-quizzer breakdown,
      per-question marks, Classic ledger cells/deltas, undo availability)

## Phase 3 — UI implementation
- [ ] New Round setup (ruleset tab, teams, quizzers, seats)
- [ ] Shared widgets first (`common/`: score type, console, undo, alerts, time-outs, marks)
- [ ] `ScoreboardView` setting (persisted per-device, overridable per session)
- [ ] Wire prototype screens to the real engine (replace `FakeRound`)
- [ ] Live scoring screen in both modes (running scores, auto quiz-out/strike-out alerts)
      over the shared `RoundView`
- [ ] Round summary + PDF/CSV export (mode-agnostic, single implementation)
- [ ] SQLite autosave & round resume

## Phase 4 — Packaging & polish
- [ ] Polish pass: UI design, usability, intuitiveness, UI logic (button prominence,
      placement, alert placement)
- [ ] Guardrail logic pass: block impossible entries (same quizzer scoring twice
      on one question, two quizzers on the same team both scoring on one question)
      in the real engine as `RuleViolation`s with UI surfacing per the interaction
      spec (prototype has a first cut: `canScore`/`scoreBlockedReason`)
- [ ] Signed APK + Windows installer release pipeline (CI under `.github/workflows/`)
- [ ] Touch verification pass (emulator now, real tablet later)
- [ ] Accessibility (Semantics) + haptics pass
- [ ] CI workflow: build APK + Windows installer + Linux on tag (`.github/workflows/`)
