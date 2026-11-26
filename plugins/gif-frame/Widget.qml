import QtQuick
import QtCore
import Qt.labs.folderlistmodel
import "kit"
import "GifFrame.js" as GF

// GIF Frame: a looping picture in a polaroid, taped or block frame. The source is a file, or a
// folder it picks from at random (FolderListModel) and changes every `changeMinutes`.
// It plays only while the widget is on screen (host.working) and not paused.
Item {
    id: root
    required property var host

    readonly property var t: root.host.theme
    readonly property var s: root.host.settings
    readonly property string home: String(StandardPaths.writableLocation(StandardPaths.HomeLocation)).replace("file://", "")
    readonly property string path: GF.expand(root.s.source, root.home)
    readonly property bool fromFolder: GF.isFolder(root.path)
    property string current: root.fromFolder ? "" : root.path
    property bool paused: !root.s.autoplay

    readonly property real w: Math.max(140, root.s.width)
    readonly property string look: root.s.look
    readonly property real pad: root.look === "polaroid" ? 12 : (root.look === "tape" ? 8 : 0)
    readonly property string cap: GF.caption(root.s.caption, root.current, root.s.showName)
    readonly property real capH: root.look === "polaroid" ? (root.cap !== "" ? 40 : 26) : 0
    readonly property real picW: root.w - 2 * root.pad - (root.look === "block" ? 0 : 2 * root.t.borderWidth)
    readonly property real picH: GF.boxHeight(root.picW, pic.implicitWidth, pic.implicitHeight)

    // room for the tilt and the tape sticking out
    implicitWidth: root.w + 24
    implicitHeight: card.height + 28

    // ----- the folder
    FolderListModel {
        id: folder
        folder: root.fromFolder ? "file://" + root.path : ""
        showDirs: false
        showHidden: false
        nameFilters: GF.EXTS.map(e => "*." + e).concat(GF.EXTS.map(e => "*." + e.toUpperCase()))
        sortField: FolderListModel.Name
        onStatusChanged: if (status === FolderListModel.Ready) root.next()
        onCountChanged: if (status === FolderListModel.Ready && root.current === "") root.next()
    }

    function next() {
        if (!root.fromFolder)
            return
        const names = []
        for (let i = 0; i < folder.count; i++)
            names.push(String(folder.get(i, "filePath")))
        root.current = GF.pickNext(names, root.current, Math.random())
    }

    Timer {
        interval: Math.max(1, root.s.changeMinutes) * 60000
        repeat: true
        running: root.fromFolder && root.s.changeMinutes > 0 && root.host.working
        onTriggered: root.next()
    }

    // ----- the card
    Item {
        id: card
        x: 12
        y: 14
        width: root.w
        height: root.look === "block" ? root.picH + 2 * frameBlock.ringWidth + root.t.shadowOffset
                                      : root.picH + 2 * root.pad + root.capH + 2 * root.t.borderWidth + root.t.shadowOffset
        rotation: root.s.tilt
        antialiasing: true

        // polaroid / tape: paper on a hard shadow, outlined; block: the shell's block
        Block {
            id: frameBlock
            anchors.fill: parent
            t: root.t
            radius: root.look === "block" ? 14 : 6
            ringWidth: root.look === "block" ? root.t.borderWidth + 2 : root.t.borderWidth
            fill: root.t.pSurface
        }

        Item {
            id: picBox
            x: root.look === "block" ? frameBlock.ringWidth : root.t.borderWidth + root.pad
            y: root.look === "block" ? frameBlock.ringWidth : root.t.borderWidth + root.pad
            width: root.look === "block" ? card.width - 2 * frameBlock.ringWidth : root.picW
            height: root.picH
            clip: true

            Rectangle {
                anchors.fill: parent
                color: root.t.pSurfaceDivider
            }
            AnimatedImage {
                id: pic
                anchors.fill: parent
                source: root.current !== "" ? "file://" + root.current : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                smooth: true
                playing: root.host.working && !root.paused
                onStatusChanged: if (status === AnimatedImage.Error && root.fromFolder) retry.restart()
            }
            // one bad file in a folder: try another a moment later, not a broken frame forever
            Timer { id: retry; interval: 1500; onTriggered: root.next() }

            // nothing to show: said in words
            Column {
                visible: pic.status !== AnimatedImage.Ready
                anchors.centerIn: parent
                width: parent.width - 24
                spacing: 6
                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    t: root.t
                    name: pic.status === AnimatedImage.Loading ? "progress_activity" : "imagesmode"
                    spinning: pic.status === AnimatedImage.Loading
                    color: root.t.pInkSub
                    size: 28
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    color: root.t.pInkSub
                    font.family: root.t.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    text: pic.status === AnimatedImage.Loading ? "Loading…"
                        : pic.status === AnimatedImage.Error ? "Can't open " + String(root.current).split("/").pop()
                        : root.fromFolder && folder.status === FolderListModel.Ready && folder.count === 0
                          ? "No GIFs or pictures found in " + root.path.replace(root.home, "~")
                        : root.path === "" ? "Pick a GIF or a folder in Settings > Desktop > Plugins > GIF Frame"
                        : "Looking in " + root.path.replace(root.home, "~")
                }
            }

            // controls: shown on hover, so the picture stays clean
            HoverHandler { id: hover }
            Row {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 6
                spacing: 6
                opacity: hover.hovered || root.host.selected ? 1 : 0
                visible: opacity > 0 && pic.status === AnimatedImage.Ready
                Behavior on opacity { NumberAnimation { duration: 140 } }
                Key {
                    t: root.t
                    keyHeight: 24
                    icon: root.paused ? "play_arrow" : "pause"
                    visible: pic.frameCount > 1
                    onClicked: root.paused = !root.paused
                }
                Key {
                    t: root.t
                    keyHeight: 24
                    icon: "skip_next"
                    visible: root.fromFolder && folder.count > 1
                    onClicked: root.next()
                }
            }
        }

        // the polaroid's caption
        Text {
            visible: root.look === "polaroid" && root.cap !== ""
            x: picBox.x
            y: picBox.y + picBox.height + 8
            width: picBox.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            maximumLineCount: 1
            textFormat: Text.PlainText
            text: root.cap
            color: root.t.pInk
            font.family: root.t.fontFamily
            font.pixelSize: 15
            font.weight: Font.ExtraBold
            font.styleName: root.t.fontStyleBold
        }

        // washi tape over the two top corners (one of the design system's deliberate translucent pieces)
        Repeater {
            model: root.look === "tape" ? 2 : 0
            Rectangle {
                required property int index
                width: 74
                height: 22
                x: index === 0 ? -16 : card.width - 58
                y: -8
                rotation: index === 0 ? -32 : 32
                antialiasing: true
                readonly property color base: Qt.color(index === 0 ? root.t.accentMint : root.t.accentCyan)
                color: Qt.rgba(base.r, base.g, base.b, 0.78)
                Row {
                    anchors.centerIn: parent
                    spacing: 7
                    Repeater {
                        model: 6
                        Rectangle { width: 3; height: 22; color: Qt.rgba(1, 1, 1, 0.22) }
                    }
                }
            }
        }
    }
}
