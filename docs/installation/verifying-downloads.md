# Verifying your download

<!-- OUTLINE (docs pass): type = HOW-TO, one task. Confirm the checksum file
     name and layout from the release job in .github/workflows/build.yml
     (it flattens the artifacts into a dist/ folder and generates a SHA-256
     list) before writing this — do not invent a filename. -->

**Why:** every release publishes SHA-256 checksums, so you can confirm the file
you downloaded is exactly what the project built — worth doing for a file you
side-load onto a tablet.

## Outline

- Where the checksum file lives on the Releases page and what it looks like
  (one line per artifact: `<hash>  <filename>`).
- **Linux**: `sha256sum -c <checksums-file>` in the download folder.
- **macOS**: `shasum -a 256 -c <checksums-file>`.
- **Windows**: `certutil -hashfile <file> SHA256` and compare by eye (explain
  that matching the whole string is required — no partial matches).
- **Android/Fire**: mention that checksum tooling is not built into the tablet,
  so verify on a computer before transferring the APK.
- What to do if it does *not* match: do not install, re-download, and report it
  (link the issue template / security policy).

## Related

- [Release artifacts & checksums](../reference/release-artifacts.md)
- [Security policy](../SECURITY.md)
