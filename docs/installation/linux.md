# Linux

<!-- OUTLINE (docs pass): type = HOW-TO. Artifact: concordance-linux-x64.tar.gz
     (the Flutter `bundle/` directory tarred). Requires GTK3 + clang-built
     bundle; no .deb/.AppImage yet. Test on the dev machine + a clean VM. -->

## Outline

1. **Download** `concordance-linux-x64.tar.gz` from the Releases page.
2. **Extract** — `tar -xzf concordance-linux-x64.tar.gz` → gives `bundle/`.
3. **Run** — `./bundle/concordance`; note the executable bit is preserved by
   tar (contrast with the AppImage case below).
4. **Dependencies** — GTK 3 and the usual desktop libs must be present; the
   common "error while loading shared libraries: libgtk-3.so.0" fix per
   distro family (dnf/pacman/apt).
5. **Wayland vs X11** — what to do if the window is blank or ignores input
   (run with `GDK_BACKEND=x11`); X11 is the tested path today.
6. **Desktop entry (optional)** — a short `.desktop` file snippet so it appears
   in the app launcher.
7. **Alternatives** — AppImage/.deb/.rpm are not shipped yet; say so plainly
   rather than leaving the user hunting.

## Related

- [Specify checksum verification](verifying-downloads.md)
- [Install & launch problems](../troubleshooting/install-and-launch.md)
