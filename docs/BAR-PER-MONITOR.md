# A bar of its own on each monitor: hide, move, wrap

Each monitor's bar can now differ from the others in three ways, set from that monitor. The
case it was made for: a portrait monitor whose flat bar was too narrow for its modules, so the
three zones (left, centre, right) slid over each other and the centre's clock and date ended up
under the utility keys.

## Using it

**Settings > Bar > This monitor** (the card names the monitor the Settings phone is on):

| Choice | What it does |
| --- | --- |
| **Bar on this monitor** | Off: no bar on this monitor. The other monitors keep theirs. The global **Show bar** still hides every bar. |
| **Edge here** | **Same** follows **Position** above; Top / Right / Bottom / Left puts this monitor's bar there. |
| **When it doesn't fit** | **Wrap** (the default): a flat bar too narrow for its modules grows a second, or third, row. **Overlap**: one row, as it was before. |

A wrapped bar:

```
2 rows   [ left zone ............................... right zone ]
         [                    centre zone                       ]

3 rows   [                     left zone                        ]   (when even the left and right
         [                    centre zone                       ]    zones don't share a row)
         [                     right zone                       ]
```

A zone that has its row to itself is centred on it, so stacked rows read as one column; zones
sharing a row keep their edges.

The bar's window and the space it reserves grow with it, and the popups, the OSD, notifications,
the recording indicator and the dock keep clear of the taller bar. A standing bar (left or right
edge) never wraps; it folds its utility keys into one key with a flyout and then leaves out CPU /
RAM and the weather, as before.

From a script or a keybind (`<output>` is the monitor's name, `hyprctl monitors`):

```sh
qs -c sekaipop ipc call barposition hidescreen <output> true     # false shows it again
qs -c sekaipop ipc call barposition setscreen <output> left      # default = follow Position
qs -c sekaipop ipc call barposition wrapscreen <output> off      # or auto
qs -c sekaipop ipc call barposition getscreen <output>           # what it is set to
```

The choices are kept in `settings.json` as `bar.screens` (JSON keyed by output name). Desktop
presets never carry it: output names belong to one machine.

## How it works

| File | What it does |
| --- | --- |
| `services/BarPositionService.qml` | `screenPrefs` (read from `bar.screens`), `positionFor` / `hiddenOn` / `wrapFor` / `setScreenPref`, the bar's live thickness per monitor (`reportExtra`, `thicknessOn`, `reservedOn`), and the ipc. |
| `shell.qml` | Builds no bar for a hidden monitor and builds each on its own edge. The dock now finds its monitor's bar by screen, not by place in the list (with a monitor without a bar the two lists no longer line up). |
| `modules/sekai/bar/BarWrap.js` | The arithmetic: how many rows the zones need, which row each zone takes, where a row's middle is, and the hysteresis. Pure functions. |
| `modules/sekai/bar/Status_Bar.qml` | Measures each zone (`zoneNeed`), keeps `rows`, puts each zone on its row, and gives the media pill the room its row leaves. |
| `modules/sekai/bar/Bar.qml` | Makes the window `extraThickness` thicker and reports it. |
| NotificationPopup, OSDPopup, RecordingIndicator, RegionPreview, ReloadPopup, OnScreenKeyboard, Dock, QuickPanel | Read their own monitor's edge and thickness instead of the shell-wide one. |

**Why the measuring doesn't use the real widths of everything.** The media pill takes the room its
row leaves, which depends on the rows, so the fit is measured with the pill at its 220 px minimum;
the active-window pill is measured at its cap. A long song or window title therefore never changes
the bar's shape. A pill that appears (a Discord call, the privacy pill) can, which is the point. A
change waits 250 ms, and a row goes away again only once the bar fits with 32 px to spare, so a
width right at the edge never makes the bar flicker between shapes.

## Tests

```sh
node tests/bar-wrap-test/bar_wrap_unit.js    # from the sekaipop folder
```
