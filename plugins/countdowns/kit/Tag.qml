import QtQuick

// A section tab (docs/DESIGN-SYSTEM.md, SectionTab / Slant): a slanted chip with a diamond and a
// short UPPERCASE eyebrow word. Put titles next to it, not inside.
//
//   Tag { t: host.theme; text: "Watchlist" }
Item {
    id: tag
    required property var t
    property string text: ""
    property color fill: tag.t.chipFill
    property color ink: tag.t.chipInk
    property color diamond: tag.t.dark ? tag.t.accentMint : tag.t.colBorder

    implicitWidth: label.implicitWidth + 34
    implicitHeight: 22

    Rectangle {
        anchors.fill: parent
        radius: 7
        color: tag.fill
        antialiasing: true
        transform: Matrix4x4 {
            // lean right by 0.2 of the height, around the middle
            matrix: Qt.matrix4x4(1, -0.2, 0, tag.height * 0.1, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
        }
    }
    Rectangle {
        x: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 7; height: 7
        rotation: 45
        color: tag.diamond
        antialiasing: true
    }
    Text {
        id: label
        x: 23
        anchors.verticalCenter: parent.verticalCenter
        text: tag.text.toUpperCase()
        color: tag.ink
        font.family: tag.t.fontFamily
        font.pixelSize: 10
        font.weight: Font.ExtraBold
        font.styleName: tag.t.fontStyleBold
        font.letterSpacing: 0.6
    }
}
