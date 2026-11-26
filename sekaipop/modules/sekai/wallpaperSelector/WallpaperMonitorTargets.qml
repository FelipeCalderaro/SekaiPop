import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets

// "Where does it go?" in the wallpaper viewer, above Set as Desktop / Lockscreen, when more than
// one monitor is connected: All monitors, or one of them. Each monitor's chip shows a thumbnail of
// what it has now, so they can be told apart, and "here" marks the one the board is open on.
// The chosen one wears the accent ring (the shell's "on").
//
// Pure UI: `screens` is [{ name, image, here }], `current` "all" or a monitor's name; it only
// says picked(id).
Item {
    id: root

    readonly property var mt: Theme.of(QsWindow.window)

    property var screens: []
    property string current: "all"
    signal picked(string id)

    implicitHeight: label.height + 8 + flow.implicitHeight
    implicitWidth: 400

    Text {
        id: label
        text: "SET ON"
        color: mt.pInkSub
        font.family: mt.fontFamily
        font.pixelSize: 11
        font.weight: Font.ExtraBold
        font.styleName: mt.fontStyleBold
        font.letterSpacing: 0.7
    }

    Flow {
        id: flow
        y: label.height + 8
        width: root.width
        spacing: 8

        Repeater {
            model: [{ name: "all", image: "", here: false }].concat(root.screens)

            delegate: Item {
                id: chip
                required property var modelData
                readonly property bool all: modelData.name === "all"
                readonly property bool on: root.current === modelData.name
                width: inner.implicitWidth + 20
                height: 42 + mt.shadowOffset

                // hard shadow, then the cap (drops onto it while pressed)
                Rectangle {
                    y: mt.shadowOffset
                    width: chip.width
                    height: 42
                    radius: 13
                    color: mt.pLineShadow
                    antialiasing: true
                }
                Rectangle {
                    id: cap
                    width: chip.width
                    height: 42
                    y: tap.pressed ? mt.shadowOffset : 0
                    radius: 13
                    color: chip.on ? mt.accentMint : (tap.containsMouse ? mt.pSurfaceHover : mt.pSurface)
                    border.width: chip.on ? 3 : 2.5
                    border.color: chip.on ? mt.colBorder : mt.pLine
                    antialiasing: true
                    Behavior on y {
                        NumberAnimation {
                            duration: tap.pressed ? 80 : 260
                            easing.type: tap.pressed ? Easing.OutQuad : Easing.OutBack
                            easing.overshoot: tap.pressed ? 0 : 2.2
                        }
                    }

                    Row {
                        id: inner
                        anchors.centerIn: parent
                        spacing: 8

                        // the monitor: a little screen with what it shows now (all: a stack of two)
                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            width: chip.all ? 34 : 38
                            height: 24
                            Repeater {
                                model: chip.all ? 2 : 1
                                Rectangle {
                                    required property int index
                                    x: chip.all ? index * 8 : 0
                                    y: chip.all ? (1 - index) * 5 : 0
                                    width: chip.all ? 26 : 38
                                    height: chip.all ? 18 : 24
                                    radius: 4
                                    color: mt.pSurfaceDivider
                                    border.width: 2
                                    border.color: chip.on ? mt.colBorder : mt.pLine
                                    clip: true
                                    Image {
                                        visible: !chip.all && chip.modelData.image !== ""
                                        anchors.fill: parent
                                        anchors.margins: 2
                                        source: chip.modelData.image !== "" ? "file://" + chip.modelData.image : ""
                                        sourceSize.width: 96
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                    }
                                }
                            }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                text: chip.all ? "All monitors" : chip.modelData.name
                                color: chip.on ? mt.colBorder : mt.pInk
                                font.family: mt.fontFamily
                                font.pixelSize: 14
                                font.weight: Font.ExtraBold
                                font.styleName: mt.fontStyleBold
                            }
                            Text {
                                visible: !chip.all && chip.modelData.here
                                text: "here"
                                color: chip.on ? mt.colBorder : mt.pInkSub
                                font.family: mt.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                            }
                        }
                    }
                }

                MouseArea {
                    id: tap
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.picked(chip.modelData.name)
                }
            }
        }
    }
}
