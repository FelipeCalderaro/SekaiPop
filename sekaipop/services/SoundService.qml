pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

// The desktop's error sound, the bell (Settings > General > Sounds; docs/SOUNDS.md). The choice is
// the `sound.error` setting (default | soft | chime | pop | ding | off | file, with `sound.errorFile`);
// scripts/theming/error-sound.sh puts it in the XDG "__custom" sound theme that kitty and GTK
// apps play their bell from. Changing the setting applies it; `status` is what the files say.
//
//   qs -c sekaipop ipc call options set sound.error chime
//   qs -c sekaipop ipc call sound play
Singleton {
    id: root

    readonly property string script: Directories.script("theming/error-sound.sh")
    readonly property string choice: SettingsService.get("sound.error") || "default"
    readonly property string file: SettingsService.get("sound.errorFile") || ""

    property string status: ""       // what error-sound.sh status says
    property string error: ""        // why the last change didn't happen, in words
    property bool busy: false

    function apply() {
        if (!SettingsService.loaded)
            return
        root.error = ""
        root.busy = true
        const args = ["sh", root.script, "set", root.choice]
        if (root.choice === "file")
            args.push(root.file)
        setter.exec(args)
    }
    function play() { player.exec(["sh", root.script, "play"]) }
    function refresh() { statusProc.exec(["sh", root.script, "status"]) }

    // a change in Settings (not at start: the files already hold the last choice)
    property bool started: false
    onChoiceChanged: if (root.started) root.apply()
    onFileChanged: if (root.started && root.choice === "file") root.apply()
    Connections {
        target: SettingsService
        function onLoadedChanged() {
            root.started = SettingsService.loaded
            root.refresh()
        }
    }
    Component.onCompleted: {
        root.started = SettingsService.loaded
        root.refresh()
    }

    Process {
        id: setter
        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "") root.error = text.trim().replace(/^error-sound: /, "")
        }
        onExited: code => {
            root.busy = false
            if (code === 0)
                root.error = ""
            root.refresh()
        }
    }
    Process { id: player }
    Process {
        id: statusProc
        stdout: StdioCollector { onStreamFinished: root.status = text.trim() }
    }

    IpcHandler {
        target: "sound"
        function play(): void { root.play() }
        function status(): string { return root.status }
    }
}
