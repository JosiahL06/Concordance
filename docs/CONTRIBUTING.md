# Contributing to Concordance

Thanks for your interest in Concordance! This document covers everything a
developer needs: the toolchain, how to build and test, how releases are cut and
signed, and the working agreement for changes.

For what the app *is* and how to *use* it, see the [README](/README.md).

## Contents

- [Development environment](#development-environment)
- [Building & running](#building--running)
- [Testing](#testing)
- [Project layout & architecture](#project-layout--architecture)
- [Continuous integration](#continuous-integration)
- [Release signing & distribution trust](#release-signing--distribution-trust)
- [Repository notes](#repository-notes)
- [Working agreement](#working-agreement)

## Development environment

Concordance is built with [Flutter](https://flutter.dev) (stable **3.47.6** /
Dart **3.13.5**). The Android target also needs **JDK 17** and the **Android
SDK 36**.

## Building & running

Run these from the repository root:

```sh
flutter pub get
flutter run                      # run on a connected device/emulator
flutter analyze                  # MUST be clean before any "done" claim
flutter test                     # MUST pass before any "done" claim
flutter build apk                # Android (primary target)
flutter build linux              # Linux desktop dev loop
flutter build windows            # only builds on Windows
flutter build macos              # only builds on a Mac with Xcode
```

### Platform build notes

- **Linux** — `flutter build linux` unconditionally uses `clang`/`clang++`
  and links GTK, so it needs `clang` plus `cmake`, `ninja`, `pkg-config` and
  `libgtk-3-dev`. Do **not** override `CC`/`CXX`; the Flutter tool overwrites
  them. If a stale `build/linux/.../CMakeCache.txt` was generated under a
  different toolchain, delete `build/linux` and rebuild. The build also installs
  a `.desktop` entry and a hicolor app icon into the bundle's `share/` tree
  (`linux/org.concordance.app.desktop`, `linux/icons/...`) so a packaged
  install integrates with the desktop launcher.
- **macOS** — the `macos/` Xcode runner is committed and configured (bundle id
  `org.concordance.app`, landscape-tablet default window, sandboxed no-network
  entitlements), but `flutter build macos` **only runs on a Mac with Xcode**.
  The plain output is a `.app` bundle (an executable), **not** an installer; a
  `.dmg`/`.pkg` must be created separately.
- **Windows** — Authenticode signing is deferred (see
  [distribution trust](#release-signing--distribution-trust)).

### Primary test emulator

`fire_hd_10` mirrors the primary device — API 30 AOSP image (no Google APIs),
1920×1200 @ 240 dpi, landscape:

```sh
flutter emulators --launch fire_hd_10
```

For headless validation:

```sh
emulator -avd fire_hd_10 -no-window -no-audio -no-boot-anim -gpu swiftshader_indirect &
adb wait-for-device
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell am start -n org.concordance.app/.MainActivity
adb exec-out screencap -p > /tmp/screen.png
adb emu kill          # always shut down when finished
```

## Testing

Tests live in `test/`. A feature is **not done without tests**.

- **Engine logic** (`test/engine/`) → unit tests with **golden scenarios
  derived directly from the rulebooks** (e.g. "30-pointer answered wrong
  ⇒ −15"; "fifth correct answer ⇒ +30 then +20 quiz-out bonus").
- **Screens** (`test/views/`) → widget tests for scoring flows, contrast and
  accessibility.

## Project layout & architecture

- `lib/engine/` — the scoring engine, **pure Dart** (no Flutter imports),
  unit-testable in isolation.
- `lib/app/` — controllers, settings, theme, haptics (the UI/engine bridge).
- `lib/views/` — screens; `common/` holds widgets shared by both live views.
- `lib/data/` — SQLite persistence and export (PDF/CSV).
- `assets/rulesets/` — built-in rulebook presets as **data** (JSON).
- `test/` — engine goldens + widget tests.

Two architecture commitments underpin everything:

1. **Event-sourced scoring engine.** Scorekeeper actions (correct/incorrect,
   foul, time-out, interruption, contest/appeal, void) are *events*; all state
   (scores, question progression, quiz-out/strike-out/foul-out) is *derived* by
   folding events. This makes undo/correction trivial and rules testable.
2. **Ruleset-as-data.** Everything that varies between rulebooks lives in a
   JSON config (`docs/design/ruleset-schema.md`); the engine is ruleset-agnostic.
   New rulebooks = new JSON, never engine forks. If a rule can't be expressed,
   extend the **schema**, never fork the engine.

Coding conventions: `flutter_lints` (see `analysis_options.yaml`), `dart format`
defaults, 80-column ruler, `*_screen.dart` / `*_widget.dart` naming. New pub
dependencies MUST be open-source licensed, **GMS-free**, and offline-compatible.

## Continuous integration

Workflows live under `.github/workflows/` (GitHub Actions layout, also valid
for Gitea Actions):

- **`ci.yml`** — `flutter analyze` + `flutter test` on every push to `main` and
  on pull requests. Fast gate, no build.
- **`build.yml`** — full four-platform release build on `v*` tags and via manual
  dispatch (*Actions → Build → Run workflow*): Android APK, Linux bundle,
  Windows zip, and macOS `.app` zip. Tag builds attach the artifacts to a GitHub
  Release and publish a `SHA256SUMS` file.

Both workflows gate their jobs to GitHub (`github.server_url ==
'https://github.com'`), so if the repo is mirrored to a Gitea `origin` those
jobs are **skipped** rather than failing — Gitea Actions cannot provide
macOS/Windows runners or the GitHub API that `subosito/flutter-action` relies on.

To cut a release build:

```sh
git tag v1.0.0
git push origin-github v1.0.0   # 'origin-github' is the GitHub remote
```

All desktop artifacts are **unsigned/unnotarized** and will show platform trust
warnings until Windows and macOS signing land. The Android APK **is**
release-signed when the keystore secrets are configured, and debug-signed only
as a fallback.

## Release signing & distribution trust

### Android

CI signs the release APK with a release keystore supplied as repository secrets.
When the secret is absent the build falls back to the debug key, so a local
`flutter build apk --release` keeps working with no setup.

Create the keystore once, then add these repo secrets
(**Settings → Secrets and variables → Actions**):

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 release.keystore` |
| `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| `ANDROID_KEY_ALIAS` | key alias |
| `ANDROID_KEY_PASSWORD` | key password |

```sh
keytool -genkeypair -v -keystore release.keystore -alias concordance \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -dname "CN=Concordance, O=Concordance"
base64 -w0 release.keystore   # paste into ANDROID_KEYSTORE_BASE64
```

Keep the keystore **backed up outside this repo** — losing it means you can no
longer ship updates over an installed copy. **Never commit a keystore**; if one
ever lands in git, rotate it.

### Checksums

Every release includes a `SHA256SUMS` file, so anyone can verify a download
matches what CI built:

```sh
sha256sum -c SHA256SUMS
```

### Windows & macOS (not yet signed)

- **Windows** — Authenticode signing via **SignPath Foundation** (free for open
  source, OV-level), planned for when the repository goes public. Alternative:
  Azure Artifact Signing (~$9.99/mo, individuals US/CA only). EV certs no longer
  bypass SmartScreen (removed 2024), so OV is sufficient.
- **macOS** — Gatekeeper requires the **Apple Developer Program ($99/yr)** +
  Developer ID cert + hardened runtime + notarization; planned separately.
- Until then both show trust warnings, which is expected for sideloaded builds.

## Repository notes

- The official rulebook PDFs are **not** committed — they are copyrighted by
  My Healthy Church and licensed for local church use only (`docs/*.pdf` is
  gitignored). Scoring rules are encoded as app configuration instead; extracted
  text must go to `/tmp` only, and long verbatim excerpts must never be added to
  the repo. Facts and numeric rules needed to implement scoring are fine.
- `pubspec.lock` **is** committed (this is an application, so dependencies are
  pinned).
- `TODO.md` is the roadmap source of truth; notable changes are recorded in
  `CHANGELOG.md` under `## [Unreleased]` (Keep a Changelog 1.1.0 + SemVer).

## Working agreement

- **Automation must never `git commit`, push, or alter git history.** The
  maintainer performs all commits and pushes.
- The remote is the maintainer's **Gitea** instance; the GitHub remote
  (`origin-github`) is the mirror that CI runs against.
- `flutter analyze` must be clean and `flutter test` must pass before a change is
  considered done.
