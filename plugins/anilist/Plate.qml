import QtQuick
import Quickshell.Widgets

// The header plate the shell's popups open with (SekaiPlate.qml, docs/DESIGN-SYSTEM.md
// "Plate"): a gradient slab on the block construction (outline, ring, hard shadow), a printed
// halftone fading out of one corner and two slanted bands of stage light. This one can also
// lay your AniList banner under the gradient.
//
// Children land on the plate's face, unclipped, so a tag can break over its edge.
Item {
    id: plate

    required property var t
    property color colorTop: Qt.lighter(plate.colorBottom, 1.18)
    property color colorBottom: plate.t.accentCyan
    property string banner: ""
    property real cornerRadius: 16
    readonly property real ring: plate.t.borderWidth + 2
    // Dots and light: dark on a light plate, white on a dark one.
    property color dotColor: Qt.rgba(plate.t.colBorder.r, plate.t.colBorder.g, plate.t.colBorder.b, 0.16)
    property color bandColor: Qt.rgba(1, 1, 1, 0.20)

    default property alias content: face.data
    readonly property real faceHeight: plate.height - plate.t.shadowOffset

    Rectangle {
        y: plate.t.shadowOffset
        width: plate.width
        height: plate.faceHeight
        radius: plate.cornerRadius
        color: plate.t.lineShadow
        antialiasing: true
    }

    Rectangle {
        width: plate.width
        height: plate.faceHeight
        radius: plate.cornerRadius
        color: plate.t.ringWhite
        border.width: plate.t.borderWidth
        border.color: plate.t.line
        antialiasing: true
    }

    // The fill: the gradient, then (optionally) your banner, then the print on top.
    Rectangle {
        id: fill
        x: plate.ring
        y: plate.ring
        width: plate.width - 2 * plate.ring
        height: plate.faceHeight - 2 * plate.ring
        radius: Math.max(0, plate.cornerRadius - plate.ring)
        antialiasing: true
        gradient: Gradient {
            GradientStop { position: 0; color: plate.colorTop }
            GradientStop { position: 1; color: plate.colorBottom }
        }
    }

    // Only the picture needs its corners cut.
    ClippingRectangle {
        anchors.fill: fill
        radius: fill.radius
        color: "transparent"
        visible: bannerImg.status === Image.Ready && plate.banner !== ""

        Image {
            id: bannerImg
            anchors.fill: parent
            source: plate.banner
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 760
            opacity: 0.55
        }
        // The gradient comes back from the left, so the text stays readable over the banner.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.rgba(plate.colorBottom.r, plate.colorBottom.g, plate.colorBottom.b, 0.95) }
                GradientStop { position: 0.55; color: Qt.rgba(plate.colorBottom.r, plate.colorBottom.g, plate.colorBottom.b, 0.55) }
                GradientStop { position: 1; color: Qt.rgba(plate.colorBottom.r, plate.colorBottom.g, plate.colorBottom.b, 0.15) }
            }
        }
    }

    // Halftone (top-right, shrinking toward the middle) and two light bands, clipped to the
    // fill's rounded shape by the canvas itself. Drawn once; again only if size or colour change.
    Canvas {
        id: deco
        anchors.fill: fill
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections {
            target: plate
            function onDotColorChanged() { deco.requestPaint() }
            function onBandColorChanged() { deco.requestPaint() }
        }
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const w = width, h = height, sp = 13, reach = Math.hypot(w, h) * 0.55
            ctx.beginPath()
            ctx.roundedRect(0, 0, w, h, fill.radius, fill.radius)
            ctx.clip()
            ctx.fillStyle = plate.dotColor
            for (let y = sp / 2; y < h; y += sp) {
                for (let x = sp / 2; x < w; x += sp) {
                    const r = 3.2 * (1 - Math.hypot(w - x, y) / reach)
                    if (r > 0.35) {
                        ctx.beginPath()
                        ctx.arc(x, y, r, 0, Math.PI * 2)
                        ctx.fill()
                    }
                }
            }
            ctx.fillStyle = plate.bandColor
            const band = (x0, bw) => {
                ctx.beginPath()
                ctx.moveTo(x0 + h * 0.45, 0)
                ctx.lineTo(x0 + h * 0.45 + bw, 0)
                ctx.lineTo(x0 + bw, h)
                ctx.lineTo(x0, h)
                ctx.closePath()
                ctx.fill()
            }
            band(w * 0.52, 26)
            band(w * 0.52 + 36, 9)
        }
    }

    Item {
        id: face
        width: plate.width
        height: plate.faceHeight
    }
}
