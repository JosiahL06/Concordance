# Release artifacts & checksums

<!-- OUTLINE (docs pass): type = REFERENCE. Facts verified against
     .github/workflows/build.yml: tags build four platforms and the release
     job flattens every artifact into dist/ and writes SHA256SUMS. -->

**Goal:** know exactly what each release contains and how it is produced.

## To cover

- **Table: artifact → platform → what it is**

  | File | Platform | Notes |
  | --- | --- | --- |
  | `app-release.apk` | Android / Fire (primary) | GMS-free; side-loadable |
  | `concordance-windows-x64.zip` | Windows | portable bundle (no installer yet) |
  | `concordance-linux-x64.tar.gz` | Linux | `bundle/` directory |
  | `concordance-macos.zip` | macOS | zipped `.app` |
  | `SHA256SUMS` | — | one SHA-256 line per file above |

- **How a release is produced** — a `v*` tag triggers the four-platform build;
  artifacts are attached to the GitHub release together with `SHA256SUMS`, so a
  download can always be tied back to a tag.
- **Where else builds appear** — CI artifacts on non-tag runs (short-lived);
  the Releases page is the canonical place.
- **Signing status** — Android release builds are signed with the project
  keystore; desktop builds are **unsigned** (and macOS is unnotarized) — one
  sentence each, linking the OS install pages.
- **Verification** — link to the how-to; do not repeat the commands here.

## Related

- [Verifying your download](../installation/verifying-downloads.md)
- [Changelog](../CHANGELOG.md)
