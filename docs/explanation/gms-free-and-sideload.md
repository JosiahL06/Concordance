# GMS-free & sideload-only

<!-- OUTLINE (docs pass): type = EXPLANATION.
     Explains why "download an APK and tap it" is the normal install path for
     this app rather than a hack, and what that means for the user. -->

## Outline

- **The target device has no Google Play services** — Amazon Fire tablets run
  Fire OS, which has no Play Store and no Google APIs; the app and every
  library it uses are deliberately GMS-free so this is a supported target, not
  a compromise.
- **What "sideload" actually means** — installing an APK from a trusted source
  instead of a store; the device warns you once, and that warning is expected.
- **Why not publish to stores?** — the store question, the account/review cost,
  and that the project would rather ship an offline tool directly than depend
  on a store account for something this small (also note the AGPL-3.0-only
  licensing stance).
- **What you give up** — automatic updates; you install each new release
  yourself (link to Updating), and the app does not check for updates (it never
  goes online).
- **Trust model** — releases are checksummed and the APK is signed with a
  project keystore; verification is how you confirm a download.
- **Other devices are first-class too** — Windows/Linux/macOS bundles exist for
  practice and desktop use.

## Related

- [Amazon Fire HD 10](../installation/fire-hd-10.md)
- [Verifying your download](../installation/verifying-downloads.md)
- [Release artifacts & checksums](../reference/release-artifacts.md)
