# A wallpaper per monitor

With more than one monitor, each can have its own wallpaper (and its own lockscreen wallpaper),
and a desktop preset keeps them.

## Choosing where a wallpaper goes

Open a picture in the wallpaper board (the phone's Wallpapers screen). Above **Set as Desktop** and
**Set as Lockscreen**, a **Set on** row lists **All monitors** and each connected monitor, each with
a thumbnail of what it shows now; **here** marks the monitor the board is open on. The chosen one
is lit. Then Set:

- **All monitors**: the picture goes on every monitor.
- **One monitor**: only that one changes. If **One wallpaper per monitor** (Settings > Desktop >
  Wallpaper) is off, setting one monitor turns it on first, and every other monitor keeps exactly
  what it shows (each is pinned to its current picture), so nothing else blinks or changes.
- **Shift+click** on a Set key always means every monitor.

The row only shows with more than one monitor. What it starts on: this monitor while One wallpaper
per monitor is on, all monitors while it is off. Your choice stays while the board is open, and
goes back to that if the chosen monitor is unplugged.

## Presets

A desktop preset holds the wallpaper as it is: with One wallpaper per monitor on, each monitor's
picture (desktop and lockscreen) by its name, and the switch itself; with it off, the one picture.
Wearing the preset puts the switch back first and then each monitor's picture in one step. A monitor
the preset names that isn't connected is skipped; a picture whose file is gone leaves that monitor
as it is, and a notification says so.

## Where it lives

- `sekaipop/modules/sekai/wallpaperSelector/WallpaperMonitorTargets.qml`: the Set on row.
- `sekaipop/modules/sekai/wallpaperSelector/WallpaperFace.qml`: `screenTarget`, `applyTo()`; the
  Set keys go through it.
- `sekaipop/modules/common/functions/WallpaperTarget.js`: which monitor(s), and what a Set does
  (tests: `tests/wallpaper-target-test/tst_wallpaper_target.qml`, with Qt's qmltestrunner).
- `sekaipop/services/WallpaperService.qml`: `setWallpaper(path, monitor)`, `setPerMonitor()`,
  `pinMissing()` (keeps the other monitors on what they show).
- `sekaipop/services/DesktopPresetService.qml`: `wallpaper: { default, screens, lockDefault,
  lockScreens }` in a preset, worn by `applyWallpaper()`.
