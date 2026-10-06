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
- [x] New Round setup (ruleset tab, teams, quizzers, seats)
- [x] Shared widgets first (`common/`: console, undo, alerts, time-outs, marks,
      live chrome) — both live views compose them
- [x] `ScoreboardView` setting (persisted per-device via `shared_preferences`,
      overridable per session on the setup screen)
- [x] Wire prototype screens to the real engine (`RoundController` over
      `RoundView`; `FakeRound` no longer used by the production app)
- [x] Live scoring screen in both modes (running scores, auto quiz-out/strike-out
      alerts) over the shared `RoundView`
- [x] Round summary + PDF/CSV export (mode-agnostic, single implementation;
      share sheet via `share_plus`)
- [x] SQLite autosave & round resume (`sqlite3` direct, journal-as-rows;
      save-on-event, resume re-folds)
- [x] Void / substitute-question / substitute-quizzer UI entry points
      (documented gap in `docs/design/interaction.md` §7)
- [x] Tests: engine goldens + `RoundController` adapter + store round-trip +
      widget flows (setup, Classic scoring/undo, Modern scoring), storage
      failure, dark-mode contrast, theme toggle — 46 passing

## Phase 4 — Packaging & polish
- [x] Overtime is automatic: tie after the final question appends the next
      overtime question from the ruleset sequence with a notice (no button);
      undo reverts the overtime question and the forcing ruling
- [x] Storage failures surface an actionable error card with retry
- [x] Live screens follow the app theme from a single shared seed; theme
      toggle (system → light → dark) on Home, Setup, both live headers,
      and Summary, choice persisted per device
- [ ] Polish pass: UI design, usability, intuitiveness, UI logic (button prominence,
      placement, alert placement)
      - [x] Dark-mode text contrast in the live views: fixed-light team tints now
            use the fixed dark `sideInk`/`sideInkMuted`, and the deep red/green
            accents swap to lightened variants (`sideAccent`) on dark surfaces
      - [x] Notifications fire once: quiz/strike/foul-out and limit warnings no
            longer re-announce on every later ruling (`RoundController._announced`)
      - [x] Notifications re-arm on undo: an undone-out quizzer's later re-out
            announces again (substitution-safe); resume settles settled history
      - [x] Time-outs cap at the team allotment (3/3); a 4th request is denied
            and the keeper is prompted to assign the team foul (never automatic)
      - [x] Overtime time-outs per rulebook: TBQ voids remaining (none in OT);
            JBQ carries remaining + 1 extra (cap 4), announced at OT start
- [ ] Guardrail logic pass: block impossible entries (same quizzer scoring twice
      on one question, two quizzers on the same team both scoring on one question)
      in the real engine as `RuleViolation`s with UI surfacing per the interaction
      spec (prototype has a first cut: `canScore`/`scoreBlockedReason`)
- [ ] Signed APK + Windows installer release pipeline (CI under `.github/workflows/`)
- [ ] Touch verification pass (emulator now, real tablet later)
- [ ] Accessibility (Semantics) + haptics pass
- [ ] CI workflow: build APK + Windows installer + Linux on tag (`.github/workflows/`)
