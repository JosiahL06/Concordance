# Linux

Concordance for Linux is a folder of files inside a single download. It does not
come with an installer package yet. These steps use a terminal, which is a few
short commands.

## 1. Download it

Download `concordance-linux-x64.tar.gz` from the project's
[Releases page](https://github.com/JosiahL06/Concordance/releases).

## 2. Extract it

Open a terminal in the folder where you downloaded the file and run:

```sh
tar -xzf concordance-linux-x64.tar.gz
```

That creates a folder called `bundle`.

## 3. Run it

```sh
./bundle/concordance
```

The file keeps its permission to run from the archive, so there is nothing extra
to set up.

## 4. If it says a library is missing

If the app refuses to start with a message mentioning `libgtk-3.so.0`, your
system is missing the GTK 3 library that the app draws its window with. Install
it with your distribution's package manager:

```sh
# Debian / Ubuntu
sudo apt install libgtk-3-0

# Fedora
sudo dnf install gtk3

# Arch
sudo pacman -S gtk3
```

## 5. If the window is blank or ignores clicks

Concordance is tested on the classic Linux display system (called X11). If the
window comes up blank, or your taps and clicks do nothing, start it like this
instead:

```sh
GDK_BACKEND=x11 ./bundle/concordance
```

## 6. Add it to your app menu (optional)

To launch Concordance without a terminal, create a file named
`~/.local/share/applications/concordance.desktop` with these contents, changing
the path to wherever you extracted `bundle`:

```ini
[Desktop Entry]
Name=Concordance
Exec=/home/you/Downloads/bundle/concordance
Type=Application
Categories=Utility;
```

## 7. What is not available yet

There is no `.deb`, `.rpm`, or one-file AppImage download yet. The archive above
is the only Linux download for now.

## Related

- [Verifying your download](verifying-downloads.md)
- [Install & launch problems](../troubleshooting/install-and-launch.md)
