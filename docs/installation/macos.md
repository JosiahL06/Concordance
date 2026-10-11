# macOS

<!-- OUTLINE (docs pass): type = HOW-TO. Artifact: concordance-macos.zip
     (a zipped .app). Unsigned + unnotarized → Gatekeeper blocks it.
     This page is important: the double-click failure looks like a broken app
     to a non-technical user, so lead with the fix. -->

## Outline

1. **Which Mac** — Apple silicon vs Intel: the CI build is a single artifact;
   state exactly what it contains (universal vs arm64-only — confirm from the
   build workflow before publishing this page) and what Rosetta means if the
   user is on the other architecture.
2. **Download** `concordance-macos.zip` from the Releases page and unzip it.
3. **Move it to Applications** — drag `Concordance.app` there, because running
   it from Downloads trips Gatekeeper on every launch.
4. **First launch (unsigned app)** — the warning "cannot be opened because the
   developer cannot be verified"; give both paths:
   - right-click (or Control-click) the app → **Open** → **Open** again, and
   - the `xattr -dr com.apple.quarantine /Applications/Concordance.app`
     terminal one-liner, with a plain-language explanation of what it does.
5. **Why this happens** — the build is unsigned/unnotarized; notarization needs
   a paid Apple Developer account (link the roadmap/security notes).
6. **Uninstalling** — drag to Trash plus where the round database lives.

!!! note
    Screenshots must be captured on an actual Mac — this machine cannot run
    `flutter build macos` (see the toolchain notes).

## Related

- [Verifying your download](verifying-downloads.md)
- [Updating & uninstalling](updating-and-uninstalling.md)
