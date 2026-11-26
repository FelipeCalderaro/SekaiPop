import QtQuick
import "kit"
import "Pet.js" as PET

// Desk Pet: Mochi (Mochi.qml) on a strip of the desktop. Pet.js decides what it does once a
// second; this moves it (x, over the walk's time) and floats the little stickers over its head
// (♪ while dancing, z z z asleep, ♥ when clicked). The strip itself is invisible, except a faint
// dashed floor in Edit Desktop, so you can see how far it roams.
Item {
    id: root
    required property var host

    readonly property var t: root.host.theme
    readonly property var s: root.host.settings
    readonly property var svc: root.host.service
    readonly property real stripW: Math.max(160, root.s.width)
    readonly property color body: ({
        mint: root.t.accentMint, cyan: root.t.accentCyan, pink: "#ff9ecb", yellow: "#ffe066", lilac: "#b39ddb"
    })[root.s.color] || root.t.accentMint

    readonly property real size: Math.max(0.8, Math.min(2, root.s.size))
    property var st: PET.start(Date.now())
    property bool clicked: false

    implicitWidth: root.stripW
    implicitHeight: 150 + 90 * (root.size - 1)

    function tick() {
        root.st = PET.step(root.st, {
            now: Date.now(),
            playing: root.s.dance && root.svc ? root.svc.playing : false,
            idle: root.svc ? root.svc.idle : false,
            rnd: Math.random,
            clicked: root.clicked
        })
        root.clicked = false
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.host.working
        onTriggered: root.tick()
    }

    // Edit Desktop: the floor it walks on
    Row {
        visible: root.host.editing
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        spacing: 6
        Repeater {
            model: Math.floor(root.stripW / 14)
            Rectangle { width: 8; height: 3; radius: 1.5; color: root.t.pInkSub }
        }
    }

    Item {
        id: walker
        width: pet.width * root.size
        height: parent.height
        readonly property real room: root.stripW - pet.width
        // walking: head for the target over the walk's time; otherwise stay put (or settle quickly)
        x: (root.st.mode === "walk" ? root.st.target : root.st.x) * walker.room
        Behavior on x {
            NumberAnimation {
                duration: root.st.mode === "walk" ? PET.walkMs(root.st.x, root.st.target) : 300
                easing.type: root.st.mode === "walk" ? Easing.Linear : Easing.OutQuad
            }
        }

        Mochi {
            id: pet
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4 + 18 * (root.size - 1)
            scale: root.size
            transformOrigin: Item.Bottom
            t: root.t
            mode: root.st.mode
            facing: root.st.facing
            body: root.body
            live: root.host.working
        }

        // what it's feeling, as a little sticker over its head
        Sticker {
            id: mood
            readonly property string word: PET.mood(root.st.mode)
            visible: word !== ""
            t: root.t
            text: word
            size: 20
            fill: root.st.mode === "happy" ? "#ff9ecb" : "#ffffff"
            anchors.horizontalCenter: pet.horizontalCenter
            anchors.horizontalCenterOffset: 16 * root.size
            y: 2
            SequentialAnimation on y {
                running: mood.visible && root.host.working
                loops: Animation.Infinite
                NumberAnimation { from: 10; to: -2; duration: 1100; easing.type: Easing.OutQuad }
                NumberAnimation { from: -2; to: 10; duration: 0 }
            }
        }

        // its name, on a slanted tag under it
        Tag {
            visible: root.s.showName && String(root.s.name).trim() !== ""
            t: root.t
            text: root.s.name
            anchors.horizontalCenter: pet.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: -4
            scale: 0.85
        }

        MouseArea {
            anchors.horizontalCenter: pet.horizontalCenter
            anchors.bottom: pet.bottom
            width: pet.width * root.size
            height: pet.height * root.size
            cursorShape: Qt.PointingHandCursor
            onClicked: { root.clicked = true; root.tick() }
        }
    }
}
