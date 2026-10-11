# Autosave & recovery

<!-- OUTLINE (docs pass): type = HOW-TO + reassurance. The audience question
     is "what if the tablet dies mid-match?" Answer it in the first sentence.
     Implementation facts: SQLite, journal-as-rows, save-on-event, resume
     re-folds the journal; delta writes inside one transaction, so a kill
     mid-save leaves the previous journal intact. -->

**Goal:** trust that a dead battery or a crash cannot lose the round.

## To cover

- **Autosave** — every ruling is written to disk as it happens; there is no
  Save button and nothing to remember.
- **What "resume" does** — Home lists saved rounds; resuming replays the
  journal and rebuilds the exact state, including undo history and the current
  screen position.
- **What survives what** — table: crash / battery death / force-kill / reboot /
  app update ⇒ round intact; uninstall ⇒ round deleted (export first!).
- **Deleting a round** — the confirmation step; why it is deliberately fussy.
- **Recovering after something weird** — link to the troubleshooting page.
- Under the hood (2 sentences, link to Data & storage): rounds are rows in a
  local SQLite database; the app never talks to a server, so recovery never
  depends on anything but the device.

## Related

- [Recovering a round](../troubleshooting/data-recovery.md)
- [Data & storage](../reference/data-and-storage.md)
