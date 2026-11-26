import QtQuick
import "kit"
import "Countdown.js" as CD

// Countdowns: the nearest date as a big sticker on a block, the rest as rows under it.
// Dates are the "events" setting (Settings > Desktop > Plugins > Countdowns), one per line;
// the logic is Countdown.js. Ticks every 30 s, only while the widget is on screen.
Item {
    id: root
    required property var host

    readonly property var t: root.host.theme
    readonly property var s: root.host.settings
    property date now: new Date()

    readonly property var parsed: CD.parse(root.s.events, root.now, root.s.showPast)
    readonly property var shown: root.parsed.items.slice(0, Math.max(1, root.s.maxShown))
    readonly property var first: root.shown.length > 0 ? root.shown[0] : null
    readonly property var rest: root.shown.slice(1)

    implicitWidth: 300
    implicitHeight: col.implicitHeight

    Timer {
        interval: 30000
        repeat: true
        running: root.host.working || root.host.editing
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    Column {
        id: col
        width: parent.width
        spacing: 10

        Tag { t: root.t; text: root.s.title || "Countdowns" }

        // ----- the nearest one
        Block {
            id: hero
            visible: root.first !== null
            t: root.t
            width: parent.width
            height: visible ? heroBody.implicitHeight + 2 * hero.ringWidth + hero.drop + 20 : 0
            radius: 14
            fill: root.t.pSurfaceDivider

            readonly property var lab: root.first ? CD.label(root.first, root.now) : ({ big: "", unit: "", words: "" })

            Column {
                id: heroBody
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 10
                spacing: 6

                Row {
                    spacing: 10
                    width: parent.width
                    Sticker {
                        id: big
                        t: root.t
                        text: hero.lab.big
                        size: hero.lab.big.length > 3 ? 30 : 44
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - big.width - 10
                        spacing: 1
                        Text {
                            visible: hero.lab.unit !== ""
                            text: hero.lab.unit.toUpperCase()
                            color: root.t.pInkSub
                            font.family: root.t.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.ExtraBold
                            font.styleName: root.t.fontStyleBold
                            font.letterSpacing: 0.6
                        }
                        Text {
                            width: parent.width
                            text: root.first ? root.first.title : ""
                            color: root.t.pInk
                            elide: Text.ElideRight
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            lineHeightMode: Text.FixedHeight
                            lineHeight: 22
                            textFormat: Text.PlainText
                            font.family: root.t.fontFamily
                            font.pixelSize: 18
                            font.weight: Font.ExtraBold
                            font.styleName: root.t.fontStyleBold
                        }
                        Text {
                            width: parent.width
                            text: root.first ? CD.dateText(root.first, root.now, root.s.use24h) : ""
                            color: root.t.pInkSub
                            elide: Text.ElideRight
                            font.family: root.t.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                    }
                }

                // the last 30 days of the wait, as a track that fills
                Item {
                    width: parent.width
                    height: 10
                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: root.t.pSurface
                        border.width: 2
                        border.color: root.t.pLine
                    }
                    Rectangle {
                        x: 2; y: 2
                        height: parent.height - 4
                        width: Math.max(height, (parent.width - 4) * (root.first ? CD.progress(root.first, root.now, 30) : 0))
                        radius: height / 2
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: root.t.accentMint }
                            GradientStop { position: 1; color: root.t.accentCyan }
                        }
                    }
                }
            }
        }

        // ----- the others
        Repeater {
            model: root.rest
            delegate: Block {
                id: row
                required property var modelData
                readonly property var lab: CD.label(modelData, root.now)
                t: root.t
                width: col.width
                height: 44 + row.drop
                radius: 10
                drop: 3
                ringWidth: root.t.borderWidth

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 10
                    spacing: 10

                    // the number on a chip: the bar's chip colours
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(44, chipText.implicitWidth + 14)
                        height: 26
                        radius: 8
                        color: root.t.chipFill
                        Text {
                            id: chipText
                            anchors.centerIn: parent
                            text: row.lab.big + (row.lab.unit !== "" && row.lab.big.length < 4 ? (row.lab.unit.charAt(0) === "d" ? "d" : row.lab.unit === "min" ? "m" : "h") : "")
                            color: root.t.chipInk
                            font.family: root.t.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.ExtraBold
                            font.styleName: root.t.fontStyleBold
                        }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 54 - 10
                        Text {
                            width: parent.width
                            text: row.modelData.title
                            color: root.t.pInk
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            textFormat: Text.PlainText
                            font.family: root.t.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.ExtraBold
                            font.styleName: root.t.fontStyleBold
                        }
                        Text {
                            width: parent.width
                            text: row.lab.words + " · " + CD.dateText(row.modelData, root.now, root.s.use24h)
                            color: root.t.pInkSub
                            elide: Text.ElideRight
                            font.family: root.t.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }
        }

        // ----- nothing to count, or lines it couldn't read: said in words
        Text {
            visible: root.first === null
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Nothing to count down to. Add dates in Settings > Desktop > Plugins > Countdowns, one per line: 2026-12-24 Christmas"
            color: root.t.pInkSub
            font.family: root.t.fontFamily
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }
        Text {
            visible: root.parsed.bad > 0
            width: parent.width
            wrapMode: Text.WordWrap
            text: root.parsed.bad + (root.parsed.bad === 1 ? " line isn't" : " lines aren't") + " a date it understands (2026-12-24 Name, or 12-24 Name)."
            color: root.t.pInkSub
            font.family: root.t.fontFamily
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }
    }
}
