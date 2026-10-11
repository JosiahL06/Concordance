# Recovering a round

<!-- OUTLINE (docs pass): type = TROUBLESHOOTING. The most emotionally
     important page in the wiki: a scorekeeper believes they lost a match.
     Lead with "you almost certainly haven't", then the actual steps.
     Keep the guarantees honest: anything already on screen was written. -->

## Outline

- **First, don't panic and don't uninstall.** Everything already recorded is on
  disk; opening the app again is safe.
- **The round isn't on Home** — check for a saved round under Resume, and
  whether you are looking at a *new* round; explain how a round is identified.
- **The app crashed / the tablet died mid-match** — reopen, resume; the state
  is rebuilt from the journal, including undo history (link the guide page).
- **The app will not start at all** — platform-specific steps
  (reinstall over the top; on Android installing a newer APK over the old one
  keeps app data — but a *different signing key* forces an uninstall, which
  deletes it: say so clearly).
- **The last tap is missing** — what to do: re-enter the ruling; explain that a
  write in flight is atomic, so you will never see a half-applied ruling.
- **Starting a fresh copy without losing the old one** — how to record the
  score you can see and carry on (there is no import feature; be honest).
- **Reporting it** — the exact details to capture *before* touching anything
  further, with a link to the issue template. If the data is genuinely
  important, say plainly: stop, export nothing, open an issue.

## Related

- [Autosave & recovery](../guide/autosave-and-recovery.md)
- [Data & storage](../reference/data-and-storage.md)
