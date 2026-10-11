# Install & launch problems

<!-- OUTLINE (docs pass): type = TROUBLESHOOTING (Good Docs template shape:
     symptom → cause → fix, one block per problem). Group by platform.
     Every entry needs the *cause* explained, not just a fix — that is what
     builds trust with a non-technical volunteer. -->

## Outline

**Android / Fire**
- "App not installed" — most often a signature mismatch (an older debug build
  is installed): uninstall the old app first; also storage space; also a
  corrupted/partial download (verify the checksum).
- "This type of file can harm your device" — expected for any side-loaded APK;
  confirm the source and continue.
- Unknown-sources switch missing or greys out — where the per-app permission
  lives on Fire OS 8 vs Android 8+.
- App icon missing after install — Home vs App Library on Fire OS.

**Windows**
- "Windows protected your PC" — SmartScreen for an unsigned build.
- Nothing happens on double-click — the `.exe` was run from inside the zip
  rather than the extracted folder.
- Missing `*.dll` error — same cause.

**Linux**
- `error while loading shared libraries: libgtk-3.so.0` — install GTK 3 (per
  distro commands).
- Blank window / no input — Wayland vs X11 (`GDK_BACKEND=x11`).
- "Permission denied" — extract the tarball rather than running from it.

**macOS**
- "cannot be opened because the developer cannot be verified" — Gatekeeper for
  an unsigned/unnotarized app; right-click → Open, or clear the quarantine
  attribute; explain why moving it to /Applications matters.
- "app is damaged and can't be opened" — the unzipper mangled the bundle; use
  Finder's Archive Utility or `ditto`.
- Wrong architecture (Apple silicon vs Intel) — what the error looks like.

**All platforms**
- The app opens but the round looks empty — you may be on a new round rather
  than the saved one; check Home's resume list.

## Related

- [Updating & uninstalling](../installation/updating-and-uninstalling.md)
- [Verifying your download](../installation/verifying-downloads.md)
