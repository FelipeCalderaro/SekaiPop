import QtQuick
import "kit"
import "Radar.js" as RD

// Rain Radar: a map (Esri's grey canvas tiles) with RainViewer's radar frames over it, played as a loop that
// rests a moment on the newest frame; a pin on your place; the time as a chip; a frame strip
// (forecast frames hollow); play / pause. The data is Service.qml.
// Every frame's tiles stay loaded and only the current one shows, so the loop doesn't flicker.
Item {
    id: root
    required property var host

    readonly property var t: root.host.theme
    readonly property var s: root.host.settings
    readonly property var svc: root.host.service
    readonly property var place: root.svc ? root.svc.place : null
    readonly property var frames: root.svc ? root.svc.frames : []
    readonly property int zoom: RD.clampZoom(root.s.zoom)
    readonly property real mapW: Math.max(220, root.s.width)
    readonly property real mapH: Math.max(160, root.s.height)
    readonly property bool darkMap: Qt.color(root.t.pSurface).hslLightness < 0.5
    readonly property var tiles: root.place ? RD.layout(root.place.lat, root.place.lon, root.zoom, root.mapW, root.mapH) : []
    // the newest frame that isn't a forecast: where the loop rests
    readonly property int nowIndex: {
        for (let i = root.frames.length - 1; i >= 0; i--)
            if (!root.frames[i].forecast) return i
        return root.frames.length - 1
    }
    property int cur: -1
    readonly property int shown: root.cur >= 0 && root.cur < root.frames.length ? root.cur : root.nowIndex
    property bool playing: true
    property int rest: 0
    property date now: new Date()

    implicitWidth: root.mapW + 2 * (root.t.borderWidth + 2)
    implicitHeight: col.implicitHeight

    onFramesChanged: root.cur = root.nowIndex

    Timer {
        interval: Math.max(200, root.s.speedMs)
        repeat: true
        running: root.playing && root.host.working && root.frames.length > 1
        onTriggered: {
            root.now = new Date()
            if (root.shown === root.nowIndex && root.rest < 3) {      // hold on "now" for a beat
                root.rest++
                return
            }
            root.rest = 0
            root.cur = (root.shown + 1) % root.frames.length
        }
    }

    Column {
        id: col
        width: parent.width
        spacing: 8

        Row {
            spacing: 10
            Tag { anchors.verticalCenter: parent.verticalCenter; t: root.t; text: "Rain radar" }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.place ? root.place.label : ""
                color: root.t.pInk
                font.family: root.t.fontFamily
                font.pixelSize: 14
                font.weight: Font.ExtraBold
                font.styleName: root.t.fontStyleBold
            }
        }

        Block {
            id: frame
            t: root.t
            width: parent.width
            height: root.mapH + 2 * frame.ringWidth + frame.drop
            radius: 12

            Item {
                id: map
                anchors.fill: parent
                clip: true

                // the map
                Repeater {
                    model: root.tiles
                    Image {
                        required property var modelData
                        x: modelData.left
                        y: modelData.top
                        width: RD.TILE
                        height: RD.TILE
                        source: RD.baseUrl(root.darkMap, modelData.z, modelData.x, modelData.y)
                        asynchronous: true
                        cache: true
                    }
                }

                // the radar: one layer per frame, only the current one visible
                Repeater {
                    model: root.svc && root.place ? root.frames : []
                    Item {
                        id: frameLayer
                        required property var modelData
                        required property int index
                        readonly property string path: frameLayer.modelData ? frameLayer.modelData.path : ""
                        anchors.fill: parent
                        visible: frameLayer.index === root.shown
                        Repeater {
                            model: root.tiles
                            Image {
                                required property var modelData
                                x: modelData.left
                                y: modelData.top
                                width: RD.TILE
                                height: RD.TILE
                                opacity: 0.8
                                asynchronous: true
                                cache: true
                                source: frameLayer.path === "" ? "" : RD.radarUrl(root.svc.host_, frameLayer.path, modelData.z, modelData.x, modelData.y,
                                                    parseInt(root.s.colors) || 2, root.s.smooth, root.s.snow)
                            }
                        }
                    }
                }

                // the pin: a small block with a hard shadow, at the middle
                Item {
                    visible: root.place !== null
                    x: map.width / 2 - 9
                    y: map.height / 2 - 9
                    width: 18
                    height: 18
                    Rectangle { y: 3; width: 18; height: 18; radius: 9; color: root.t.pLineShadow }
                    Rectangle {
                        width: 18; height: 18; radius: 9
                        color: root.t.accentCyan
                        border.width: root.t.borderWidth
                        border.color: root.t.colBorder
                    }
                }

                // the time, as a chip
                Rectangle {
                    visible: root.frames.length > 0 && root.place !== null
                    x: 8
                    y: 8
                    width: timeText.implicitWidth + 16
                    height: 24
                    radius: 8
                    color: root.t.chipFill
                    border.width: 2
                    border.color: root.t.colBorder
                    Text {
                        id: timeText
                        anchors.centerIn: parent
                        readonly property var f: root.frames[root.shown]
                        text: f ? RD.clock(f.time) + " · " + (f.forecast ? "forecast" : RD.frameWords(f.time, root.now.getTime())) : ""
                        color: root.t.chipInk
                        font.family: root.t.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.ExtraBold
                        font.styleName: root.t.fontStyleBold
                    }
                }

                // in words when there is nothing to show
                Rectangle {
                    visible: !root.place || (root.svc && root.svc.error !== "" && root.frames.length === 0)
                    anchors.fill: parent
                    color: root.t.pSurfaceDivider
                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 32
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: root.svc && root.svc.error !== "" ? root.svc.error : "Finding " + root.s.place + "…"
                        color: root.t.pInkSub
                        font.family: root.t.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }
                }
            }
        }

        // the frames as a strip: past filled, forecast hollow, the shown one tall
        Item {
            width: parent.width
            height: playKey.height
            Key {
                id: playKey
                t: root.t
                keyHeight: 26
                icon: root.playing ? "pause" : "play_arrow"
                enabled: root.frames.length > 1
                onClicked: root.playing = !root.playing
            }
            Row {
                id: strip
                anchors.left: playKey.right
                anchors.leftMargin: 10
                anchors.right: refreshKey.left
                anchors.rightMargin: 10
                anchors.verticalCenter: playKey.verticalCenter
                anchors.verticalCenterOffset: -root.t.shadowOffset / 2
                height: 16
                spacing: 3
                readonly property real w: root.frames.length ? (width - (root.frames.length - 1) * spacing) / root.frames.length : 0
                Repeater {
                    model: root.frames
                    Rectangle {
                        required property var modelData
                        required property int index
                        anchors.bottom: parent.bottom
                        width: strip.w
                        height: index === root.shown ? 16 : 9
                        radius: 3
                        color: modelData.forecast ? "transparent" : (index === root.shown ? root.t.accentCyan : root.t.pSurfaceDivider)
                        border.width: 1.5
                        border.color: root.t.colBorder
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -3
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { root.playing = false; root.cur = parent.index }
                        }
                    }
                }
            }
            Key {
                id: refreshKey
                anchors.right: parent.right
                t: root.t
                keyHeight: 26
                icon: "refresh"
                enabled: root.svc !== null
                onClicked: root.svc.refresh()
            }
        }

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: "Radar: RainViewer · Map: Esri, HERE, Garmin, © OpenStreetMap contributors"
            color: root.t.pInkSub
            font.family: root.t.fontFamily
            font.pixelSize: 10
            font.weight: Font.DemiBold
        }
    }
}
