import QtQuick

// Mochi, drawn in the shell's own construction (original art, no sprites): a round body with a
// thick outline, a pale ring, a flat hard shadow on the ground, two ears, eyes that blink, cheeks
// and two feet. `mode` picks the pose; every animation runs only while `live`.
Item {
    id: m
    required property var t
    property string mode: "sit"
    property int facing: 1
    property color body: m.t.accentMint
    property bool live: true

    implicitWidth: 76
    implicitHeight: 84

    readonly property color ink: m.t.colBorder
    readonly property real bw: m.t.borderWidth

    // the hard shadow, flat on the ground (it never moves up with a hop)
    Rectangle {
        x: 10
        y: m.height - 10
        width: m.width - 20
        height: 8
        radius: 4
        color: m.t.pLineShadow
        opacity: 0.9
        scale: 1 - hopper.y / -60
    }

    Item {
        id: hopper
        width: m.width
        height: m.height - 6

        // ---- poses: a bob while sitting, a bounce while dancing, a hop when happy, a step walk
        SequentialAnimation on y {
            running: m.live && (m.mode === "dance" || m.mode === "happy")
            loops: Animation.Infinite
            NumberAnimation { to: m.mode === "happy" ? -22 : -10; duration: m.mode === "happy" ? 220 : 240; easing.type: Easing.OutQuad }
            NumberAnimation { to: 0; duration: m.mode === "happy" ? 260 : 240; easing.type: Easing.OutBounce }
            onRunningChanged: if (!running) hopper.y = 0
        }
        SequentialAnimation on rotation {
            running: m.live && m.mode === "dance"
            loops: Animation.Infinite
            NumberAnimation { to: -8; duration: 480; easing.type: Easing.InOutSine }
            NumberAnimation { to: 8; duration: 480; easing.type: Easing.InOutSine }
            onRunningChanged: if (!running) hopper.rotation = 0
        }
        transformOrigin: Item.Bottom

        Item {
            id: figure
            anchors.fill: parent
            transform: Scale { origin.x: figure.width / 2; xScale: m.facing < 0 ? -1 : 1 }

            // breathing (sit / sleep): a gentle squash
            SequentialAnimation on scale {
                running: m.live && (m.mode === "sit" || m.mode === "sleep")
                loops: Animation.Infinite
                NumberAnimation { to: 1.03; duration: m.mode === "sleep" ? 1600 : 1200; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: m.mode === "sleep" ? 1600 : 1200; easing.type: Easing.InOutSine }
                onRunningChanged: if (!running) figure.scale = 1
            }
            transformOrigin: Item.Bottom

            // feet (step in turn while walking)
            Repeater {
                model: 2
                Rectangle {
                    required property int index
                    x: index === 0 ? 18 : m.width - 36
                    y: figure.height - 14
                    width: 18
                    height: 12
                    radius: 6
                    color: Qt.darker(m.body, 1.15)
                    border.width: m.bw
                    border.color: m.ink
                    SequentialAnimation on y {
                        running: m.live && m.mode === "walk"
                        loops: Animation.Infinite
                        PauseAnimation { duration: index * 180 }
                        NumberAnimation { to: figure.height - 20; duration: 180; easing.type: Easing.OutQuad }
                        NumberAnimation { to: figure.height - 14; duration: 180; easing.type: Easing.InQuad }
                        onRunningChanged: if (!running) parent.y = figure.height - 14
                    }
                }
            }

            // ears (behind the body)
            Repeater {
                model: 2
                Rectangle {
                    required property int index
                    x: index === 0 ? 12 : m.width - 34
                    y: 6
                    width: 22
                    height: 26
                    radius: 10
                    rotation: index === 0 ? -20 : 20
                    color: m.body
                    border.width: m.bw
                    border.color: m.ink
                    Rectangle {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: 2
                        width: 8; height: 12; radius: 4
                        color: "#ff9ecb"
                    }
                }
            }

            // the body: outline, pale ring, fill
            Rectangle {
                id: bodyShape
                x: 6
                y: 16
                width: m.width - 12
                height: figure.height - 26
                radius: width / 2.2
                color: m.t.pRingWhite
                border.width: m.bw
                border.color: m.ink
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: m.bw + 2
                    radius: width / 2.2
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.lighter(m.body, 1.12) }
                        GradientStop { position: 1; color: m.body }
                    }
                }

                // eyes: open dots that blink; closed arcs while asleep; happy arcs when happy
                Repeater {
                    model: 2
                    Item {
                        required property int index
                        x: bodyShape.width / 2 + (index === 0 ? -17 : 7)
                        y: bodyShape.height * 0.36
                        width: 10
                        height: 12
                        Rectangle {
                            id: eye
                            anchors.centerIn: parent
                            visible: m.mode !== "sleep" && m.mode !== "happy"
                            width: 8
                            height: 11
                            radius: 4
                            color: m.ink
                            Rectangle { x: 4; y: 2; width: 3; height: 3; radius: 1.5; color: "#ffffff" }
                            SequentialAnimation on height {
                                running: m.live && eye.visible
                                loops: Animation.Infinite
                                PauseAnimation { duration: 2600 + parent.index * 40 }
                                NumberAnimation { to: 2; duration: 70 }
                                NumberAnimation { to: 11; duration: 90 }
                            }
                        }
                        // closed / happy: a little arc (a ring cut in half)
                        Item {
                            anchors.centerIn: parent
                            visible: m.mode === "sleep" || m.mode === "happy"
                            width: 12
                            height: 6
                            clip: true
                            Rectangle {
                                y: m.mode === "happy" ? 0 : -6
                                width: 12
                                height: 12
                                radius: 6
                                color: "transparent"
                                border.width: 2.5
                                border.color: m.ink
                            }
                        }
                    }
                }
                // cheeks
                Repeater {
                    model: 2
                    Rectangle {
                        required property int index
                        x: index === 0 ? 8 : bodyShape.width - 22
                        y: bodyShape.height * 0.56
                        width: 14
                        height: 7
                        radius: 3.5
                        color: "#ff9ecb"
                        opacity: 0.85
                    }
                }
                // mouth: a small smile, an "o" while dancing
                Rectangle {
                    x: bodyShape.width / 2 - width / 2 + 3
                    y: bodyShape.height * 0.58
                    width: m.mode === "dance" ? 7 : 8
                    height: m.mode === "dance" ? 8 : 4
                    radius: m.mode === "dance" ? 3.5 : 2
                    color: m.mode === "dance" ? m.ink : "transparent"
                    border.width: m.mode === "dance" ? 0 : 2
                    border.color: m.ink
                }
            }
        }
    }
}
