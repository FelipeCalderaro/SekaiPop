import QtQuick
import QtQuick.Shapes
import "Palette.js" as P

// SekaiPop's login screen for SDDM: the lockscreen's gacha look (sekaipop/modules/sekai/lock/
// LockSurface.qml) for logging in. Your wallpaper as the art, a slate side panel whose mint tab is
// the user who logs in (the others are rows under it), the date on a band and the time as big
// outlined type, drifting sparkles, the session as a capsule at the bottom left, power keys at the
// top right, and the password row at the bottom right: the white Password pill with the typed dots
// in the card colours, the mint Log in pill with its Enter tag, a pink bubble when it fails.
//
// The colours and the wallpaper follow the shell: it writes them to theme.conf.user (a link into
// /var/lib/sekaipop-sddm, see scripts/theming/sddm-theme.sh). Sized off the screen's height
// (u = 1 at 1080 px), like the lockscreen.
//
// SDDM hands a theme `sddm`, `userModel`, `sessionModel`, `keyboard` and `config`; they are read
// through the properties below so the theme can be drawn with stand-ins (sddm/tests/render.qml).
Rectangle {
    id: root

    property var sddmApi: typeof sddm !== "undefined" ? sddm : null
    property var users: typeof userModel !== "undefined" ? userModel : null
    property var sessions: typeof sessionModel !== "undefined" ? sessionModel : null
    property var kb: typeof keyboard !== "undefined" ? keyboard : null
    property var cfg: typeof config !== "undefined" ? config : ({})
    property string themeDir: Qt.resolvedUrl(".").toString()

    function cfgStr(key, def) {
        const v = root.cfg ? root.cfg[key] : undefined
        return v === undefined || v === null || String(v) === "" ? def : String(v)
    }
    function cfgBool(key, def) {
        const v = root.cfgStr(key, def ? "true" : "false")
        return v === "true" || v === "1"
    }

    readonly property var pal: P.colours(P.raw(root.cfg))
    readonly property bool use24h: root.cfgBool("use24h", true)
    readonly property bool animations: root.cfgBool("animations", true)
    readonly property string fontFamily: gsf.status === FontLoader.Ready ? gsf.name : root.cfgStr("font", "Google Sans Flex")
    readonly property string iconFont: "Material Symbols Rounded"
    readonly property real u: Math.max(0.55, root.height / 1080)
    function px(n) { return Math.round(n * root.u) }

    // who logs in, and with what
    property int userIndex: root.users && root.users.lastIndex !== undefined && root.users.lastIndex >= 0 ? root.users.lastIndex : 0
    property string userName: ""
    property int sessionIndex: root.sessions && root.sessions.lastIndex !== undefined && root.sessions.lastIndex >= 0 ? root.sessions.lastIndex : 0
    property var sessionNames: []
    property bool busy: false
    property string failure: ""
    property string lastFailure: ""
    property date now: new Date()

    width: 1920
    height: 1080
    color: root.pal.fallbackBottom

    FontLoader {
        id: gsf
        source: root.themeDir + "fonts/GoogleSansFlex.ttf"
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.now = new Date()
    }

    Connections {
        target: root.sddmApi
        ignoreUnknownSignals: true
        function onLoginFailed() {
            root.busy = false
            root.failure = P.failureWords(root.kb ? root.kb.capsLock : false)
            root.lastFailure = root.failure
            password.text = ""
            shakeAnim.restart()
            password.forceActiveFocus()
        }
        function onLoginSucceeded() {
            root.busy = false
            root.failure = ""
        }
    }

    function login() {
        if (root.busy || !root.sddmApi || root.userName === "")
            return
        root.busy = true
        root.failure = ""
        root.sddmApi.login(root.userName, password.text, root.sessionIndex)
    }

    // the sessions' names, for the capsule (SDDM's model only hands them to a delegate)
    Instantiator {
        model: root.sessions
        delegate: QtObject {
            required property int index
            required property string name
        }
        onObjectAdded: (i, o) => {
            const a = root.sessionNames.slice()
            a[i] = o.name
            root.sessionNames = a
        }
    }

    // ===== little building blocks (as in the lockscreen) =====
    component OutlinedText: Item {
        id: ot
        property string text: ""
        property int pixelSize: 40
        property color color: "white"
        property color outlineColor: root.pal.periwinkle
        property int outline: 4
        implicitWidth: face.implicitWidth + ot.outline * 2
        implicitHeight: face.implicitHeight + ot.outline * 2
        Repeater {
            model: 14
            delegate: Text {
                required property int index
                x: ot.outline + Math.cos(index * Math.PI / 7) * ot.outline
                y: ot.outline + Math.sin(index * Math.PI / 7) * ot.outline
                text: ot.text
                color: ot.outlineColor
                font.family: root.fontFamily
                font.pixelSize: ot.pixelSize
                font.weight: Font.ExtraBold
            }
        }
        Text {
            id: face
            x: ot.outline
            y: ot.outline
            text: ot.text
            color: ot.color
            font.family: root.fontFamily
            font.pixelSize: ot.pixelSize
            font.weight: Font.ExtraBold
        }
    }

    component Sparkle: Item {
        id: sp
        property int size: 30
        property int delay: 0
        property color color: "white"
        width: sp.size
        height: sp.size
        opacity: 0
        scale: 0.5
        Shape {
            anchors.fill: parent
            antialiasing: true
            ShapePath {
                fillColor: sp.color
                strokeColor: "transparent"
                strokeWidth: -1
                startX: sp.size / 2
                startY: 0
                PathQuad { x: sp.size; y: sp.size / 2; controlX: sp.size / 2; controlY: sp.size / 2 }
                PathQuad { x: sp.size / 2; y: sp.size; controlX: sp.size / 2; controlY: sp.size / 2 }
                PathQuad { x: 0; y: sp.size / 2; controlX: sp.size / 2; controlY: sp.size / 2 }
                PathQuad { x: sp.size / 2; y: 0; controlX: sp.size / 2; controlY: sp.size / 2 }
            }
        }
        SequentialAnimation {
            running: root.animations
            PauseAnimation { duration: sp.delay }
            SequentialAnimation {
                loops: Animation.Infinite
                ParallelAnimation {
                    NumberAnimation { target: sp; property: "opacity"; to: 0.95; duration: 900; easing.type: Easing.OutQuad }
                    NumberAnimation { target: sp; property: "scale"; to: 1; duration: 900; easing.type: Easing.OutBack }
                }
                ParallelAnimation {
                    NumberAnimation { target: sp; property: "opacity"; to: 0.05; duration: 1200; easing.type: Easing.InQuad }
                    NumberAnimation { target: sp; property: "scale"; to: 0.4; duration: 1200; easing.type: Easing.InQuad }
                }
                PauseAnimation { duration: 700 }
            }
        }
    }

    component Halftone: Item {
        id: ht
        property int cols: 6
        property int rows: 8
        property int cell: 12
        property color color: "white"
        width: ht.cols * ht.cell + ht.cell / 2
        height: ht.rows * ht.cell
        Repeater {
            model: ht.cols * ht.rows
            delegate: Rectangle {
                required property int index
                readonly property int c: index % ht.cols
                readonly property int r: Math.floor(index / ht.cols)
                readonly property real k: 1 - (c + r * 0.55) / ht.cols
                visible: k > 0.12
                width: ht.cell * k * 0.92
                height: width
                radius: width / 2
                x: c * ht.cell + (r % 2) * ht.cell / 2 + (ht.cell - width) / 2
                y: r * ht.cell + (ht.cell - height) / 2
                color: ht.color
                antialiasing: true
            }
        }
    }

    component DottedLine: Item {
        id: dl
        property int dot: 4
        property int gap: 6
        property color color: root.pal.divider
        height: dl.dot
        Row {
            spacing: dl.gap
            Repeater {
                model: Math.max(0, Math.floor((dl.width + dl.gap) / (dl.dot + dl.gap)))
                delegate: Rectangle { width: dl.dot; height: dl.dot; radius: dl.dot / 2; color: dl.color }
            }
        }
    }

    component Glyph: Text {
        property string name: ""
        property real size: 24
        text: name
        font.family: root.iconFont
        font.pixelSize: size
    }

    // A dark capsule key (the lockscreen's "Locked since" capsule, clickable)
    component CapKey: Rectangle {
        id: ck
        property string icon: ""
        property string label: ""
        property string tip: ""
        signal clicked()
        height: root.px(58)
        width: ckRow.implicitWidth + root.px(ck.label !== "" ? 48 : 34)
        radius: height / 2
        color: ckArea.containsMouse ? root.pal.capHover : root.pal.cap
        scale: ckArea.pressed ? 0.95 : 1
        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
        Behavior on color { ColorAnimation { duration: 120 } }
        Row {
            id: ckRow
            anchors.centerIn: parent
            spacing: root.px(10)
            Glyph {
                visible: ck.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                name: ck.icon
                size: root.px(28)
                color: root.pal.mint
            }
            Text {
                visible: ck.label !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: ck.label
                color: "white"
                font.family: root.fontFamily
                font.pixelSize: root.px(24)
                font.weight: Font.Bold
            }
        }
        MouseArea {
            id: ckArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ck.clicked()
        }
        // the hover tag: words for an icon (docs/DESIGN-SYSTEM.md, Legibility)
        Rectangle {
            visible: ck.tip !== "" && ckArea.containsMouse
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height + root.px(10)
            width: tipText.implicitWidth + root.px(24)
            height: root.px(36)
            radius: root.px(10)
            color: root.pal.paper
            Text {
                id: tipText
                anchors.centerIn: parent
                text: ck.tip
                color: root.pal.cBorder
                font.family: root.fontFamily
                font.pixelSize: root.px(17)
                font.weight: Font.DemiBold
            }
        }
    }

    // ===== background =====
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.pal.fallbackTop }
            GradientStop { position: 1.0; color: root.pal.fallbackBottom }
        }
    }
    Image {
        id: wallpaper
        anchors.fill: parent
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(Math.max(1, root.width), Math.max(1, root.height))
        source: {
            const b = root.cfgStr("background", "")
            if (b === "") return ""
            return b.charAt(0) === "/" ? "file://" + b : root.themeDir + b
        }
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.pal.scrimTop }
            GradientStop { position: 0.5; color: root.pal.scrimClear }
            GradientStop { position: 1.0; color: root.pal.scrimBottom }
        }
    }

    // ===== foreground =====
    Item {
        id: content
        anchors.fill: parent

        Repeater {
            model: root.animations ? [
                { fx: 0.19, fy: 0.09, s: 30, d: 0 }, { fx: 0.47, fy: 0.06, s: 20, d: 700 },
                { fx: 0.62, fy: 0.22, s: 44, d: 1300 }, { fx: 0.33, fy: 0.46, s: 24, d: 400 },
                { fx: 0.79, fy: 0.13, s: 26, d: 1900 }, { fx: 0.91, fy: 0.42, s: 34, d: 900 },
                { fx: 0.55, fy: 0.64, s: 22, d: 1600 }, { fx: 0.27, fy: 0.70, s: 38, d: 300 },
                { fx: 0.72, fy: 0.55, s: 18, d: 2200 }, { fx: 0.06, fy: 0.90, s: 26, d: 1100 }
            ] : []
            delegate: Sparkle {
                required property var modelData
                required property int index
                size: root.px(modelData.s)
                delay: modelData.d
                x: modelData.fx * content.width
                y: modelData.fy * content.height
                color: index % 3 === 0 ? root.pal.sparkle : "white"
            }
        }

        // ===== side panel: the users =====
        Rectangle {
            id: sidebar
            x: root.px(48)
            y: root.px(130)
            width: root.px(340)
            height: sideCol.implicitHeight + root.px(40)
            radius: root.px(26)
            color: root.pal.panel
            border.width: 2
            border.color: root.pal.panelEdge

            Column {
                id: sideCol
                x: root.px(16)
                y: root.px(20)
                width: parent.width - root.px(32)
                spacing: root.px(6)

                Repeater {
                    model: root.users
                    delegate: Item {
                        id: userRow
                        required property int index
                        required property string name
                        required property var model
                        // optional roles: read through `model`, so a model without them still works
                        readonly property string realName: userRow.model && userRow.model.realName ? String(userRow.model.realName) : ""
                        readonly property string icon: userRow.model && userRow.model.icon ? String(userRow.model.icon) : ""
                        readonly property bool current: index === root.userIndex
                        readonly property string avatar: {
                            const own = root.cfgStr("avatarUser", "")
                            if (own !== "" && own === userRow.name && root.cfgStr("avatar", "") !== "")
                                return "file://" + root.cfgStr("avatar", "")
                            return userRow.icon !== "" ? (userRow.icon.indexOf("://") > 0 ? userRow.icon : "file://" + userRow.icon) : ""
                        }
                        onCurrentChanged: if (current) root.userName = name
                        width: sideCol.width
                        height: current ? root.px(116) : root.px(56)
                        Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

                        // the selected one: the mint tab
                        Rectangle {
                            anchors.fill: parent
                            visible: userRow.current
                            radius: root.px(18)
                            color: root.pal.mint
                            clip: true
                            Halftone {
                                x: root.px(8)
                                y: root.px(6)
                                cell: root.px(11)
                                color: root.pal.mintDeep
                            }
                            Row {
                                anchors.right: parent.right
                                anchors.rightMargin: root.px(16)
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: root.px(14)
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: root.px(2)
                                    Text {
                                        anchors.right: parent.right
                                        width: Math.min(implicitWidth, Math.max(root.px(60), sideCol.width - root.px(124)))
                                        elide: Text.ElideRight
                                        horizontalAlignment: Text.AlignRight
                                        text: userRow.realName !== "" ? userRow.realName : userRow.name
                                        color: root.pal.cBorder
                                        font.family: root.fontFamily
                                        font.pixelSize: root.px(30)
                                        font.weight: Font.ExtraBold
                                    }
                                    Text {
                                        anchors.right: parent.right
                                        text: "Welcome back"
                                        color: root.pal.subText
                                        font.family: root.fontFamily
                                        font.pixelSize: root.px(19)
                                        font.weight: Font.Medium
                                    }
                                }
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: root.px(62)
                                    height: width
                                    radius: width / 2
                                    color: "white"
                                    clip: true
                                    Glyph {
                                        anchors.centerIn: parent
                                        visible: avatarImg.status !== Image.Ready
                                        name: "person"
                                        size: root.px(36)
                                        color: root.pal.cBorder
                                    }
                                    // round: a Canvas clips the picture, so no shader effect is needed
                                    Canvas {
                                        id: avatarImg
                                        anchors.fill: parent
                                        anchors.margins: root.px(3)
                                        property int status: Image.Null
                                        readonly property string src: userRow.avatar
                                        onSrcChanged: { if (src !== "") loadImage(src); requestPaint() }
                                        Component.onCompleted: if (src !== "") loadImage(src)
                                        onImageLoaded: { status = Image.Ready; requestPaint() }
                                        onPaint: {
                                            const ctx = getContext("2d")
                                            ctx.reset()
                                            if (src === "" || !isImageLoaded(src)) return
                                            ctx.beginPath()
                                            ctx.arc(width / 2, height / 2, width / 2, 0, Math.PI * 2)
                                            ctx.clip()
                                            ctx.drawImage(src, 0, 0, width, height)
                                        }
                                    }
                                }
                            }
                        }

                        // the others: a row to pick
                        Row {
                            visible: !userRow.current
                            anchors.left: parent.left
                            anchors.leftMargin: root.px(14)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: root.px(14)
                            Glyph {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "person"
                                size: root.px(30)
                                color: root.pal.mint
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: userRow.realName !== "" ? userRow.realName : userRow.name
                                color: rowArea.containsMouse ? "white" : root.pal.lavenderText
                                font.family: root.fontFamily
                                font.pixelSize: root.px(23)
                                font.weight: Font.ExtraBold
                            }
                        }
                        MouseArea {
                            id: rowArea
                            anchors.fill: parent
                            enabled: !userRow.current
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.userIndex = userRow.index
                                root.failure = ""
                                password.text = ""
                                password.forceActiveFocus()
                            }
                        }
                    }
                }

                // the machine's name under the users, on a dotted rule
                DottedLine {
                    width: parent.width
                    dot: root.px(4)
                    gap: root.px(7)
                }
                Row {
                    x: root.px(14)
                    spacing: root.px(12)
                    Glyph {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "computer"
                        size: root.px(26)
                        color: root.pal.mint
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.sddmApi && root.sddmApi.hostName ? root.sddmApi.hostName : root.cfgStr("hostName", "")
                        color: root.pal.lavenderText
                        font.family: root.fontFamily
                        font.pixelSize: root.px(19)
                        font.weight: Font.Medium
                    }
                }
            }
        }

        // ===== the title: date band and the time =====
        Item {
            id: titleBlock
            x: sidebar.x + sidebar.width + root.px(64)
            y: root.px(34)
            Rectangle {
                id: dateBand
                height: root.px(64)
                width: dateLabel.implicitWidth + root.px(90)
                radius: root.px(12)
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: root.pal.band }
                    GradientStop { position: 0.75; color: root.pal.band }
                    GradientStop { position: 1.0; color: root.pal.bandClear }
                }
                Text {
                    id: dateLabel
                    x: root.px(22)
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDate(root.now, "dddd, MMMM d")
                    color: "white"
                    font.family: root.fontFamily
                    font.pixelSize: root.px(38)
                    font.weight: Font.Bold
                }
            }
            OutlinedText {
                id: bigClock
                y: dateBand.height + root.px(2)
                text: Qt.formatDateTime(root.now, root.use24h ? "HH:mm" : "hh:mm AP").split(" ")[0]
                pixelSize: root.px(236)
                outline: root.px(7)
            }
            Rectangle {
                visible: !root.use24h
                x: bigClock.width + root.px(10)
                y: bigClock.y + bigClock.height * 0.56
                width: ampm.implicitWidth + root.px(44)
                height: root.px(58)
                radius: root.px(14)
                color: root.pal.mint
                Text {
                    id: ampm
                    anchors.centerIn: parent
                    text: Qt.formatDateTime(root.now, "AP")
                    color: root.pal.cBorder
                    font.family: root.fontFamily
                    font.pixelSize: root.px(36)
                    font.weight: Font.ExtraBold
                }
            }
        }

        // ===== top right: power =====
        Row {
            anchors.right: parent.right
            anchors.rightMargin: root.px(64)
            y: root.px(40)
            spacing: root.px(14)
            CapKey {
                visible: root.sddmApi && root.sddmApi.canSuspend === true
                icon: "bedtime"
                tip: "Sleep"
                onClicked: root.sddmApi.suspend()
            }
            CapKey {
                visible: root.sddmApi && root.sddmApi.canReboot === true
                icon: "restart_alt"
                tip: "Restart"
                onClicked: root.sddmApi.reboot()
            }
            CapKey {
                visible: root.sddmApi && root.sddmApi.canPowerOff === true
                icon: "power_settings_new"
                tip: "Shut down"
                onClicked: root.sddmApi.powerOff()
            }
        }

        // ===== bottom left: the session =====
        CapKey {
            id: sessionKey
            x: root.px(64)
            y: x + width + root.px(24) > controls.x ? controls.y - height - root.px(20) : parent.height - height - root.px(56)
            visible: root.sessionNames.length > 0
            icon: "desktop_windows"
            label: (root.sessionNames[root.sessionIndex] || "Session") + (root.sessionNames.length > 1 ? "  ›" : "")
            tip: root.sessionNames.length > 1 ? "Click for the next session" : ""
            onClicked: {
                if (root.sessionNames.length > 1)
                    root.sessionIndex = (root.sessionIndex + 1) % root.sessionNames.length
                password.forceActiveFocus()
            }
        }

        // ===== bottom right: the password row =====
        Item {
            id: controls
            readonly property int pillH: root.px(122)
            readonly property int pwW: root.px(560)
            readonly property int unW: root.px(330)
            readonly property int gap: root.px(26)
            anchors.right: parent.right
            anchors.rightMargin: root.px(84)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.px(52)
            width: pwW + gap + unW
            height: pillH

            // the real text field: invisible, it only holds what is typed
            TextInput {
                id: password
                width: 1
                height: 1
                opacity: 0
                echoMode: TextInput.Password
                focus: true
                enabled: !root.busy
                Component.onCompleted: forceActiveFocus()
                onTextChanged: if (text !== "") root.failure = ""
                onAccepted: root.login()
                Keys.onEscapePressed: text = ""
            }
            MouseArea {
                anchors.fill: parent
                onPressed: mouse => { password.forceActiveFocus(); mouse.accepted = false }
            }

            Item {
                id: pwGroup
                width: controls.pwW
                height: controls.pillH
                transform: Translate { id: shake; x: 0 }
                SequentialAnimation {
                    id: shakeAnim
                    NumberAnimation { target: shake; property: "x"; to: -root.px(16); duration: 55 }
                    NumberAnimation { target: shake; property: "x"; to: root.px(14); duration: 70 }
                    NumberAnimation { target: shake; property: "x"; to: -root.px(9); duration: 70 }
                    NumberAnimation { target: shake; property: "x"; to: root.px(5); duration: 60 }
                    NumberAnimation { target: shake; property: "x"; to: 0; duration: 60 }
                }
                Rectangle {
                    y: root.px(6)
                    width: parent.width
                    height: parent.height
                    radius: height * 0.42
                    color: root.pal.shadow
                }
                Rectangle {
                    anchors.fill: parent
                    radius: height * 0.42
                    color: root.pal.paper
                    border.width: root.failure !== "" ? root.px(4) : 0
                    border.color: root.pal.pink
                    Behavior on border.width { NumberAnimation { duration: 120 } }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width - 2 * (layoutTag.visible ? layoutTag.width + root.px(28) : root.px(24))
                        y: root.px(12)
                        height: Math.max(0, well.y - y - root.px(6))
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: root.busy ? "Checking…" : (root.kb && root.kb.capsLock ? "Password · Caps Lock" : "Password")
                        color: root.pal.cBorder
                        font.family: root.fontFamily
                        font.pixelSize: root.px(34)
                        fontSizeMode: Text.HorizontalFit
                        minimumPixelSize: root.px(22)
                        font.weight: Font.ExtraBold
                    }

                    // the keyboard layout, as a tag on the corner (click: the next one)
                    Rectangle {
                        id: layoutTag
                        readonly property var layouts: root.kb && root.kb.layouts ? root.kb.layouts : []
                        visible: layoutTag.layouts.length > 1
                        x: parent.width - width - root.px(14)
                        y: root.px(8)
                        width: layoutText.implicitWidth + root.px(26)
                        height: root.px(30)
                        radius: height / 2
                        color: root.pal.mint
                        Text {
                            id: layoutText
                            anchors.centerIn: parent
                            text: {
                                const l = layoutTag.layouts[root.kb ? root.kb.currentLayout : 0]
                                return l ? String(l.shortName || l.longName || "").toUpperCase() : ""
                            }
                            color: root.pal.cBorder
                            font.family: root.fontFamily
                            font.pixelSize: root.px(18)
                            font.weight: Font.ExtraBold
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.kb.currentLayout = (root.kb.currentLayout + 1) % layoutTag.layouts.length
                                password.forceActiveFocus()
                            }
                        }
                    }

                    // the dark well: the typed dots sit in here, in the card colours
                    Rectangle {
                        id: well
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: root.px(14)
                        width: parent.width - root.px(64)
                        height: root.px(48)
                        radius: height / 2
                        color: root.pal.well
                        Row {
                            id: dots
                            anchors.centerIn: parent
                            spacing: root.px(9)
                            opacity: root.busy ? 0.45 : 1
                            readonly property int shown: Math.min(password.text.length, 16)
                            Repeater {
                                model: dots.shown
                                delegate: Rectangle {
                                    required property int index
                                    width: root.px(22)
                                    height: width
                                    radius: width / 2
                                    antialiasing: true
                                    color: P.dotColour(root.pal, password.text.length - dots.shown + index)
                                    NumberAnimation on scale { from: 0.3; to: 1; duration: 150; easing.type: Easing.OutBack; easing.overshoot: 2.5 }
                                }
                            }
                        }
                    }
                }

                // the pink callout: why it failed
                Item {
                    id: bubble
                    x: root.px(34)
                    y: -height - root.px(18)
                    width: Math.min(bubbleText.implicitWidth + root.px(52), root.px(640))
                    height: root.px(58)
                    opacity: root.failure !== "" ? 1 : 0
                    scale: root.failure !== "" ? 1 : 0.85
                    transformOrigin: Item.BottomLeft
                    Behavior on opacity { NumberAnimation { duration: 160 } }
                    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
                    Rectangle { anchors.fill: parent; radius: root.px(14); color: root.pal.pink }
                    Rectangle {
                        x: root.px(40)
                        y: parent.height - root.px(13)
                        width: root.px(24)
                        height: width
                        rotation: 45
                        color: root.pal.pink
                    }
                    Text {
                        id: bubbleText
                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, bubble.width - root.px(52))
                        elide: Text.ElideRight
                        text: root.lastFailure
                        color: "white"
                        font.family: root.fontFamily
                        font.pixelSize: root.px(26)
                        font.weight: Font.Bold
                    }
                }
            }

            // the mint "Log in" pill
            Item {
                id: loginPill
                x: controls.pwW + controls.gap
                width: controls.unW
                height: controls.pillH
                scale: loginArea.pressed ? 0.97 : 1
                Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
                Rectangle {
                    y: root.px(6)
                    width: parent.width
                    height: parent.height
                    radius: height * 0.42
                    color: root.pal.shadow
                }
                Rectangle {
                    anchors.fill: parent
                    radius: height * 0.42
                    color: root.pal.mint
                    Text {
                        id: loginLabel
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.horizontalCenterOffset: root.px(30)
                        y: root.px(12)
                        text: "Log in"
                        color: root.pal.cBorder
                        font.family: root.fontFamily
                        font.pixelSize: root.px(34)
                        font.weight: Font.ExtraBold
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: root.px(14)
                        width: parent.width - root.px(64)
                        height: root.px(48)
                        radius: height / 2
                        color: root.pal.well
                        Glyph {
                            anchors.centerIn: parent
                            name: root.busy ? "progress_activity" : "arrow_forward"
                            size: root.px(28)
                            color: root.pal.mint
                            RotationAnimator on rotation {
                                running: root.busy
                                from: 0
                                to: 360
                                duration: 900
                                loops: Animation.Infinite
                                onRunningChanged: if (!running) parent.rotation = 0
                            }
                        }
                    }
                }
                Rectangle {
                    x: root.px(32)
                    y: loginLabel.parent.y + loginLabel.y + loginLabel.baselineOffset - hint.y - hint.baselineOffset - root.px(8)
                    width: hint.implicitWidth + root.px(26)
                    height: root.px(30)
                    radius: height / 2
                    color: root.pal.pink
                    Text {
                        id: hint
                        anchors.centerIn: parent
                        text: "Enter"
                        color: "white"
                        font.family: root.fontFamily
                        font.pixelSize: root.px(18)
                        font.weight: Font.ExtraBold
                    }
                }
                MouseArea {
                    id: loginArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { password.forceActiveFocus(); root.login() }
                }
            }
        }
    }
}
