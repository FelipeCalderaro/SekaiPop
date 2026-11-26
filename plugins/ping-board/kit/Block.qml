import QtQuick

// The shell's block (docs/DESIGN-SYSTEM.md, "Construction: the block"), from the theme names a
// plugin is promised: a hard shadow straight down, an outline, a pale ring and the fill, with the
// content on the fill. For a desktop card (the `p…` family).
//
//   Block { t: host.theme; width: 120; height: 60; fill: t.accentMint; Text { ... } }
//
// `pressed` drops the cap onto its shadow; letting go springs it back past rest (OutBack).
Item {
    id: block

    required property var t
    property color fill: block.t.pSurface
    property color line: block.t.pLine
    property color ring: block.t.pRingWhite
    property color shadow: block.t.pLineShadow
    property real radius: 12
    property real ringWidth: block.t.borderWidth + 2
    property real drop: block.t.shadowOffset
    property bool pressed: false
    // Gradient fill (the "on" look): set both, else `fill` is used.
    property color fillTop: "transparent"
    property color fillBottom: "transparent"
    readonly property bool gradientFill: block.fillTop.a > 0 && block.fillBottom.a > 0

    default property alias content: face.data
    readonly property real capHeight: block.height - block.drop
    readonly property real innerRadius: Math.max(0, block.radius - block.ringWidth)

    Rectangle {
        visible: block.drop > 0
        y: block.drop
        width: block.width
        height: block.capHeight
        radius: block.radius
        color: block.shadow
        antialiasing: true
    }

    Item {
        id: cap
        width: block.width
        height: block.capHeight
        y: block.pressed ? block.drop : 0
        Behavior on y {
            NumberAnimation {
                duration: block.pressed ? 80 : 260
                easing.type: block.pressed ? Easing.OutQuad : Easing.OutBack
                easing.overshoot: block.pressed ? 0 : 2.2
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: block.radius
            color: block.ring
            border.width: block.t.borderWidth
            border.color: block.line
            antialiasing: true
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: block.ringWidth
            radius: block.innerRadius
            color: block.fill
            antialiasing: true
            gradient: block.gradientFill ? grad : null
            Gradient {
                id: grad
                GradientStop { position: 0; color: block.fillTop }
                GradientStop { position: 1; color: block.fillBottom }
            }
        }
        Item {
            id: face
            anchors.fill: parent
            anchors.margins: block.ringWidth
        }
    }
}
