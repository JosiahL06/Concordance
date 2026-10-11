# Install & launch problems

Every problem below is set out the same way: what you see, why it happens, and
how to fix it.

## Android and Fire tablets

### "App not installed"

**Why:** the most common cause is that a different copy of the app is already on
the tablet; a new install cannot replace one that was signed by someone else.
Less often, the download did not finish, or the tablet is out of storage.

**Fix:** remove any older copy of Concordance first, then install again. If that
does not help, free up some storage and download the file once more.

### "This type of file can harm your device"

**Why:** this is the warning Android shows for any app that did not come from an
app store. It is not a sign that anything is wrong with this particular file.

**Fix:** if you are confident you downloaded it from the project's Releases
page, tap **Install anyway**.

### The "unknown sources" setting is missing or greyed out

**Why:** newer versions of Android and Fire OS move this permission to the app
you are installing *from*, rather than having one switch for everything.

**Fix:** open **Settings** and look under **Security & Privacy** for **Install
unknown apps**, then allow your browser or file manager there. On older devices,
look for a single **Apps from Unknown Sources** switch instead.

### The app installed but there is no icon for it

**Why:** Fire tablets do not always put a new app on the home screen.

**Fix:** swipe up from the bottom of the home screen to open the **App Library**,
and look for it there.

## Windows

### "Windows protected your PC"

**Why:** Windows shows this for any app it does not recognise, and Concordance
is not yet signed.

**Fix:** click **More info**, then **Run anyway**.

### Nothing happens when you double-click the app

**Why:** the app was opened from inside the zip file, rather than from the
folder you extracted it to.

**Fix:** right-click the zip and choose **Extract All…** first, then run
`concordance.exe` from the extracted folder.

### A message about a missing file

**Why:** the same cause as above — the app needs the other files that came in
the zip, and it cannot find them from inside the zip.

**Fix:** run the app from the extracted folder, with all of its files beside it.

## Linux

### "error while loading shared libraries: libgtk-3.so.0"

**Why:** the app needs the GTK 3 library to draw its window, and your system
does not have it installed.

**Fix:** install GTK 3 with your package manager. The exact command for each
common distribution is on the [Linux page](../installation/linux.md).

### The window is blank, or clicks do nothing

**Why:** Concordance is tested on the classic Linux display system (called X11),
and some other setups do not agree with it.

**Fix:** start the app in that mode — the command is on the
[Linux page](../installation/linux.md).

### "Permission denied"

**Why:** the app was run from inside the archive rather than extracted first.

**Fix:** extract the archive, then run the app from the extracted folder.

## macOS

### "cannot be opened because the developer cannot be verified"

**Why:** the app is not signed or notarized by Apple, so macOS is careful about
it.

**Fix:** right-click (or Control-click) the app, choose **Open**, then click
**Open** again in the box. The other method is described on the
[macOS page](../installation/macos.md).

### "The app is damaged and can't be opened"

**Why:** the tool that unzipped the download did not preserve the app's internal
links.

**Fix:** use your Mac's own unzip — double-click the zip file in Finder — rather
than a third-party tool.

### The app will not open on an older Intel Mac

**Why:** the download is built for Apple silicon Macs, so it will not run on an
older Intel Mac.

**Fix:** there is no fix yet. You can open an issue on the
[project's issues page](https://github.com/JosiahL06/Concordance/issues) to ask
about Intel support.

## Any device

### The app opens but the round looks empty

**Why:** you may have started a new round rather than opening the one you were
using.

**Fix:** return to the home screen and open your round from the **Resume round**
list.

## Related

- [Updating & uninstalling](../installation/updating-and-uninstalling.md)
- [Verifying your download](../installation/verifying-downloads.md)
