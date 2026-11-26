import QtQuick

// A keycap in the shell's own construction (docs/DESIGN-SYSTEM.md, "The block"): outline,
// white ring, fill, on a hard shadow straight down. Pressed, the cap drops onto its shadow;
// let go, it springs back past rest and settles (OutBack). A plugin can't import the shell's
// Pill, so this rebuilds it from the promised theme names.
//
//   Key { t: host.theme; icon: "refresh"; label: "Refresh"; onClicked: ... }
Item {
    id: key

    required property var t
    property string icon: ""
    property string label: ""
    // A key that does the card's main thing wears the accent instead of the surface.
    property bool accent: false
    property color accentColor: key.t.accentMint
    property bool busy: false
    property real keyHeight: 30
    property real radius: 10

    signal clicked()

    readonly property bool down: area.pressed && key.enabled
    readonly property color fill: key.accent ? key.accentColor
        : (area.containsMouse && key.enabled ? key.t.surfaceHover : key.t.surface)
    readonly property color ink: key.accent ? key.t.colBorder : key.t.ink

    // Room left and right of the icon / word together (a chip-sized key takes less).
    property real padding: key.label !== "" ? 24 : 16
    implicitWidth: content.implicitWidth + key.padding
    implicitHeight: key.keyHeight + key.t.shadowOffset
    opacity: key.enabled ? 1 : 0.45

    // The hard shadow: never moves, the cap covers it when pressed.
    Rectangle {
        y: key.t.shadowOffset
        width: parent.width
        height: key.keyHeight
        radius: key.radius
        color: key.t.lineShadow
        antialiasing: true
    }

    Item {
        id: cap
        width: parent.width
        height: key.keyHeight
        y: key.down ? key.t.shadowOffset : 0
        Behavior on y {
            NumberAnimation {
                duration: key.down ? 80 : 260
                easing.type: key.down ? Easing.OutQuad : Easing.OutBack
                easing.overshoot: key.down ? 0 : 2.2
            }
        }

        // Outline + ring...
        Rectangle {
            anchors.fill: parent
            radius: key.radius
            color: key.t.ringWhite
            border.width: key.t.borderWidth
            border.color: key.t.line
            antialiasing: true
        }
        // ...and the fill inside the ring.
        Rectangle {
            anchors.fill: parent
            anchors.margins: key.t.borderWidth + 2
            radius: Math.max(0, key.radius - key.t.borderWidth - 2)
            color: key.fill
            antialiasing: true
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        Row {
            id: content
            anchors.centerIn: parent
            spacing: 5

            Text {
                id: glyph
                visible: key.icon !== "" || key.busy
                anchors.verticalCenter: parent.verticalCenter
                text: key.busy ? "progress_activity" : key.icon
                color: key.ink
                font.family: key.t.iconFont
                font.pixelSize: 16
                RotationAnimator on rotation {
                    running: key.busy
                    from: 0
                    to: 360
                    duration: 800
                    loops: Animation.Infinite
                    onRunningChanged: if (!running) glyph.rotation = 0
                }
            }

            Text {
                visible: key.label !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: key.label
                color: key.ink
                font.family: key.t.fontFamily
                font.pixelSize: 12
                font.weight: Font.ExtraBold
                font.styleName: key.t.fontStyleBold
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: key.enabled && !key.busy
        cursorShape: Qt.PointingHandCursor
        onClicked: key.clicked()
    }
}
