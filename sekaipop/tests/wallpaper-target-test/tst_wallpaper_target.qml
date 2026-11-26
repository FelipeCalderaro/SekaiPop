import QtQuick
import QtTest
import "../../modules/common/functions/WallpaperTarget.js" as WT

// /usr/lib/qt6/bin/qmltestrunner -platform offscreen -input tests/wallpaper-target-test   (from sekaipop/)
TestCase {
    name: "WallpaperTarget"
    readonly property var two: ["HDMI-A-2", "DP-1"]

    function test_default_follows_the_mode() {
        compare(WT.resolve("", two, false, "DP-1"), "all", "one wallpaper everywhere: every monitor")
        compare(WT.resolve("", two, true, "DP-1"), "DP-1", "one per monitor: this one")
    }

    function test_pick_wins_while_it_exists() {
        compare(WT.resolve("HDMI-A-2", two, false, "DP-1"), "HDMI-A-2")
        compare(WT.resolve("all", two, true, "DP-1"), "all")
        compare(WT.resolve("HDMI-A-1", two, true, "DP-1"), "DP-1", "a monitor that went away: back to the default")
    }

    function test_plan() {
        compare(WT.plan("HDMI-A-2", false, 2, false), { screen: "HDMI-A-2", turnOnPerMonitor: true })
        compare(WT.plan("HDMI-A-2", false, 2, true), { screen: "HDMI-A-2", turnOnPerMonitor: false })
        compare(WT.plan("HDMI-A-2", true, 2, true).screen, "", "Shift+click: every monitor")
        compare(WT.plan("DP-1", false, 1, false).screen, "", "one monitor: nothing to choose")
        compare(WT.plan("all", false, 3, true), { screen: "", turnOnPerMonitor: false })
    }

    function test_note() {
        compare(WT.note("all", true), "Sets every monitor. Shift+click: every monitor.")
        compare(WT.note("DP-1", true), "Sets DP-1 only. Shift+click: every monitor.")
        verify(WT.note("DP-1", false).indexOf("turns on One wallpaper per monitor") > 0)
    }
}
