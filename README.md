# Concordance

A modern, touch-first **scorekeeper for Bible Quiz matches** — built to be clean,
intuitive, and usable within seconds of handing it to a volunteer scorekeeper.

Concordance tracks a single round offline (no accounts, no server), with the
scoring rules expressed as **pluggable rulesets** rather than hard-coded logic.
Built-in presets ship for the Assemblies of God **Teen Bible Quiz (TBQ)** and
**Junior Bible Quiz (JBQ)** rulebooks.

## Platforms

- **Amazon Fire HD 10 (2023, 13th gen)** — **primary target**. Fire OS 8
  (Android 11, API 30), 1920×1200 landscape-first touch UI. Fire tablets have
  **no Google Play services**, so the app stays fully GMS-free and ships as a
  sideloaded APK (enable *Apps from Unknown Sources* on the tablet).
- **Windows** — secondary target (touchscreen-friendly)
- **Linux** — day-to-day development and testing
- **macOS** — secondary desktop target. The Xcode project is committed, but
  `flutter build macos` **only runs on a Mac with Xcode** (see below).

> **Note:** macOS builds cannot be produced on Linux. The `macos/` runner is
> scaffolded and configured here so the code is build-ready; the actual build
> happens on a Mac (see the development rules for details).

## Development

Built with [Flutter](https://flutter.dev) (stable 3.47.x).

```sh
flutter pub get
flutter run          # run on a connected device/emulator
flutter test         # unit + widget tests
flutter build apk    # Android release build
flutter build windows
flutter build linux
flutter build macos  # macOS desktop (only builds on a Mac with Xcode)
```

Primary test emulator: `fire_hd_10` — API 30 AOSP image (no Google APIs), sized
1920×1200 @ 240 dpi to mirror the Fire HD 10. Launch it with:

```sh
flutter emulators --launch fire_hd_10
```

Project-local SDK setup lives in `~/sdk/env.sh` (Flutter, Android SDK, JDK 17)
and is sourced from `~/.bashrc`.

## Repository notes

- The official rulebook PDFs are **not** committed — they are copyrighted by
  My Healthy Church and licensed for local church use only (`docs/*.pdf` is
  gitignored). Scoring rules are encoded as app configuration instead.
- CI workflows live under `.github/workflows/` (GitHub Actions; the layout is
  also valid for Gitea Actions).

## Continuous integration

Workflows live under `.github/workflows/`:

- **`ci.yml`** — `flutter analyze` + `flutter test` on every push to `main` and
  on pull requests. Fast gate, no build.
- **`build.yml`** — full four-platform release build on `v*` tags and via manual
  dispatch (*Actions → Build → Run workflow*): Android APK, Linux bundle,
  Windows zip, and macOS `.app` zip. Tag builds attach the artifacts to a GitHub
  Release.

Both workflows gate their jobs to GitHub (`github.server_url ==
'https://github.com'`), so if the repo is mirrored to your Gitea `origin`, those
jobs are **skipped** rather than failing — Gitea Actions cannot provide
macOS/Windows runners or the GitHub API that `subosito/flutter-action` relies on.

To cut a release build:

```sh
git tag v1.0.0
git push origin-github v1.0.0   # 'origin-github' is the GitHub remote
```

All desktop artifacts are **unsigned/unnotarized** and will show platform trust
warnings until Windows and macOS signing land (below). The Android APK **is**
release-signed when the keystore secrets are configured, and debug-signed only
as a fallback.

## Release signing & distribution trust

### Android

CI signs the release APK with a release keystore supplied as GitHub secrets.
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
longer ship updates over an installed copy.

### Checksums

Every release includes a `SHA256SUMS` file, so anyone can verify a download
matches what CI built:

```sh
sha256sum -c SHA256SUMS
```

### Windows & macOS (not yet signed)

- **Windows** — Authenticode signing via **SignPath Foundation** (free for open
  source, OV-level), planned for when the repository goes public.
- **macOS** — Gatekeeper requires the **Apple Developer Program ($99/yr)** +
  Developer ID cert + hardened runtime + notarization; planned separately.
- Until then both will show trust warnings, which is expected for sideloaded
  builds.

## License

[GNU Affero General Public License v3.0](LICENSE) (AGPL-3.0-only).
