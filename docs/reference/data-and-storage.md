# Data & storage

**Goal:** answer "where is my data, and who can see it?"

## What is kept

Two things:

- **Your rounds.** Each round, with every ruling you recorded in it, is kept so
  it can be opened again later. The scores are worked out from those rulings
  rather than stored on their own.
- **Your settings.** The light/dark choice, the tap-vibration choice, and the
  last live view you used.

Nothing else is stored. There are no accounts, no usage tracking, and no
information about you.

## Where it is kept

Rounds are kept in a single file called `concordance.db`, in the app's own
folder on your device. The exact folder depends on the platform:

| Platform | Where the file is |
| --- | --- |
| Android / Fire | The app's private storage, not visible in a normal file manager |
| Windows | `%APPDATA%\Concordance\Concordance\concordance.db` |
| Linux | `~/.local/share/org.concordance.concordance/concordance.db` |
| macOS | `~/Library/Application Support/org.concordance.app/concordance.db` |

Your settings are kept separately, in the place your device normally keeps an
app's small preferences.

## How it is written

Your rulings are written to the file as you make them. Each change is written in
one piece, so if the tablet loses power in the middle of a write, the round is
left at the state it was in before that change — never half-applied.

When you reopen a round, the scores are worked out again from the rulings on
record. That is what makes undo exact, as described in
[Autosave & recovery](../guide/autosave-and-recovery.md).

## What is not kept

- No account, and no sign-in of any kind.
- No names of real people, beyond the team and quizzer names you type in
  yourself.
- No usage tracking, no analytics, and no crash reports.
- No network activity at all — the app never connects to the internet.

## Keeping a copy

Saving a round as a PDF or a spreadsheet file is the supported way to keep a
copy, and it is the only way we recommend. On a desktop computer you can also
copy the `concordance.db` file itself, but that is not supported and a copy
cannot be loaded back in — it is there for emergencies only.

## Deleting data

There are three levels, each with a different effect:

| What you do | What is removed |
| --- | --- |
| Delete one round from the home screen | That round only. You are asked to confirm first. |
| Uninstall the app | All rounds **and** your settings |
| Clear the app's storage (Android/Fire) | All rounds **and** your settings |

Uninstalling removes your rounds for good, so save anything you care about
first. See [Updating & uninstalling](../installation/updating-and-uninstalling.md).

## Related

- [Autosave & recovery](../guide/autosave-and-recovery.md)
- [Offline-only, no accounts](../explanation/offline-only.md)
