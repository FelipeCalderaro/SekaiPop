import QtQuick
import "kit"
import "PingBoard.js" as PB

// Ping Board: one row per host (name, last answer, a bar graph of the last 30, how it's doing in
// words) and the speed test. The pinging is Service.qml; this only draws host.service.
Item {
    id: root
    required property var host

    readonly property var t: root.host.theme
    readonly property var svc: root.host.service
    readonly property var hosts: root.svc ? root.svc.hosts : []
    property date now: new Date()
    // a white card (Light, and Dark's classic white cards) needs a darker bar than the pale accent
    readonly property bool lightCard: Qt.color(root.t.pSurface).hslLightness > 0.6

    implicitWidth: 320
    implicitHeight: col.implicitHeight

    Timer {
        interval: 20000
        repeat: true
        running: root.host.working
        onTriggered: root.now = new Date()
    }

    Column {
        id: col
        width: parent.width
        spacing: 8

        Tag { t: root.t; text: "Network" }

        Repeater {
            model: root.hosts
            delegate: Block {
                id: row
                required property var modelData
                readonly property var samples: root.svc ? (root.svc.samples[modelData.address] || []) : []
                readonly property var st: PB.stats(row.samples)
                readonly property var verdict: PB.verdict(row.st)
                readonly property var heights: PB.bars(row.samples, 50)

                t: root.t
                width: col.width
                height: 56 + row.drop
                radius: 10
                drop: 3
                ringWidth: root.t.borderWidth

                Item {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10

                    Column {
                        id: names
                        anchors.verticalCenter: parent.verticalCenter
                        width: 104
                        spacing: 1
                        Text {
                            width: parent.width
                            text: row.modelData.label
                            color: root.t.pInk
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                            font.family: root.t.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.ExtraBold
                            font.styleName: root.t.fontStyleBold
                        }
                        Text {
                            text: PB.msText(row.st.last)
                            color: row.st.last === null && row.st.count > 0 ? root.t.pInk : root.t.pInkSub
                            font.family: root.t.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                    }

                    // the graph: newest on the right; a lost answer is a short amber stub with a
                    // gap above it, so it reads without colour too
                    Row {
                        id: graph
                        anchors.left: names.right
                        anchors.leftMargin: 8
                        anchors.right: chip.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        height: 30
                        spacing: 2
                        layoutDirection: Qt.RightToLeft
                        readonly property real barW: Math.max(2, (width - 29 * spacing) / 30)
                        Repeater {
                            model: row.heights.slice().reverse()
                            Item {
                                required property real modelData
                                width: graph.barW
                                height: graph.height
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    height: parent.modelData < 0 ? 5 : Math.max(3, parent.height * parent.modelData)
                                    radius: Math.min(2, width / 2)
                                    // the accent on a dark card; on a white one it is too pale, so the outline colour
                                    color: parent.modelData < 0 ? root.t.warnFill : (root.lightCard ? root.t.colBorder : root.t.accentCyan)
                                    border.width: parent.modelData < 0 ? 1 : 0
                                    border.color: root.t.colBorder
                                }
                            }
                        }
                    }

                    // how it's doing, in words; amber when it wants a look (with colBorder ink)
                    Rectangle {
                        id: chip
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(40, chipText.implicitWidth + 14)
                        height: 22
                        radius: 7
                        color: row.verdict.warn ? root.t.warnFill : root.t.chipFill
                        Text {
                            id: chipText
                            anchors.centerIn: parent
                            text: row.verdict.word
                            color: row.verdict.warn ? root.t.colBorder : root.t.chipInk
                            font.family: root.t.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.ExtraBold
                            font.styleName: root.t.fontStyleBold
                        }
                    }
                }
            }
        }

        Text {
            visible: root.hosts.length === 0
            width: parent.width
            wrapMode: Text.WordWrap
            text: "No hosts to ping. Add them in Settings > Desktop > Plugins > Ping Board, one per line: 1.1.1.1 Cloudflare"
            color: root.t.pInkSub
            font.family: root.t.fontFamily
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }

        // ----- speed test
        Item {
            visible: root.host.settings.showSpeedTest
            width: parent.width
            height: visible ? Math.max(speedKey.height, result.implicitHeight) : 0

            Key {
                id: speedKey
                t: root.t
                icon: "speed"
                label: root.svc && root.svc.speedState === "running" ? "Testing…" : "Test speed"
                busy: root.svc && root.svc.speedState === "running"
                enabled: root.svc !== null
                onClicked: root.svc.runSpeedTest()
            }
            Column {
                id: result
                anchors.left: speedKey.right
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.verticalCenter: speedKey.verticalCenter
                anchors.verticalCenterOffset: -root.t.shadowOffset / 2
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    color: root.t.pInk
                    font.family: root.t.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.ExtraBold
                    font.styleName: root.t.fontStyleBold
                    text: !root.svc ? "" : root.svc.speedState === "done"
                          ? "↓ " + root.svc.speedDown + (root.svc.speedUp !== "" ? "   ↑ " + root.svc.speedUp : "")
                        : root.svc.speedState === "error" ? "Couldn't test: " + root.svc.speedError
                        : root.svc.speedState === "running" ? "Downloading and uploading…" : "Not tested yet"
                }
                Text {
                    visible: root.svc && root.svc.speedState === "done"
                    text: root.svc ? "speed.cloudflare.com · " + PB.ago(root.svc.speedAt, root.now) : ""
                    color: root.t.pInkSub
                    font.family: root.t.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
            }
        }
    }
}
