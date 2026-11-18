# gamma-switch

Switch your monitor's gamma with a keyboard shortcut on **KDE Plasma 6 (Wayland)** — no more
digging through System Settings › Display to pick an ICC profile.

Built for rhythm games like osu!, where a brighter gamma helps you read fast-approaching
circles (e.g. DT on high-AR maps), but it works anywhere.

## How it works

```
 keyboard shortcut ──► KDE global shortcut (.desktop file)
                              │
                              ▼
                         bin/gamma <action>
                              │  reads/writes ~/.local/state/gamma-switch/state
                              ▼
     kscreen-doctor output.DP-1.iccprofile."<repo>/icc/sRGB-0.7G.icc"
                              │
                              ▼
          KWin applies the ICC profile in its colour pipeline + on-screen OSD
```

- **ICC profiles do the work.** Each gamma value is a ready-made sRGB ICC profile
  (`sRGB-0.5G.icc` … `sRGB-1.5G.icc`, step 0.05), bundled in [`icc/`](icc/) (see
  [Credits](#credits)). KWin applies it in software, so switching is
  instant-ish and does nothing to the monitor hardware.
- **`kscreen-doctor`** (ships with Plasma) sets the profile on the output. An empty path removes
  it, returning to "no ICC profile".
- **State** is a tiny file holding the current value and whether gamma is on, so the toggle
  remembers the last value you picked. Values are stored as integer hundredths (70 = 0.7) to avoid
  floating-point drift. Writes are atomic and runs are serialized with `flock`, so mashing a key
  never loses steps or leaves a half-written file; a corrupt file falls back to the defaults.
- **Feedback** comes from the Plasma OSD (falls back to `notify-send`), so you can see the value
  even inside a fullscreen game.
- **Shortcuts** are plain `.desktop` files with `X-KDE-Shortcuts=`; KDE registers them as global
  shortcuts. No daemon runs in the background.

## Shortcuts

| Shortcut              | Action                                                        |
|-----------------------|---------------------------------------------------------------|
| `Meta+Shift+G`        | Toggle gamma on/off (default 0.7; remembers the last value)   |
| `Meta+Shift+PgUp`     | Gamma +0.05 (max 1.5; turns gamma on if it was off)           |
| `Meta+Shift+PgDown`   | Gamma −0.05 (min 0.5; turns gamma on if it was off)           |
| `Meta+Alt+G`          | Back to normal (no ICC) and reset the stored value to 0.7     |

`Meta` is the Windows/Super key. The defaults avoid KWin's built-in `Meta+G` (Grid View) and
`Meta+PgUp/PgDown` (maximize/minimize). See [Changing the shortcuts](#changing-the-shortcuts).

## Requirements

- KDE Plasma 6, Wayland session
- `kscreen-doctor`, `qdbus6`, `kbuildsycoca6`, `kwriteconfig6` (all part of Plasma), `flock` (util-linux)

The ICC profiles come with the repository, nothing else to download.

## Install

```sh
git clone https://github.com/maats01/gamma-switch.git
cd gamma-switch
bash install.sh
```

This symlinks `bin/gamma` to `~/.local/bin/gamma` and installs the shortcuts as
`~/.local/share/applications/gamma-*.desktop`. If the shortcuts don't respond right away, log
out and back in.

Keep the cloned folder where it is: the command and the profiles are used straight from it.

Uninstall with `bash install.sh --uninstall`.

## Configuration

### Changing the default gamma

The default value (used on the first toggle and restored by `Meta+Alt+G` / `gamma reset`) is
0.7. To change it, edit this line near the top of [`bin/gamma`](bin/gamma):

```sh
DEFAULT=70   # valores em centésimos: 70 = 0.7
```

The value is in hundredths: `80` = 0.8, `100` = 1.0, `65` = 0.65. It must be between `50` and
`150` and a multiple of `5` (there is one profile per 0.05 step). Since `~/.local/bin/gamma` is
a symlink to this file, the change takes effect immediately, with no reinstall.

The toggle remembers the last value you picked, so after editing run `gamma reset` (or press
`Meta+Alt+G`) once to start from the new default.

Below 1.0 the screen gets brighter (shadows lifted); above 1.0 it gets darker.

### Changing the shortcuts

**Through System Settings (easiest):** System Settings › Keyboard › Shortcuts, search for
"Gamma", click the shortcut and press the new keys. This is stored in your KDE config only;
note that running `install.sh` again puts the repository defaults back.

**In the repository (permanent):** edit the `X-KDE-Shortcuts=` line of the matching file in
[`shortcuts/`](shortcuts/), then reinstall:

| File                           | Action        |
|--------------------------------|---------------|
| `shortcuts/gamma-toggle.desktop` | toggle on/off |
| `shortcuts/gamma-up.desktop`     | gamma +0.05   |
| `shortcuts/gamma-down.desktop`   | gamma −0.05   |
| `shortcuts/gamma-reset.desktop`  | reset         |

```ini
X-KDE-Shortcuts=Meta+Shift+G
```

Use KDE key names joined with `+`: modifiers `Meta`, `Ctrl`, `Alt`, `Shift`; keys like `G`,
`F9`, `PgUp`, `PgDown`, `Home`, `End`, `Up`, `Down`. Then:

```sh
bash install.sh
```

If the new keys don't respond, log out and back in. Avoid combinations KDE already uses
(System Settings › Keyboard › Shortcuts shows conflicts).

### Environment variables

Set them in the `.desktop` `Exec=` lines or your session environment:

| Variable         | Default                   | Meaning                      |
|------------------|---------------------------|------------------------------|
| `GAMMA_ICC_DIR`  | `icc/` in this repository | Folder with the ICC profiles (named `sRGB-<value>G.icc`, e.g. `sRGB-0.7G.icc`, `sRGB-1.05G.icc`) |
| `GAMMA_OUTPUT`   | `DP-1`                    | Output name (see `kscreen-doctor -o`) |
| `XDG_STATE_HOME` | `~/.local/state`          | Where the state file lives   |

## Command line

```sh
gamma toggle | up | down | reset | status
```

`status` prints e.g. `on 0.7` or `off 0.7`. Exit codes: 0 ok, 1 error (missing profile or
`kscreen-doctor` failure, nothing is saved), 2 bad usage.

## Tests

```sh
bash tests/run.sh
```

Plain bash, no dependencies: `kscreen-doctor`, `qdbus6` and `notify-send` are replaced by stubs
on `PATH`, so the tests never touch your real display.

## Credits

The ICC profiles in [`icc/`](icc/) were created by **[ien646](https://github.com/ien646)** and
come unchanged from [ien646/gamma-icc](https://github.com/ien646/gamma-icc), released into the
public domain under the [Unlicense](icc/LICENSE). They are bundled here only for convenience;
all credit for them goes to the original author. See [`icc/README.md`](icc/README.md).

## Notes

OSD messages are in Portuguese (`Gamma normal`, `falha ao aplicar`, …); edit `bin/gamma` to
change them.
