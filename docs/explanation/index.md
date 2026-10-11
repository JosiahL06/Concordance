# Why Concordance works this way

Concordance is built around a few deliberate choices. This section explains
those choices, rather than telling you to do anything.

- **It never touches the internet.** No accounts, no server, nothing sent
  anywhere — ever. → [Offline-only, no accounts](offline-only.md)
- **A round is a record of what happened, not a running total.** This is why
  undo is exact and why a crash loses nothing. →
  [Event-sourced scoring](event-sourced-scoring.md)
- **The rules live in files, not in the app.** A new season is a new file,
  rather than an app update. → [Rulesets](../rulesets/index.md)
- **Two live views, one engine.** Modern and Classic are only two ways of
  showing the same round. → [Modern vs Classic](modern-vs-classic.md)
- **It is built for a tablet with no Google services.** That is why installing
  from a downloaded file is the normal path here, not a workaround. →
  [GMS-free & sideload-only](gms-free-and-sideload.md)
- **It is not for official use.** An independent community project, not the
  scorekeeper of record. See the note on the [home page](../index.md).
