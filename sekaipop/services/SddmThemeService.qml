pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

// Keeps SekaiPop's SDDM login screen (sekaipop/sddm/sekaipop, docs/SDDM.md) in step with the
// shell: the lockscreen's colours (LockPalette, so a matugen lockscreen and Monochrome come along),
// the lockscreen wallpaper of the main monitor (a still for a video), your avatar, 12/24 h and the
// sparkles. scripts/theming/sddm-theme.sh `sync` writes them to /var/lib/sekaipop-sddm, which the
// installed theme reads at the next login. With the theme not installed, sync does nothing.
//
// A moment after the last change (changes come in bursts at start and on a theme switch), never
// more than one run at a time.
Singleton {
    id: root

    // Read once from shell.qml so this exists from the start (singletons are made when first read).
    readonly property bool ready: true

    readonly property string script: Directories.script("theming/sddm-theme.sh")

    function hex(c) { return Qt.color(c).toString() }

    function args() {
        const p = ThemeService.lockPalette || ThemeService.palette
        const out = ["sync"]
        for (const k of ["border", "A", "B", "deep", "rimHi", "glint", "wallMid"])
            if (p && p[k] !== undefined && p[k] !== null)
                out.push(k + "=" + root.hex(p[k]))
        // the lockscreen's own mint and pink (worked out when the palette has none)
        out.push("lockMint=" + root.hex(LockPalette.mint), "lockPink=" + root.hex(LockPalette.pink))
        out.push("mono=" + (p && p.mono === true ? "true" : "false"))
        out.push("use24h=" + (SettingsService.flag("time.use24h") ? "true" : "false"))
        out.push("animations=" + (SettingsService.flag("lock.animations") ? "true" : "false"))
        const bg = WallpaperService.lockImagePathFor(WallpaperService.themeScreen)
        if (bg !== "")
            out.push("background=" + bg)
        if (PanelImages.avatarPath !== "")
            out.push("avatar=" + PanelImages.avatarPath)
        const me = Quickshell.env("USER")
        if (me)
            out.push("user=" + me)
        return out
    }

    // what goes into a sync, as one string: a change in any of it runs one
    readonly property string signature: {
        const p = ThemeService.lockPalette
        return JSON.stringify([p, root.hex(LockPalette.mint), root.hex(LockPalette.pink),
            SettingsService.flag("time.use24h"), SettingsService.flag("lock.animations"),
            WallpaperService.lockImagePathFor(WallpaperService.themeScreen), PanelImages.avatarPath])
    }
    onSignatureChanged: debounce.restart()

    Timer {
        id: debounce
        interval: 2500
        onTriggered: {
            if (!SettingsService.loaded || !WallpaperService.ready)
                return debounce.restart()
            if (proc.running)
                proc.again = true
            else
                proc.exec(["sh", root.script].concat(root.args()))
        }
    }

    Process {
        id: proc
        property bool again: false
        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "") console.log("[SddmThemeService]", text.trim())
        }
        onExited: {
            if (proc.again) {
                proc.again = false
                debounce.restart()
            }
        }
    }

    Component.onCompleted: debounce.restart()

    IpcHandler {
        target: "sddmtheme"
        function sync(): void { debounce.restart() }
        function status(): string { return "run: sh " + root.script + " status" }
    }
}
