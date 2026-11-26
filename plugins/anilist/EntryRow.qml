import QtQuick
import Quickshell.Widgets
import "AniList.js" as AL

// One entry on your list, in the popup:
//
//   ┌──┬─────────────────────────────────────────────┐
//   │▌ [cover]  Sousou no Frieren           [EP 8 · 2d]│   the stripe and the bar take the
//   │▌ [     ]  TV · 7 / 28 ep · ★ 8.5       [+2] [+1]│   cover's own colour
//   │▌ [     ]  ███████░░░░░░░░░░░                    │
//   └──┴─────────────────────────────────────────────┘
//
// Clicking the row opens it on AniList; +1 (signed in) moves your progress on by one.
Item {
    id: row

    required property var t
    required property var entry
    property string lang: "user"
    property real nowSec: 0
    property bool canBump: false
    property bool bumping: false

    signal bumpRequested()

    readonly property color tone: row.entry.color !== "" ? row.entry.color : row.t.accentCyan
    readonly property int behind: AL.behind(row.entry)
    readonly property bool airs: row.entry.airingAt > row.nowSec

    implicitHeight: 66 + row.t.shadowOffset

    // Hard shadow, outline, fill: the shell's card.
    Rectangle {
        y: row.t.shadowOffset
        width: row.width
        height: row.height - row.t.shadowOffset
        radius: 12
        color: row.t.lineShadow
        antialiasing: true
    }

    Rectangle {
        id: body
        width: row.width
        height: row.height - row.t.shadowOffset
        // Pressing the row sinks it a little (the key inside sinks on its own).
        y: hit.pressed ? 2 : 0
        Behavior on y { NumberAnimation { duration: hit.pressed ? 70 : 200; easing.type: Easing.OutBack; easing.overshoot: 2 } }
        radius: 12
        color: hit.containsMouse ? row.t.surfaceHover : row.t.surface
        border.width: row.t.borderWidth - 0.5
        border.color: row.t.line
        antialiasing: true
        Behavior on color { ColorAnimation { duration: 120 } }

        // The cover's colour down the left edge, as a bar inside the outline.
        Rectangle {
            x: 6
            y: 9
            width: 4
            height: parent.height - 18
            radius: 2
            color: row.tone
        }

        // The cover as a little sticker: outline, then the picture, a hard shadow under it.
        Item {
            id: coverBox
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 40
            height: 56

            Rectangle {
                x: 0
                y: 3
                width: parent.width
                height: parent.height
                radius: 8
                color: row.t.lineShadow
            }
            // Outline + the cover's colour (what shows until the picture arrives).
            Rectangle {
                anchors.fill: parent
                radius: 8
                color: row.tone
                border.width: 2
                border.color: row.t.line
                antialiasing: true
            }
            Text {
                anchors.centerIn: parent
                visible: cover.status !== Image.Ready
                text: row.entry.kind === "MANGA" ? "menu_book" : "movie"
                color: AL.isLight(String(row.tone)) ? row.t.colBorder : "#ffffff"
                font.family: row.t.iconFont
                font.pixelSize: 18
            }
            // Only the picture is clipped (inside the outline).
            ClippingRectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: 6
                color: "transparent"
                visible: cover.status === Image.Ready

                Image {
                    id: cover
                    anchors.fill: parent
                    source: row.entry.cover
                    sourceSize: Qt.size(80, 112)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                }
            }
        }

        Column {
            id: texts
            anchors.left: coverBox.right
            anchors.leftMargin: 12
            anchors.right: side.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Text {
                width: parent.width
                elide: Text.ElideRight
                maximumLineCount: 1
                text: AL.titleOf(row.entry.title, row.lang)
                color: row.t.ink
                font.family: row.t.fontFamily
                font.pixelSize: 13
                font.weight: Font.ExtraBold
                font.styleName: row.t.fontStyleBold
            }

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: [row.entry.format.replace("_", " "), AL.progressText(row.entry),
                       row.entry.score > 0 ? "★ " + row.entry.score : ""].filter(s => s !== "").join("  ·  ")
                color: row.t.inkSub
                font.family: row.t.fontFamily
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }

            // Progress: a track in the divider tone, filled in the cover's colour.
            Item {
                width: parent.width
                height: 8

                Rectangle {
                    anchors.fill: parent
                    radius: 4
                    color: row.t.surfaceDivider
                    border.width: 1.5
                    border.color: row.t.line
                }
                Rectangle {
                    x: 1.5
                    y: 1.5
                    height: parent.height - 3
                    radius: 2.5
                    width: Math.max(0, (parent.width - 3) * AL.fraction(row.entry))
                    color: row.tone
                    Behavior on width { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
                }
            }
        }

        // Airing chip on top, the behind badge and +1 under it.
        Column {
            id: side
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Rectangle {
                visible: row.airs
                anchors.right: parent.right
                width: airText.implicitWidth + 14
                height: 20
                radius: 7
                color: row.t.chipFill

                Text {
                    id: airText
                    anchors.centerIn: parent
                    text: "EP " + row.entry.nextEpisode + " · " + AL.countdown(row.entry.airingAt - row.nowSec)
                    color: row.t.chipInk
                    font.family: row.t.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.ExtraBold
                    font.styleName: row.t.fontStyleBold
                    font.letterSpacing: 0.3
                }
            }

            Row {
                anchors.right: parent.right
                spacing: 6

                Rectangle {
                    visible: row.behind > 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: behindText.implicitWidth + 12
                    height: 20
                    radius: 7
                    color: row.t.warnFill
                    border.width: 2
                    border.color: row.t.colBorder

                    Text {
                        id: behindText
                        anchors.centerIn: parent
                        text: "+" + row.behind + " OUT"
                        color: row.t.colBorder
                        font.family: row.t.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.ExtraBold
                        font.styleName: row.t.fontStyleBold
                    }
                }

                Key {
                    visible: row.canBump
                    t: row.t
                    label: "+1"
                    keyHeight: 24
                    radius: 8
                    accent: true
                    busy: row.bumping
                    onClicked: row.bumpRequested()
                }
            }
        }
    }

    // The whole row opens the entry; the +1 key sits above this and keeps its own clicks.
    MouseArea {
        id: hit
        z: -1
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (row.entry.siteUrl !== "") Qt.openUrlExternally(row.entry.siteUrl)
    }
}
