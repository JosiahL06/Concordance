# Data & storage

<!-- OUTLINE (docs pass): type = REFERENCE. Verify every path against the
     shipped code (sqlite3 direct, journal-as-rows; shared_preferences for
     settings) before publishing — do not guess OS paths. -->

**Goal:** answer "where is my data, and who can see it?"

## To cover

- **What is stored**: rounds (the event journal + derived state), and the
  per-device settings (live-view default, theme, haptics). Nothing else.
- **Where**: a local SQLite database in the platform's per-user app-data
  directory — one row per platform, with the actual path for
  Android/Fire, Windows, Linux and macOS (get these from the platform
  directories, do not guess).
- **How it is written**: journal-as-rows; each ruling is a delta write inside a
  single transaction, so a kill mid-write leaves the previous journal intact.
- **The journal is the source of truth** — state is re-derived by folding it on
  resume; this is what makes undo exact.
- **What is NOT stored**: no accounts, no names of real people beyond what the
  scorekeeper typed, no telemetry, no analytics, no network traffic of any kind.
- **Backups** — export PDF/CSV is the supported way to keep a copy; copying the
  database file is possible but unsupported.
- **Deleting data** — deleting a round in-app vs uninstalling the app vs
  clearing app storage (each has a different blast radius).

## Related

- [Autosave & recovery](../guide/autosave-and-recovery.md)
- [Offline-only, no accounts](../explanation/offline-only.md)
