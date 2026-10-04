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
- [ ] CI workflow: build APK + Windows installer + Linux on tag (`.github/workflows/`)

## Phase 1 — Scoring engine (pure Dart, test-first)
- [ ] Event-sourced round model (answer/foul/time-out/contest events)
- [ ] Ruleset-as-data schema (question values, quiz-out/strike-out/foul rules)
- [ ] TBQ 25-26 preset + JBQ 2026 preset from the official rulebooks
- [ ] Golden unit tests worked from both rulebooks

## Phase 2 — UI
- [ ] Design mockup of live scoring screen (sign-off before implementation)
- [ ] Home / New Round setup (ruleset tab, teams, quizzers, seats)
- [ ] Live scoring screen (running scores, auto quiz-out/strike-out alerts)
- [ ] Round summary + PDF/CSV export
- [ ] SQLite autosave & round resume

## Phase 3 — Packaging & polish
- [ ] Signed APK + Windows installer release pipeline
- [ ] Touch verification pass (emulator now, real tablet later)
- [ ] Accessibility (Semantics) + haptics pass
