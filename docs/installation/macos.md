# macOS

The Mac version is a normal app you drag into your Applications folder. The only
tricky part is the first launch, which macOS blocks until you tell it the app is
safe. This page covers both.

## Which Mac you need

The download is built for Apple silicon Macs — the ones with an M1 chip or
newer. On an older Intel Mac the app will not open, because the download
contains only the Apple silicon version. Support for Intel Macs is something a
future release may add.

## 1. Download and unzip it

Download `concordance-macos.zip` from the project's
[Releases page](https://github.com/JosiahL06/Concordance/releases), then
double-click the zip file to unzip it. You get an app called
**Concordance.app**.

## 2. Move it into Applications

Drag **Concordance.app** into your **Applications** folder. If you leave it in
your Downloads folder, macOS will make you step past a warning every single time
you open it.

## 3. Open it for the first time

macOS will refuse the first launch, with a message such as *"Concordance.app
cannot be opened because the developer cannot be verified."* This is macOS being
careful about an app it does not recognise. There are two ways past it:

- **Right-click (or Control-click) the app**, choose **Open**, then click
  **Open** again in the box that appears.
- Or open the **Terminal** app and run this line:

  ```sh
  xattr -dr com.apple.quarantine /Applications/Concordance.app
  ```

  It tells macOS to stop treating the app as an unknown download. You only need
  to do this once.

## 4. Why the warning appears

The Mac version is not signed or notarized by Apple. Notarizing an app requires
a paid Apple developer account, which the project does not have yet. Until then,
the steps above are the way in — and after that first launch, the app behaves
like any other.

## 5. Uninstalling

Drag **Concordance.app** from Applications to the Trash. Your saved rounds are
not kept inside the app, so remove those too if you want them gone. See
[Data & storage](../reference/data-and-storage.md) and
[Updating & uninstalling](updating-and-uninstalling.md).

## Related

- [Verifying your download](verifying-downloads.md)
- [Updating & uninstalling](updating-and-uninstalling.md)
