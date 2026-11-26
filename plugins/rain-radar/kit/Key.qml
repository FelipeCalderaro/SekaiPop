import QtQuick

// A keycap on a desktop card (docs/DESIGN-SYSTEM.md, "Buttons and states"): a Block that drops
// onto its shadow when pressed and springs back, hover wash, pointer cursor, 45 % when disabled.
// `on` wears the accent gradient (the shell's "on" state).
//
//   Key { t: host.theme; icon: "refresh"; label: "Run"; onClicked: ... }
Item {
    id: key

    required property var t
    property string icon: ""
    property string label: ""
    property bool on: false
    property bool busy: false
    property real keyHeight: 30
    property real radius: 10
    property string tip: ""

    signal clicked()

    readonly property bool hovered: area.containsMouse && key.enabled
    readonly property color ink: key.on ? key.t.colBorder : key.t.pInk

    implicitWidth: row.implicitWidth + (key.label !== "" ? 24 : 16) + 2 * (key.t.borderWidth + 2)
    implicitHeight: key.keyHeight + key.t.shadowOffset
    opacity: key.enabled ? 1 : 0.45

    Block {
        anchors.fill: parent
        t: key.t
        radius: key.radius
        drop: key.t.shadowOffset
        pressed: area.pressed && key.enabled
        fill: key.hovered ? key.t.pSurfaceHover : key.t.pSurfaceDivider
        fillTop: key.on ? key.t.accentCyan : "transparent"
        fillBottom: key.on ? key.t.accentMint : "transparent"

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 5
            Icon {
                visible: key.icon !== "" || key.busy
                anchors.verticalCenter: parent.verticalCenter
                t: key.t
                name: key.busy ? "progress_activity" : key.icon
                color: key.ink
                size: 16
                spinning: key.busy
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
