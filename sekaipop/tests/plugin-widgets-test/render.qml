import QtQuick
import QtQuick.Window
import "FakeTheme.js" as FT

// Draws a plugin's Widget.qml outside the shell, framed the way PluginWidgetHost frames it,
// and saves a PNG. For looking at a widget in each mode without a running shell.
//
//   QT_QPA_PLATFORM=offscreen qml render.qml -- <plugin dir> <out.png> [mode] [palette] [fixture.js] [wait ms]
//
// mode: light | dark | darker (default dark). palette: vs, leoneed, mmj, vbs, wxs, nightcord, mono.
// fixture.js (optional, next to this file or a full path): `.pragma library` with
//   function settings()   -> overrides of the manifest's defaults
//   function service(Qt)  -> what the widget reads as host.service (plain properties are enough)
Window {
    id: win
    visible: true
    color: "#8a8a99"            // a neutral "desk" so the card's edges show
    width: Math.max(80, card.width + 40)
    height: Math.max(60, card.height + 40)

    readonly property var args: {
        const a = Qt.application.arguments
        const i = a.indexOf("--")
        return i >= 0 ? a.slice(i + 1) : []
    }
    readonly property string dir: args[0] || "."
    readonly property string out: args[1] || "out.png"
    readonly property string mode: args[2] || "dark"
    readonly property string paletteName: args[3] || "vs"
    readonly property string fixture: args[4] || ""
    readonly property int wait: parseInt(args[5] || "1500")

    property var manifest: ({})
    property var fx: null
    readonly property var theme: FT.theme(win.mode, win.paletteName)
    property Item widget: null

    function readFile(path) {
        const x = new XMLHttpRequest()
        x.open("GET", "file://" + path, false)
        x.send()
        return x.responseText
    }

    Component.onCompleted: {
        win.manifest = JSON.parse(win.readFile(win.dir + "/plugin.json"))
        if (win.fixture !== "") {
            const url = win.fixture.startsWith("/") ? "file://" + win.fixture : Qt.resolvedUrl(win.fixture)
            const comp = Qt.createComponent(Qt.resolvedUrl("FixtureLoader.qml"))
            const loader = comp.createObject(win, { source: url })
            win.fx = loader.lib
        }
        const settings = Object.assign({}, win.manifest.settings || {}, win.fx && win.fx.settings ? win.fx.settings() : {})
        const host = {
            apiVersion: 1, id: win.manifest.id, name: win.manifest.name, version: win.manifest.version,
            dir: win.dir, path: rel => win.dir + "/" + rel,
            theme: win.theme, settings: settings, setSetting: (k, v) => { settings[k] = v; return true },
            secrets: {}, reloadSecrets: () => {}, screenName: "DP-1", scale: 1, clone: false,
            working: true, editing: false, selected: false, wanted: ["widget"],
            service: win.fx && win.fx.service ? win.fx.service(Qt) : null
        }
        const c = Qt.createComponent("file://" + win.dir + "/Widget.qml")
        if (c.status !== Component.Ready) {
            console.error("render: " + c.errorString())
            Qt.exit(1)
            return
        }
        win.widget = c.createObject(slot, { host: host })
        if (!win.widget) {
            console.error("render: could not create the widget")
            Qt.exit(1)
        }
    }

    readonly property bool framed: win.manifest.frame !== false
    readonly property int inset: win.framed ? theme.borderWidth + theme.outerRingWidth + 10 : 0

    Item {
        id: card
        x: 20
        y: 20
        width: (win.widget ? win.widget.implicitWidth : 100) + win.inset * 2
        height: (win.widget ? win.widget.implicitHeight : 60) + win.inset * 2 + (win.framed ? win.theme.shadowOffset : 0)

        // the housing: hard shadow, outline + pale ring, fill (Pill.qml)
        Rectangle {
            visible: win.framed
            y: win.theme.shadowOffset
            width: parent.width
            height: parent.height - win.theme.shadowOffset
            radius: win.theme.radiusOuter
            color: win.theme.pLineShadow
        }
        Rectangle {
            visible: win.framed
            width: parent.width
            height: parent.height - win.theme.shadowOffset
            radius: win.theme.radiusOuter
            color: win.theme.pSurfaceRing
            border.width: win.theme.borderWidth
            border.color: win.theme.pLine
            Rectangle {
                anchors.fill: parent
                anchors.margins: win.theme.borderWidth + win.theme.outerRingWidth
                radius: Math.max(0, win.theme.radiusOuter - win.theme.borderWidth - win.theme.outerRingWidth)
                color: win.theme.pSurface
            }
        }
        Item {
            id: slot
            x: win.inset
            y: win.inset
            width: win.widget ? win.widget.implicitWidth : 0
            height: win.widget ? win.widget.implicitHeight : 0
        }
    }

    Timer {
        interval: win.wait
        running: true
        onTriggered: win.contentItem.grabToImage(r => {
            r.saveToFile(win.out)
            Qt.exit(0)
        })
    }
}
