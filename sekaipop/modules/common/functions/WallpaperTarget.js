.pragma library

// Where the wallpaper board's Set keys put a picture (WallpaperFace.qml, its "Set on" row):
// "all" or a monitor's name. Pure functions: tests/wallpaper-target-test/tst_wallpaper_target.qml.

// pick: what you chose ("" = nothing yet), names: the connected monitors, perMonitor: One
// wallpaper per monitor is on, here: the monitor the board is open on.
//   - your pick, while it still makes sense (all, or a monitor still connected);
//   - else this monitor when each monitor has its own wallpaper, every monitor when not.
function resolve(pick, names, perMonitor, here) {
    if (pick === "all" || (pick && names.indexOf(pick) >= 0))
        return pick
    return perMonitor && here ? here : "all"
}

// What a Set with this target does: { screen: "" for every monitor, else its name;
// turnOnPerMonitor: a single monitor needs One wallpaper per monitor on first }.
// Shift+click (all) and a single connected monitor always mean every monitor.
function plan(target, all, monitorCount, perMonitor) {
    if (all || monitorCount < 2 || target === "all")
        return { screen: "", turnOnPerMonitor: false }
    return { screen: target, turnOnPerMonitor: !perMonitor }
}

// The viewer's line about it.
function note(target, perMonitor) {
    if (target === "all")
        return "Sets every monitor. Shift+click: every monitor."
    return "Sets " + target + " only" + (perMonitor ? "." : " (and turns on One wallpaper per monitor; the others keep theirs).")
        + " Shift+click: every monitor."
}
