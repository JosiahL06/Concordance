# Settings

<!-- OUTLINE (docs pass): type = HOW-TO for the settings that exist + REFERENCE
     stub per setting. Every setting must be listed with its default and where
     it is stored. Current known settings: ScoreboardView (per-device, via
     shared_preferences, overridable per round), theme (system/light/dark),
     haptics (opt-in, off by default). Verify against the app before writing. -->

**Goal:** adjust the app to the device and the venue.

## To cover

- **Default live view (ScoreboardView)** — per-device default; how to override
  it for a single round from Setup; why it is remembered per device (different
  tablets, different keepers).
- **Theme** — follows the system by default; light red/green tints keep the
  teams distinguishable in both themes.
- **Haptics** — **off by default**; why (a match must never be distracted by
  tablet noises/vibration); per-device switch next to the theme switch.
- **Sound** — there is no sound setting, because the app never plays audio;
  explain that this is deliberate and app-wide (all Material feedback paths are
  disabled).
- **Accessibility** — screen-reader behaviour (TalkBack), ≥48 dp targets, no
  hidden gestures, no long-press-only affordances.
- **Where settings live** — on-device only; reinstalling resets them.
- Table of settings: name · default · scope (device / round) · where stored.

## Related

- [Data & storage](../reference/data-and-storage.md)
- [Modern vs Classic](../explanation/modern-vs-classic.md)
