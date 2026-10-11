# Offline-only, no accounts

<!-- OUTLINE (docs pass): type = EXPLANATION.
     Audience question: "is this going to phone home, or need Wi-Fi at the
     venue?" Answer: no, and here's why that is a design constraint rather
     than a missing feature. -->

## Outline

- **The constraint**: v1 is one round, on one device, with no server. Not a
  TODO — an architectural boundary (the official Bible Quiz database has no
  public API, so "sync" was never on the table).
- **What that buys you**: works in a gym with no signal; nothing to log into;
  nothing to leak; a match cannot be interrupted by a captive portal.
- **The cost**: rounds live on one device — share results by exporting a
  PDF/CSV, not by syncing.
- **Privacy in practice**: no analytics, no telemetry, no crash reporting, no
  network permissions in the manifest.
- **What "no accounts" means** for a club with several tablets: each device is
  its own scorekeeper; nothing to configure.
- A short note on why a future online version, if it ever exists, would still
  keep the core loop offline.

## Related

- [Data & storage](../reference/data-and-storage.md)
- [Why Concordance works this way](index.md)
