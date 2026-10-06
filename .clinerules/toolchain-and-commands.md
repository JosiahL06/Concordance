---
description: Development environment — toolchain locations, required commands, emulator workflow, and environment gotchas.
version: 1.0
tags: ["toolchain", "commands", "environment"]
---

# Development Environment & Commands

**Objective:** Reproduce the exact commands and environment quirks of this machine so builds, tests, and device work never fail for environmental reasons.

## Environment facts
- OS: **Arch Linux**, user `siah`, **no passwordless sudo** — all SDKs are user-level installs under `~/sdk/` (Flutter, Android SDK, JDK 17 Temurin). NEVER attempt `sudo`/`pacman`; install tools user-level.
- **CRITICAL:** non-interactive shells do NOT source `~/.bashrc`. Every command MUST begin with:
  ```sh
  source $HOME/sdk/env.sh   # sets PATH, ANDROID_HOME, ANDROID_SDK_ROOT, JAVA_HOME
  ```
  (Interactive terminals get this automatically via `~/.bashrc`.)
- Versions: Flutter **3.47.6** stable / Dart **3.13.5** / JDK **17.0.20.1** / Android SDK **36** / emulator **37.2.12**.
- Tool downloads/caches: `~/sdk/cache/` (logs + installers live here).

## Standard commands (run from `/home/siah/concordance`)
```sh
flutter pub get
flutter analyze          # MUST be clean before any "done" claim
flutter test             # MUST pass before any "done" claim
flutter build apk --debug        # PRIMARY target (Fire HD 10) — works here
flutter build linux --debug      # desktop dev loop; needs clang (installed)
flutter build windows            # only builds on Windows CI, not this machine
flutter build macos              # only builds on a Mac with Xcode, NOT this machine
```

### macOS build requires a Mac (Xcode)
`flutter build macos` **cannot run on this Linux machine** — it needs macOS with
Xcode and CocoaPods. The `macos/` Xcode runner IS committed and configured
(bundle id `org.concordance.app`, app name "Concordance", landscape-tablet
default window, sandboxed no-network entitlements), so a Mac can build it with
no source changes. On a Mac:

```sh
flutter build macos              # -> build/macos/Build/Products/Release/Concordance.app
```

The plain output is a `.app` bundle (an executable), **not** an installer. A
`.dmg` (drag-to-Applications) or `.pkg` must be created separately
(`hdiutil create` / `create-dmg` / `pkgbuild`). Unsigned apps are blocked by
Gatekeeper but openable via right-click → Open (or
`xattr -dr com.apple.quarantine Concordance.app`); a clean install needs
Developer ID signing + notarization ($99/yr Apple Developer Program).

### Linux desktop build needs clang
Flutter's `build_linux.dart` **unconditionally** sets `CC=clang, CXX=clang++`
for its cmake configure step, so `flutter build linux` REQUIRES `clang`/`clang++`
(Arch package `clang`) alongside cmake, ninja, pkgconf and gtk3 — all present on
this machine. Do NOT try to override with your own `CC`/`CXX`; the tool
overwrites them.

If a stale `build/linux/.../CMakeCache.txt` was generated under a different
toolchain you may see `The CMAKE_CXX_COMPILER: /usr/bin/clang++ is not a full
path to an existing compiler tool.` — delete `build/linux` and rebuild.

## Timing gotchas
- Tool calls have a **~30s timeout**. Long work (builds, SDK installs, emulator boots) MUST be backgrounded:
  ```sh
  nohup bash -c '...command...; echo "exit=$?" >> log; touch MARKER' >/dev/null 2>&1 </dev/null &
  ```
  then poll for the marker file. Write logs to `~/sdk/cache/`.
- `pgrep -f <pattern>` can match its own shell wrapper — verify processes with `pgrep -ax java` or by marker files, not patterns that appear in your own command string.

## Emulators (KVM available)
- **`fire_hd_10`** — PRIMARY target mirror: API 30 AOSP image (`default`, no Google APIs), 1920×1200 @ 240 dpi, landscape, hw keyboard + GPU on.
- `concordance_tablet_36` — secondary: API 36 Google APIs, Pixel Tablet 2560×1600.
- Headless validation pattern:
  ```sh
  emulator -avd fire_hd_10 -no-window -no-audio -no-boot-anim -gpu swiftshader_indirect &
  adb wait-for-device            # then poll: adb shell getprop sys.boot_completed == 1
  adb install -r build/app/outputs/flutter-apk/app-debug.apk
  adb shell am start -n org.concordance.app/.MainActivity
  adb exec-out screencap -p > /tmp/screen.png   # read the PNG to visually verify
  adb emu kill                   # always shut down when finished
  ```
- KNOWN QUIRK: `avdmanager create avd` crashes on missing `devices.xml` and writes unsubstituted placeholders (`<build>`, `<temp>`) plus generic 320×640 defaults into `config.ini`. MUST repair: fix `avd.id`/`avd.name`/`disk.dataPartition.path`, set real LCD dims/orientation/`hw.keyboard=yes`/`hw.gpu.enabled=yes`. AVDs live in `~/.android/avd/`.

## Other tools
- **VSCodium** (`codium`) is the IDE; Dart/Flutter extensions already installed; `.vscode/settings.json` pins `dart.flutterSdkPath` to `/home/siah/sdk/flutter`.
- `aapt2` is NOT on PATH — use `apkanalyzer manifest application-id <apk>` for APK inspection.
- `pdftotext` is installed — see `.clinerules/rulebooks-and-rulesets.md` for rulebook access.
