# Windows

<!-- OUTLINE (docs pass): type = HOW-TO. Artifact: concordance-windows-x64.zip
     (a portable bundle — no installer yet). Unsigned → SmartScreen warning.
     Verify on a real Windows touchscreen laptop, then screenshot each step. -->

## Outline

1. **Download** `concordance-windows-x64.zip` from the Releases page.
2. **Unzip** — right-click → *Extract All…*; explain why the app must run from
   the extracted folder (the `.exe` needs the `data/` and `*.dll` files beside
   it — running it from inside the zip will not work).
3. **Run it** — `concordance.exe`, first launch is slow (one-time unpack).
4. **The SmartScreen warning** — "Windows protected your PC" → **More info** →
   **Run anyway**; explain the build is unsigned (no code-signing certificate
   yet) and link to the roadmap note about signed builds. Also cover the
   Defender/HVCI banner if seen.
5. **Pin it** — right-click the `.exe` → *Pin to Start*, so a scorekeeper never
   has to hunt through Downloads.
6. **Touch & display** — landscape tablet-style window default; the console
   targets ≥48 dp so touchscreens work without a keyboard.

!!! note
    Installer (.msix/.exe setup) and code signing are post-v1 (see the
    roadmap); this page documents the portable-zip flow that ships today.

## Related

- [Verifying your download](verifying-downloads.md)
- [Updating & uninstalling](updating-and-uninstalling.md)
