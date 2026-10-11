# Release artifacts & checksums

**Goal:** know exactly what each release contains and how it is produced.

## What a release contains

| File | Platform | Notes |
| --- | --- | --- |
| `app-release.apk` | Android / Fire (recommended) | The app file for tablets and phones |
| `concordance-windows-x64.zip` | Windows | A folder of files to run |
| `concordance-linux-x64.tar.gz` | Linux | A folder of files to run |
| `concordance-macos.zip` | macOS | The app, ready to drag into Applications |
| `SHA256SUMS` | — | One code per file above, for checking a download |

## How a release is made

When the project publishes a new version, a single build makes all four files
from the same set of code and attaches them to the release, together with the
`SHA256SUMS` file. Because every file in a release comes from one build, a
download can always be tied back to the exact version it came from.

## Where to get it

The [Releases page](https://github.com/JosiahL06/Concordance/releases) is the
place to download. You may occasionally see temporary builds attached to the
project's other pages while a version is being prepared; those are only for
testing and should be ignored. The Releases page always holds the builds meant
for use.

## Are the files signed?

- The **Android and Fire** app file is signed, using the project's own signing
  key. That signature is what lets a new version install over an older one.
- The **Windows, Linux, and Mac** builds are **not signed** yet, and the Mac app
  is also not notarized. That is why your computer shows a warning the first
  time you open them — each install page explains which button to press. Signed
  desktop builds are planned for a later release.

## Checking a download

Every release includes the `SHA256SUMS` file so you can confirm a download is
genuine. The steps are on
[Verifying your download](../installation/verifying-downloads.md).

## Related

- [Verifying your download](../installation/verifying-downloads.md)
- [Changelog](../CHANGELOG.md)
