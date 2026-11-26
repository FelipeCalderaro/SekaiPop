import QtQuick
import QtQuick.Window

// Draws the SDDM theme (../sekaipop/Main.qml) outside SDDM, with stand-ins for what SDDM hands a
// theme, and saves a PNG. For looking at it without logging out.
//
//   QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qml render.qml -- <out.png> [palette] [state] [background]
//
// palette: vs | vbs | leoneed | mmj | wxs | nightcord | mono. state: idle | failed | busy | 12h | many.
Window {
    id: win
    width: 1920
    height: 1080
    visible: true

    readonly property var args: {
        const a = Qt.application.arguments, i = a.indexOf("--")
        return i >= 0 ? a.slice(i + 1) : []
    }
    readonly property string out: args[0] || "sddm.png"
    readonly property string palette: args[1] || "vs"
    readonly property string state: args[2] || "idle"
    readonly property string background: args[3] || ""

    // The shell's palettes (ThemeService.qml), as sddm-theme.sh writes them into theme.conf.user.
    readonly property var palettes: ({
        vs: { border: "#555473", A: "#04feee", B: "#00ffcb", deep: "#232235", rimHi: "#9796b8", glint: "#a9a6ff", wallMid: "#6e6d94", lockMint: "#7fe8d8", lockPink: "#ff75ac" },
        vbs: { border: "#561938", A: "#ff5c9a", B: "#ff96c0", deep: "#43142c", rimHi: "#d777a8", glint: "#ffa5c7", wallMid: "#c53c82" },
        leoneed: { border: "#2d3775", A: "#8ea3ff", B: "#9fd8ff", deep: "#181e3f", rimHi: "#808bce", glint: "#c1ccff", wallMid: "#4958b8" },
        mono: { border: "#444444", A: "#f4f4f4", B: "#bdbdbd", deep: "#1a1a1a", rimHi: "#9a9a9a", glint: "#d0d0d0", wallMid: "#757575", lockMint: "#e6e6e6", lockPink: "#9e9e9e", mono: "true" }
    })

    QtObject {
        id: fakeSddm
        property string hostName: "sekai-desk"
        property bool canSuspend: true
        property bool canReboot: true
        property bool canPowerOff: true
        signal loginFailed()
        signal loginSucceeded()
        function login(u, p, s) { console.log("login " + u + " session " + s) }
        function suspend() {}
        function reboot() {}
        function powerOff() {}
    }
    ListModel {
        id: fakeUsers
        property int lastIndex: 0
        ListElement { name: "vlk"; realName: "Mafuyu"; icon: "" }
        ListElement { name: "guest"; realName: "Guest"; icon: "" }
    }
    ListModel {
        id: fakeSessions
        property int lastIndex: 0
        ListElement { name: "Hyprland" }
        ListElement { name: "Plasma (Wayland)" }
    }
    QtObject {
        id: fakeKb
        property var layouts: [{ shortName: "us", longName: "English (US)" }, { shortName: "br", longName: "Portuguese (Brazil)" }]
        property int currentLayout: 0
        property bool capsLock: false
    }

    property Item theme: null
    Component.onCompleted: {
        const cfg = Object.assign({ use24h: win.state === "12h" ? "false" : "true", animations: "true", background: win.background },
                                  win.palettes[win.palette] || win.palettes.vs)
        const c = Qt.createComponent(Qt.resolvedUrl("../sekaipop/Main.qml"))
        if (c.status !== Component.Ready) {
            console.error("render: " + c.errorString())
            Qt.exit(1)
            return
        }
        if (win.state === "many") {
            fakeUsers.append({ name: "ena", realName: "Ena", icon: "" })
            fakeUsers.append({ name: "kanade", realName: "", icon: "" })
        }
        win.theme = c.createObject(win.contentItem, {
            width: 1920, height: 1080, sddmApi: fakeSddm, users: fakeUsers, sessions: fakeSessions, kb: fakeKb, cfg: cfg
        })
    }

    Timer {
        interval: 400
        running: true
        onTriggered: {
            if (win.state === "failed" || win.state === "busy") {
                win.theme.children[0]       // (nothing: the field is found by its role below)
                // type a password, then fail (or stay checking)
                const field = win.findField(win.theme)
                if (field) field.text = "hunter22"
                if (win.state === "failed") fakeSddm.loginFailed()
                else win.theme.busy = true
            }
        }
    }
    function findField(item) {
        if (!item) return null
        if (item.echoMode !== undefined && item.text !== undefined) return item
        for (let i = 0; i < item.children.length; i++) {
            const f = win.findField(item.children[i])
            if (f) return f
        }
        return null
    }
    Timer {
        interval: 1800
        running: true
        onTriggered: win.contentItem.grabToImage(r => { r.saveToFile(win.out); Qt.exit(0) })
    }
}
