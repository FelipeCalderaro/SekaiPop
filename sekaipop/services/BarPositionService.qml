pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

// Which screen edge the bar sits on. One value for the whole shell (every
// monitor's bar follows it), remembered across restarts.
//
//   top, bottom   the bar lies flat: workspaces on the left, clock on
//                 the right (the layout it always had)
//   left, right   the bar stands up: workspaces at the top, clock at the
//                 bottom, every widget stacked in a column
//
// The Settings Panel (Bar -> Position) calls setPosition(). From a
// keybind:
//   qs -c sekaipop ipc call barposition cycle
//   qs -c sekaipop ipc call barposition set left
//   qs -c sekaipop ipc call barposition get
Singleton {
    id: root

    // The order the button steps through.
    readonly property var names: ["top", "right", "bottom", "left"]

    property string position: "top"

    readonly property int index: Math.max(0, root.names.indexOf(root.position))

    // True for left / right: the bar stands up.
    readonly property bool vertical: root.position === "left" || root.position === "right"

    // How thick a bar on the given edge is, in design pixels (before the
    // per-monitor scale). Bar.qml asks for its own edge's value (a bar
    // window never changes edge once it exists, see shell.qml), so a bar
    // that is on its way out can't be resized by the new position.
    function thicknessFor(name) {
        return (name === "left" || name === "right") ? 74 : 63
    }

    // How thick the bar is on the current edge. Popups, the dock and the
    // OSD keep clear of it.
    readonly property int thickness: root.thicknessFor(root.position)

    // The space the bar reserves on its edge (what the compositor keeps windows and
    // pinned layers out of): none while it auto-hides.
    readonly property int reserved: SettingsService.get("bar.hideMode") === "auto" ? 0 : root.thickness

    // ===== per monitor =====
    // Settings -> Bar -> This monitor (`bar.screens`, JSON keyed by output name). Each
    // monitor may:
    //   hidden    have no bar at all (the other monitors keep theirs)
    //   position  sit on its own edge ("" = the shell-wide `position` above)
    //   wrap      "auto": a flat bar too narrow for its modules (a portrait monitor) grows
    //             a second (or third) row instead of letting the zones run over each other;
    //             "off": one row, as before
    // From a keybind or a script:
    //   qs -c sekaipop ipc call barposition setscreen HDMI-A-2 left      ("default" = follow)
    //   qs -c sekaipop ipc call barposition hidescreen HDMI-A-2 true
    //   qs -c sekaipop ipc call barposition wrapscreen HDMI-A-2 off
    readonly property var wrapModes: ["auto", "off"]
    readonly property var screenPrefs: {
        try {
            const j = JSON.parse(SettingsService.get("bar.screens") || "{}")
            return j && typeof j === "object" && !Array.isArray(j) ? j : ({})
        } catch (e) {
            return ({})
        }
    }

    function prefsFor(name) {
        const p = (name && root.screenPrefs[name]) || {}
        return {
            hidden: p.hidden === true,
            position: root.names.indexOf(p.position) >= 0 ? p.position : "",
            wrap: root.wrapModes.indexOf(p.wrap) >= 0 ? p.wrap : "auto"
        }
    }

    // The edge the bar on this monitor sits on.
    function positionFor(name) {
        return root.prefsFor(name).position || root.position
    }

    // This monitor has its own edge (rather than following the shell-wide one).
    function ownPosition(name) {
        return root.prefsFor(name).position !== ""
    }

    function hiddenOn(name) {
        return root.prefsFor(name).hidden
    }

    function wrapFor(name) {
        return root.prefsFor(name).wrap
    }

    // Change one of a monitor's own choices. A choice set back to its default is dropped,
    // and a monitor with nothing of its own left is dropped from the JSON entirely.
    function setScreenPref(name, key, value) {
        if (!name || ["hidden", "position", "wrap"].indexOf(key) < 0)
            return
        const all = JSON.parse(JSON.stringify(root.screenPrefs))
        const mine = Object.assign({}, all[name] || {})
        const isDefault = (key === "hidden" && value !== true)
            || (key === "position" && root.names.indexOf(value) < 0)
            || (key === "wrap" && value !== "off")
        if (isDefault)
            delete mine[key]
        else
            mine[key] = value
        if (Object.keys(mine).length === 0)
            delete all[name]
        else
            all[name] = mine
        SettingsService.set("bar.screens", JSON.stringify(all))
    }

    // How much thicker than its design thickness each monitor's bar is right now, in design
    // pixels: a wrapped bar's extra rows (Bar.qml reports it). { name: { edge, extra } }.
    property var liveExtra: ({})

    function reportExtra(name, edge, extra) {
        if (!name)
            return
        const cur = root.liveExtra[name]
        // A bar that is going away (it moved edge) does not clear its successor's report.
        if (extra === 0 && cur && cur.edge !== edge)
            return
        if (cur && cur.edge === edge && cur.extra === extra)
            return
        const next = Object.assign({}, root.liveExtra)
        next[name] = { edge: edge, extra: extra }
        root.liveExtra = next
    }

    // The bar's thickness on this monitor, design pixels: its edge's, plus any wrapped rows;
    // 0 when the monitor has no bar. Popups, the OSD and the dock keep clear of this.
    function thicknessOn(name) {
        if (root.hiddenOn(name))
            return 0
        const edge = root.positionFor(name)
        const e = root.liveExtra[name]
        return root.thicknessFor(edge) + (e && e.edge === edge ? e.extra : 0)
    }

    // What the bar reserves on this monitor (none while it auto-hides or is hidden).
    function reservedOn(name) {
        return SettingsService.get("bar.hideMode") === "auto" ? 0 : root.thicknessOn(name)
    }

    // True once the saved edge has been read (or there is nothing saved,
    // or reading it failed). shell.qml doesn't create any bar before
    // this, so the bar is built once on the right edge instead of being
    // built on "top" and then moved.
    property bool loaded: false

    // Set once the user (or IPC) has picked something this session, so
    // the startup load below can't land late and undo it.
    property bool touched: false

    function setPosition(name) {
        if (root.names.indexOf(name) < 0)
            return
        root.touched = true
        if (root.position === name)
            return
        root.position = name
        saver.save(name)
    }

    function cycle() {
        root.setPosition(root.names[(root.index + 1) % root.names.length])
    }

    // ===== persistence =====
    readonly property string script: Directories.script("state/barposition-state.sh")

    // Runs once, at startup.
    Process {
        running: true
        command: ["sh", root.script, "load"]
        stdout: StdioCollector {
            onStreamFinished: {
                const name = text.trim()
                if (!root.touched && root.names.indexOf(name) >= 0)
                    root.position = name
                root.loaded = true
            }
        }
    }

    // Safety net: if the load above never reports back (no `sh`, a stuck
    // read), start with whatever edge is set rather than having no bar.
    Timer {
        interval: 1500
        running: !root.loaded
        onTriggered: root.loaded = true
    }

    Process {
        id: saver

        property string pending: ""

        function save(name) {
            if (saver.running) {
                saver.pending = name
                return
            }
            saver.pending = ""
            saver.exec(["sh", root.script, "save", name])
        }

        onExited: {
            if (saver.pending !== "") {
                const name = saver.pending
                saver.pending = ""
                saver.exec(["sh", root.script, "save", name])
            }
        }
    }

    IpcHandler {
        target: "barposition"

        function set(name: string): void {
            root.setPosition(name)
        }

        function cycle(): void {
            root.cycle()
        }

        function get(): string {
            return root.position
        }

        // Per monitor (see `screenPrefs`). `edge` "default" follows the shell-wide edge.
        function setscreen(screen: string, edge: string): void {
            root.setScreenPref(screen, "position", edge)
        }

        function hidescreen(screen: string, hidden: bool): void {
            root.setScreenPref(screen, "hidden", hidden)
        }

        function wrapscreen(screen: string, mode: string): void {
            if (root.wrapModes.indexOf(mode) >= 0)
                root.setScreenPref(screen, "wrap", mode)
        }

        function getscreen(screen: string): string {
            return JSON.stringify(Object.assign({ edge: root.positionFor(screen) }, root.prefsFor(screen)))
        }
    }
}
