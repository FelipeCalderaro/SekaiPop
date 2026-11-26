import QtQuick
import "kit"
import "CoverWall.js" as CW

// Cover Wall: what's playing as a record that spins (its cover as the label), with play / pause
// and next, over a wall of the albums you played lately. The watching is Service.qml.
// The record turns only while music plays and the widget is on screen.
Item {
    id: root
    required property var host

    readonly property var t: root.host.theme
    readonly property var s: root.host.settings
    readonly property var svc: root.host.service
    readonly property var now: root.svc ? root.svc.now : null
    readonly property bool playing: root.svc ? root.svc.playing : false
    readonly property var history: root.svc ? root.svc.history : []
    readonly property int cols: Math.max(3, Math.min(6, root.s.columns))
    readonly property int rows: Math.max(1, Math.min(4, root.s.rows))
    readonly property real gap: 8
    readonly property real cell: 70
    readonly property real wallW: root.cols * root.cell + (root.cols - 1) * root.gap
    readonly property bool showRecord: root.s.showRecord && root.now !== null && root.now.title !== ""

    implicitWidth: root.wallW
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: 10

        Tag { t: root.t; text: root.playing ? "Now playing" : (root.showRecord ? "Paused" : "Lately") }

        // ----- the record
        Item {
            id: deck
            visible: root.showRecord
            width: parent.width
            height: visible ? 112 : 0

            Item {
                id: record
                width: 104
                height: 104
                anchors.verticalCenter: parent.verticalCenter

                // the disc, its grooves and the hard shadow under it (a block is round here)
                Rectangle {
                    y: root.t.shadowOffset
                    width: parent.width - root.t.shadowOffset
                    height: width
                    radius: width / 2
                    color: root.t.pLineShadow
                }
                Item {
                    id: disc
                    width: parent.width - root.t.shadowOffset
                    height: width

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: Qt.darker(Qt.color(root.t.colBorder), 2.4)
                        border.width: root.t.borderWidth
                        border.color: root.t.pLine
                    }
                    Repeater {
                        model: 4
                        Rectangle {
                            required property int index
                            anchors.centerIn: parent
                            width: disc.width * (0.86 - index * 0.09)
                            height: width
                            radius: width / 2
                            color: "transparent"
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.08)
                        }
                    }
                    // the label: the cover, cut round (a Canvas, so it draws without shader effects)
                    Canvas {
                        id: label
                        anchors.centerIn: parent
                        width: disc.width * 0.5
                        height: width
                        readonly property string art: root.now && CW.usableArt(root.now.art) ? root.now.art : ""
                        property string loaded: ""
                        onArtChanged: { if (art !== "") loadImage(art); requestPaint() }
                        onImageLoaded: requestPaint()
                        Component.onCompleted: if (art !== "") loadImage(art)
                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.reset()
                            ctx.save()
                            ctx.beginPath()
                            ctx.arc(width / 2, height / 2, width / 2, 0, Math.PI * 2)
                            ctx.clip()
                            if (art !== "" && isImageLoaded(art)) {
                                ctx.drawImage(art, 0, 0, width, height)
                            } else {
                                ctx.fillStyle = String(root.t.accentMint)
                                ctx.fillRect(0, 0, width, height)
                            }
                            ctx.restore()
                        }
                    }
                    Rectangle {          // the spindle
                        anchors.centerIn: parent
                        width: 8
                        height: 8
                        radius: 4
                        color: root.t.pSurface
                        border.width: 2
                        border.color: root.t.colBorder
                    }

                    RotationAnimator on rotation {
                        running: root.playing && root.host.working
                        from: disc.rotation
                        to: disc.rotation + 360
                        duration: 4000
                        loops: Animation.Infinite
                    }
                }
            }

            Column {
                anchors.left: record.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Text {
                    width: parent.width
                    text: root.now ? root.now.title : ""
                    color: root.t.pInk
                    elide: Text.ElideRight
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    lineHeightMode: Text.FixedHeight
                    lineHeight: 20
                    textFormat: Text.PlainText
                    font.family: root.t.fontFamily
                    font.pixelSize: 16
                    font.weight: Font.ExtraBold
                    font.styleName: root.t.fontStyleBold
                }
                Text {
                    width: parent.width
                    text: root.now ? CW.subtitle(root.now) : ""
                    color: root.t.pInkSub
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    textFormat: Text.PlainText
                    font.family: root.t.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
                Item { width: 1; height: 4 }
                Row {
                    spacing: 6
                    Key {
                        t: root.t
                        keyHeight: 28
                        icon: root.playing ? "pause" : "play_arrow"
                        on: root.playing
                        enabled: root.svc && root.svc.canToggle
                        onClicked: root.svc.togglePlaying()
                    }
                    Key {
                        t: root.t
                        keyHeight: 28
                        icon: "skip_next"
                        enabled: root.svc && root.svc.canNext
                        onClicked: root.svc.next()
                    }
                }
            }
        }

        // ----- the wall
        Grid {
            id: wall
            columns: root.cols
            spacing: root.gap
            Repeater {
                model: root.history.slice(0, root.cols * root.rows)
                delegate: Item {
                    id: cover
                    required property var modelData
                    readonly property bool current: root.svc && modelData.key === root.svc.nowKey
                    width: root.cell
                    height: root.cell

                    Block {
                        anchors.fill: parent
                        t: root.t
                        radius: 9
                        drop: 3
                        pressed: tap.pressed
                        // the one playing wears a wide accent ring ("on") and a badge, so it reads without colour too
                        ring: cover.current ? root.t.accentCyan : root.t.pRingWhite
                        ringWidth: cover.current ? root.t.borderWidth + 4 : root.t.borderWidth
                        Image {
                            anchors.fill: parent
                            source: cover.modelData.art
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: 140
                        }
                    }
                    Rectangle {
                        visible: cover.current
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: -4
                        width: 22
                        height: 22
                        radius: 11
                        color: root.t.accentCyan
                        border.width: 2
                        border.color: root.t.colBorder
                        Icon {
                            anchors.centerIn: parent
                            t: root.t
                            name: root.playing ? "graphic_eq" : "pause"
                            size: 14
                            color: root.t.colBorder
                        }
                    }
                    MouseArea {
                        id: tap
                        anchors.fill: parent
                        enabled: root.s.clickSearches !== "off"
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: Qt.openUrlExternally(CW.searchUrl(root.s.clickSearches, cover.modelData))
                    }
                }
            }
            // empty spots keep the wall's shape, as dashed sockets
            Repeater {
                model: Math.max(0, root.cols * root.rows - root.history.length)
                Rectangle {
                    width: root.cell
                    height: root.cell - 3
                    radius: 9
                    color: "transparent"
                    border.width: 2
                    border.color: root.t.pSurfaceDivider
                }
            }
        }

        Text {
            visible: root.history.length === 0
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Play something with a cover (Spotify, a browser, mpv with a cover) and it lands here."
            color: root.t.pInkSub
            font.family: root.t.fontFamily
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }
    }
}
