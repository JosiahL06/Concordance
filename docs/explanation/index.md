# Why Concordance works this way

<!-- OUTLINE (docs pass): type = EXPLANATION index (understanding-oriented).
     Short hub page: the design decisions that a user or a curious contributor
     benefits from understanding. One paragraph each, linking out. No steps,
     no commands — this is the "why", never the "how". -->

Concordance is built around a few deliberate choices. This section explains
them rather than telling you to do anything.

## Outline

- **It never touches the network** — offline-only, no accounts, no telemetry →
  [Offline-only, no accounts](offline-only.md).
- **Scoring is an event log, not a running total** — which is why undo is exact
  and a crashed tablet loses nothing → [Event-sourced scoring](event-sourced-scoring.md).
- **Rules live in data, not code** — seasons change without app updates →
  [Rulesets](../rulesets/index.md).
- **Two live views, one engine** — Modern and Classic are layouts, not
  behaviours → [Modern vs Classic](modern-vs-classic.md).
- **It targets a tablet with no Google services** — why side-loading is the
  normal path, not a workaround → [GMS-free & sideload-only](gms-free-and-sideload.md).
- **It is not for official use** — the disclaimer, stated plainly, and what
  that means in practice.
