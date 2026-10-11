# Verifying your download

Every release includes a small text file called `SHA256SUMS`. It lists a long
code for each file in the release. Checking those codes confirms that the file
you downloaded is exactly the file the project built — worth doing for something
you install on a tablet.

## What the file looks like

Open `SHA256SUMS` in any text editor. Each line has a long code, a couple of
spaces, and a file name:

```
<long code>  app-release.apk
<long code>  concordance-windows-x64.zip
<long code>  concordance-linux-x64.tar.gz
<long code>  concordance-macos.zip
```

## Checking your file

### Linux

Put `SHA256SUMS` in the same folder as your download, open a terminal there, and
run:

```sh
sha256sum -c SHA256SUMS
```

The word **OK** appears next to each file that matches.

### macOS

In Terminal, run:

```sh
shasum -a 256 -c SHA256SUMS
```

### Windows

Windows does not read the file for you. In the folder with your download, open a
Command Prompt and run this, using the name of the file you downloaded:

```bat
certutil -hashfile concordance-windows-x64.zip SHA256
```

It prints a code. Compare it, character for character, with the matching line in
`SHA256SUMS`. Every character has to be the same — there is no such thing as a
close match.

### Android and Fire tablets

Tablets cannot check these codes on their own. If you want to be sure, check the
file on a computer first, then copy it across to the tablet.

## If the codes do not match

Do not install the file; the download could have been tampered with and may be harmful to your device.
Delete it, download it again, and check once more. If
it still does not match, please report it — a mismatch should never be ignored.
See the [security policy](../SECURITY.md) for how to get in touch.

## Related

- [Release artifacts & checksums](../reference/release-artifacts.md)
- [Security policy](../SECURITY.md)
