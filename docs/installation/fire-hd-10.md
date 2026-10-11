# Amazon Fire HD 10 (primary target)

<!-- OUTLINE (docs pass): type = HOW-TO, one task = install on a Fire tablet.
     Numbered steps with a screenshot at each decision point.
     Screenshots: capture on the fire_hd_10 emulator, or on device.
     NOTE: Fire OS 8 is Android 11-based; the unknown-sources toggle is
     PER-APP ("Install unknown apps"), not the old global switch.
     Mention both wordings so older Fire OS users can follow. -->

The Fire HD 10 has no Google Play services. Concordance is deliberately
GMS-free, so it side-loads like any other APK.

## Outline

1. **Download the APK** — get `app-release.apk` onto the tablet (from the
   Releases page in the tablet's browser, or copy it over USB/cloud if you
   prefer; note: Fire tablets ship with Silk, not Chrome).
2. **Allow installing apps** — Settings → **Security & Privacy** → *Apps from
   Unknown Sources* / *Install unknown apps* → pick the app you'll install
   *from* (Files, Silk, …) → Allow.
3. **Open the APK** — Files app → Downloads → tap `app-release.apk`.
4. **Confirm the install** — Play Protect-style warning ("This type of file can
   harm your device") → *Install anyway*; explain why the warning appears for
   any side-loaded APK.
5. **First launch** — where the icon lands (Home / App Library), what the home
   screen shows.
6. **Set landscape & keep-awake for match use** (optional but recommended).
7. **Troubleshooting pointers** — "App not installed", storage space,
   needing to uninstall a debug build first, and the table's low-storage state.

!!! note
    Screenshots for every step are still to be captured (emulator AVD
    `fire_hd_10`), and belong inline next to the step they illustrate.

## Related

- [Other Android devices](android.md)
- [Install & launch problems](../troubleshooting/install-and-launch.md)
