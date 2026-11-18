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
     kscreen-doctor output.DP-1.iccprofile."~/gamma-icc-master/sRGB-0.7G.icc"
                              │
                              ▼
          KWin applies the ICC profile in its colour pipeline + on-screen OSD
```

- **ICC profiles do the work.** Each gamma value is a ready-made sRGB ICC profile
  (`sRGB-0.5G.icc` … `sRGB-1.5G.icc`, step 0.05). KWin applies it in software, so switching is
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
`Meta+PgUp/PgDown` (maximize/minimize). Change them anytime in
System Settings › Keyboard › Shortcuts (search for "Gamma").

## Requirements

- KDE Plasma 6, Wayland session
- `kscreen-doctor`, `qdbus6`, `kbuildsycoca6`, `kwriteconfig6` (all part of Plasma), `flock` (util-linux)
- A folder of gamma ICC profiles named `sRGB-<value>G.icc` with values from 0.5 to 1.5 in
  steps of 0.05, written without trailing zeros (`0.5`, `0.55`, `1.0`, `1.05`).

## Install

```sh
git clone https://github.com/<you>/gamma-switch.git
cd gamma-switch
bash install.sh
```

This symlinks `bin/gamma` to `~/.local/bin/gamma` and installs the shortcuts as
`~/.local/share/applications/gamma-*.desktop`. If the shortcuts don't respond right away, log
out and back in.

Uninstall with `bash install.sh --uninstall`.

## Configuration

Environment variables (set them in the `.desktop` `Exec=` lines or your session environment):

| Variable         | Default                   | Meaning                      |
|------------------|---------------------------|------------------------------|
| `GAMMA_ICC_DIR`  | `~/gamma-icc-master`      | Folder with the ICC profiles |
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

## Notes

OSD messages are in Portuguese (`Gamma normal`, `falha ao aplicar`, …); edit `bin/gamma` to
change them.
