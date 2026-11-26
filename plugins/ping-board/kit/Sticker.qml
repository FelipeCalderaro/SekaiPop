import QtQuick

// A sticker number or word (docs/DESIGN-SYSTEM.md, StickerText): the text filled, a white ring,
// a thick outline, and the outline repeated down-right as a hard shadow. A new value hops in
// from slightly smaller (not the first one). Qt's own text outline is one pixel, so each band is
// the text drawn at a ring of offsets.
//
//   Sticker { t: host.theme; text: "42°"; size: 44 }
Item {
    id: st
    required property var t
    property string text: ""
    property real size: 40
    property color fill: st.t.accentCyan
    property color outline: st.t.colBorder
    property color ring: "#ffffff"
    readonly property real stroke: Math.max(2.5, st.size * 0.085)
    readonly property real ringW: Math.max(1.2, st.stroke * 0.45)
    readonly property real drop: Math.max(2, st.stroke * 0.9)

    implicitWidth: base.implicitWidth + 2 * (st.stroke + st.ringW) + st.drop
    implicitHeight: base.implicitHeight + 2 * (st.stroke + st.ringW) + st.drop

    property bool _first: true
    onTextChanged: {
        if (st._first) { st._first = false; return }
        hop.restart()
    }
    NumberAnimation { id: hop; target: holder; property: "scale"; from: 0.82; to: 1; duration: 320; easing.type: Easing.OutBack; easing.overshoot: 2 }

    component Band: Item {
        id: band
        property real radius: 1
        property color color: "black"
        property real dx: 0
        property real dy: 0
        Repeater {
            model: 12
            Text {
                required property int index
                readonly property real a: index * Math.PI / 6
                x: band.dx + Math.cos(a) * band.radius
                y: band.dy + Math.sin(a) * band.radius
                text: st.text
                font: base.font
                color: band.color
            }
        }
    }

    Item {
        id: holder
        anchors.fill: parent
        transformOrigin: Item.Center
        readonly property real ox: st.stroke + st.ringW
        Band { radius: st.stroke + st.ringW; color: st.outline; dx: holder.ox + st.drop; dy: holder.ox + st.drop }
        Band { radius: st.stroke + st.ringW; color: st.outline; dx: holder.ox; dy: holder.ox }
        Band { radius: st.ringW; color: st.ring; dx: holder.ox; dy: holder.ox }
        Text {
            id: base
            x: holder.ox
            y: holder.ox
            text: st.text
            color: st.fill
            font.family: st.t.fontFamily
            font.pixelSize: st.size
            font.weight: Font.Black
            font.styleName: "Black"
        }
    }
}
