# Updating & uninstalling

<!-- OUTLINE (docs pass): type = HOW-TO, per platform. Short sections.
     Key facts to verify before writing:
       * Android/Fire: install the new APK over the old one (same signing key
         required — the release keystore); rounds live in app data, so they
         survive an update but NOT an uninstall.
       * Desktop: replace the folder; the round database lives in the OS's
         per-user app-data directory, so it survives replacing the bundle. -->

## Outline

- **Where your rounds live** (one sentence, linking to Data & storage) —
  updating keeps them, uninstalling deletes them.
- **Android / Fire** — download the newer APK and install it over the existing
  app; note the "App not installed" signature-mismatch case (debug build vs
  release build) and how to fix it (uninstall the debug build first).
- **Windows** — extract the new zip over the old folder (or replace it);
  your rounds are stored outside the app folder.
- **Linux** — same, replace `bundle/`.
- **macOS** — replace the `.app` in Applications; re-do the Gatekeeper
  right-click-Open step because the quarantine flag is re-applied.
- **Uninstalling** — per platform, plus an explicit warning + a "back up first"
  note (export a PDF/CSV of any round you care about before uninstalling).

## Related

- [Data & storage](../reference/data-and-storage.md)
- [Which download do I need?](index.md)
