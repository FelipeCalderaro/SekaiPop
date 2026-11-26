import QtQuick

// A Material Symbols Rounded glyph (docs/DESIGN-SYSTEM.md, "Iconography": plugins draw icons with
// the theme's icon font). `spinning` turns it as the shell's busy icons do (900 ms a turn).
Text {
    id: icon
    required property var t
    property string name: ""
    property real size: 18
    property bool spinning: false

    text: icon.name
    color: icon.t.pInk
    font.family: icon.t.iconFont
    font.pixelSize: icon.size
    renderType: Text.QtRendering

    RotationAnimator on rotation {
        running: icon.spinning && icon.visible
        from: 0
        to: 360
        duration: 900
        loops: Animation.Infinite
        onRunningChanged: if (!running) icon.rotation = 0
    }
}
