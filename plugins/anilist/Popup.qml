import QtQuick
import Quickshell.Widgets
import "AniList.js" as AL

// The card under the AniList entry (docs/PLUGINS.md, "Popup.qml"). The shell draws the card,
// places it under the pill on any edge, pops it in and swallows it back into the pill; this is
// its face:
//
//   ┌────────────────────────────────────────────┐
//   │ (avatar)  ANILIST · WATCHING     [5 ON LIST]│   plate: your profile colour (or the
//   │           yourname                          │   theme's, or the newest cover's), your
//   │           245 ep · 3.4 days · mean 78       │   banner under it, halftone + light
//   ├────────────────────────────────────────────┤
//   │ ◆ AIRING & WATCHING       [Watching|Reading]│   tab (+ switch when you follow both)
//   │ ┌ row ─────────────────────────────────────┐│
//   │ └──────────────────────────────────────────┘│   up to five rows, then it scrolls
//   │ [⟳ Refresh] [↗ AniList]      updated 2 min ago│
//   └────────────────────────────────────────────┘
//
// Three pages under the plate, switched by the keys at the bottom:
//   list      the above
//   account   connect: a public username, or Sign in with AniList (the token comes back to the
//             plugin by itself, see Service.qml startSignIn), and sign out
//   settings  every option as chips
// Not set up yet, it opens on the account page. Nothing has to be typed into a file.
Item {
    id: root

    required property var host

    readonly property var t: root.host.theme
    readonly property var svc: root.host.service
    readonly property var s: root.host.settings

    readonly property bool both: root.s.listType === "BOTH"
    // "ANIME" | "MANGA": which list the switch shows (only matters with both).
    property string kind: "ANIME"

    readonly property var shownEntries: {
        if (!root.svc)
            return []
        const list = root.both ? root.svc.entries.filter(e => e.kind === root.kind) : root.svc.entries
        return AL.sorted(list, root.s.sortBy, root.svc.nowSec)
            .slice(0, Math.max(1, Number(root.s.maxEntries) || 8))
    }

    // The plate's colour: the profile's, the theme's, or the newest cover's.
    readonly property color accent: {
        const theme = root.t.accentCyan
        if (!root.svc)
            return theme
        if (root.s.accent === "profile" && root.svc.user && root.svc.user.options) {
            const c = AL.profileColor(root.svc.user.options.profileColor)
            return c !== "" ? c : theme
        }
        if (root.s.accent === "cover" && root.svc.entries.length > 0 && root.svc.entries[0].color !== "")
            return root.svc.entries[0].color
        return theme
    }
    readonly property bool lightPlate: AL.isLight(String(root.accent))
    readonly property color plateInk: root.lightPlate ? root.t.colBorder : "#ffffff"
    readonly property color plateInkSub: Qt.rgba(root.plateInk.r, root.plateInk.g, root.plateInk.b, 0.78)

    // A slanted section tab with a diamond (the shell's SectionTab).
    component StepTab: Item {
        property string text: ""
        width: tabLabel.implicitWidth + 40
        height: 22
        Rectangle {
            anchors.fill: parent
            anchors.rightMargin: 4
            radius: 8
            color: root.t.chipFill
            transform: Matrix4x4 { matrix: Qt.matrix4x4(1, -0.2, 0, 0.2 * 11, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
        }
        Rectangle {
            x: 11
            anchors.verticalCenter: parent.verticalCenter
            width: 7
            height: 7
            rotation: 45
            color: root.t.dark ? root.t.accentMint : root.t.colBorder
        }
        Text {
            id: tabLabel
            x: 24
            anchors.verticalCenter: parent.verticalCenter
            text: parent.text
            color: root.t.chipInk
            font.family: root.t.fontFamily
            font.pixelSize: 10
            font.weight: Font.ExtraBold
            font.styleName: root.t.fontStyleBold
            font.letterSpacing: 0.6
        }
    }

    // A numbered step: a small round badge, then the words.
    component Step: Item {
        id: step
        property string number: ""
        property string text: ""
        width: parent ? parent.width : 0
        height: Math.max(20, stepText.implicitHeight)
        Rectangle {
            width: 18
            height: 18
            radius: 9
            color: root.t.accentMint
            border.width: 2
            border.color: root.t.colBorder
            Text {
                anchors.centerIn: parent
                text: step.number
                color: root.t.colBorder
                font.family: root.t.fontFamily
                font.pixelSize: 10
                font.weight: Font.ExtraBold
                font.styleName: root.t.fontStyleBold
            }
        }
        Text {
            id: stepText
            x: 26
            width: parent.width - 26
            wrapMode: Text.WordWrap
            text: step.text
            color: root.t.ink
            font.family: root.t.fontFamily
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }
    }

    // A line of help under a field.
    component Hint: Text {
        property bool strong: false
        width: parent ? parent.width : 0
        wrapMode: Text.WordWrap
        color: strong ? root.t.ink : root.t.inkSub
        font.family: root.t.fontFamily
        font.pixelSize: 10
        font.weight: strong ? Font.ExtraBold : Font.DemiBold
    }

    readonly property int rowH: 66 + root.t.shadowOffset
    readonly property int rowGap: 8
    readonly property int visibleRows: Math.max(1, Math.min(5, root.shownEntries.length))

    implicitWidth: 380
    implicitHeight: col.implicitHeight + 28

    // 0 -> 1 as the card opens: the rows slide in one after another (left at 1 on the way out,
    // so they stay put while the card shrinks into the pill).
    property real enter: 1
    readonly property bool open: root.host.popup.open
    onOpenChanged: {
        if (root.open)
            enterAnim.restart()
        else
            root.page = ""   // back to the natural page every time the card opens
    }
    NumberAnimation {
        id: enterAnim
        target: root
        property: "enter"
        from: 0
        to: 1
        duration: 420
        easing.type: Easing.OutBack
        easing.overshoot: 1.3
    }

    // "" = the natural page: the list once connected, the account page before.
    property string page: ""
    readonly property bool configured: !!root.svc && root.svc.configured
    readonly property string shownPage: root.page !== "" ? root.page : (root.configured ? "list" : "account")
    function go(p) {
        root.page = p
    }
    // Connecting (a username or a sign-in) takes you to your list.
    onConfiguredChanged: if (root.configured && root.page === "account" && !root.svc.signedIn) root.page = ""
    Connections {
        target: root.svc
        function onSignedInChanged() { if (root.svc.signedIn) root.page = "" }
    }
    // A new page slides in from the right and fades up, the rows stagger again.
    property real pageIn: 1
    onShownPageChanged: {
        pageAnim.restart()
        enterAnim.restart()
    }
    NumberAnimation {
        id: pageAnim
        target: root
        property: "pageIn"
        from: 0
        to: 1
        duration: 260
        easing.type: Easing.OutBack
        easing.overshoot: 1.2
    }

    readonly property var settingsRows: [
        { key: "listType", label: "Lists", options: [{ value: "ANIME", label: "Anime" }, { value: "MANGA", label: "Manga" }, { value: "BOTH", label: "Both" }] },
        { key: "barShows", label: "Bar shows", options: [{ value: "airing", label: "Next ep" }, { value: "progress", label: "Progress" }, { value: "count", label: "Count" }, { value: "unread", label: "Alerts" }] },
        { key: "sortBy", label: "Order", options: [{ value: "airing", label: "Airing soon" }, { value: "updated", label: "Recent" }] },
        { key: "titleLanguage", label: "Titles", options: [{ value: "user", label: "Mine" }, { value: "romaji", label: "Romaji" }, { value: "english", label: "English" }, { value: "native", label: "Native" }] },
        { key: "accent", label: "Header", options: [{ value: "profile", label: "Profile" }, { value: "theme", label: "Theme" }, { value: "cover", label: "Cover" }] },
        { key: "showBanner", label: "Banner", options: [{ value: true, label: "On" }, { value: false, label: "Off" }] },
        { key: "maxEntries", label: "Entries", options: [{ value: 5, label: "5" }, { value: 8, label: "8" }, { value: 12, label: "12" }, { value: 20, label: "20" }] },
        { key: "refreshMinutes", label: "Check every", options: [{ value: 5, label: "5 min" }, { value: 15, label: "15 min" }, { value: 30, label: "30 min" }, { value: 60, label: "1 h" }] },
        { key: "hideWhenEmpty", label: "Empty list", options: [{ value: false, label: "Keep pill" }, { value: true, label: "Hide pill" }] }
    ]

    Column {
        id: col
        x: 16
        y: 14
        width: root.width - 32
        spacing: 10

        // ===== the plate =====
        Plate {
            id: plate
            t: root.t
            width: col.width
            height: 88 + root.t.shadowOffset
            colorBottom: root.accent
            banner: root.s.showBanner && root.svc && root.svc.user && root.svc.user.bannerImage
                ? root.svc.user.bannerImage : ""
            dotColor: root.lightPlate ? Qt.rgba(root.t.colBorder.r, root.t.colBorder.g, root.t.colBorder.b, 0.16)
                                      : Qt.rgba(1, 1, 1, 0.20)

            // Avatar: white ring, outline, the picture (or a letter until it arrives).
            Item {
                id: avatar
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 50
                height: 50

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "#ffffff"
                    border.width: 2.5
                    border.color: root.t.colBorder
                    antialiasing: true
                }
                // Until the picture arrives (or without one): a letter on the accent.
                Rectangle {
                    anchors.centerIn: parent
                    width: 41
                    height: 41
                    radius: 20.5
                    color: Qt.darker(root.accent, 1.2)
                    antialiasing: true
                }
                Text {
                    anchors.centerIn: parent
                    visible: avatarImg.status !== Image.Ready
                    text: root.svc && root.svc.configured ? (root.svc.user ? root.svc.user.name : root.svc.username || "?").charAt(0).toUpperCase() : "live_tv"
                    color: "#ffffff"
                    font.family: root.svc && root.svc.configured ? root.t.fontFamily : root.t.iconFont
                    font.pixelSize: 20
                    font.weight: Font.ExtraBold
                    font.styleName: root.t.fontStyleBold
                }
                ClippingRectangle {
                    anchors.centerIn: parent
                    width: 41
                    height: 41
                    radius: 20.5
                    color: "transparent"
                    visible: avatarImg.status === Image.Ready

                    Image {
                        id: avatarImg
                        anchors.fill: parent
                        source: root.svc && root.svc.user && root.svc.user.avatar ? (root.svc.user.avatar.large || root.svc.user.avatar.medium || "") : ""
                        sourceSize: Qt.size(96, 96)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true
                    }
                }

                // Signed in: a mint dot (it breathes while a refresh is out).
                Rectangle {
                    id: liveDot
                    visible: !!root.svc && root.svc.signedIn
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: -3
                    anchors.bottomMargin: -3
                    width: 14
                    height: 14
                    radius: 7
                    color: root.t.accentMint
                    border.width: 2.5
                    border.color: root.t.line
                    antialiasing: true
                    SequentialAnimation on opacity {
                        running: !!root.svc && root.svc.loading
                        loops: Animation.Infinite
                        onRunningChanged: if (!running) liveDot.opacity = 1
                        NumberAnimation { to: 0.4; duration: 600; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutSine }
                    }
                }
            }

            Column {
                anchors {
                    left: avatar.right
                    leftMargin: 14
                    right: countTag.left
                    rightMargin: 8
                    verticalCenter: parent.verticalCenter
                    verticalCenterOffset: -1
                }
                spacing: 1

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: "ANILIST · " + (root.both ? (root.kind === "MANGA" ? "READING" : "WATCHING")
                                                    : (root.s.listType === "MANGA" ? "READING" : "WATCHING"))
                    color: root.plateInkSub
                    font.family: root.t.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    font.letterSpacing: 0.7
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: root.svc && root.svc.user ? root.svc.user.name
                        : (root.svc && root.svc.username !== "" ? root.svc.username : "Not connected")
                    color: root.plateInk
                    font.family: root.t.fontFamily
                    font.pixelSize: 19
                    font.weight: Font.ExtraBold
                    font.styleName: root.t.fontStyleBold
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    visible: text !== ""
                    text: root.svc ? AL.statsText(root.svc.user, root.both ? root.kind : root.s.listType) : ""
                    color: root.plateInkSub
                    font.family: root.t.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
            }

            // "5 ON LIST" (or the unread count, signed in) on a slanted white plate.
            Item {
                id: countTag
                visible: !!root.svc && root.svc.configured
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.top: parent.top
                anchors.topMargin: 12
                width: visible ? tagText.implicitWidth + 28 : 0
                height: 24

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: 4
                    anchors.rightMargin: 4
                    radius: 7
                    color: "#ffffff"
                    border.width: 3
                    border.color: root.t.colBorder
                    antialiasing: true
                    transform: Matrix4x4 {
                        // Lean right by 0.22 of the height, about the middle (Slant.qml's skew).
                        matrix: Qt.matrix4x4(1, -0.22, 0, 0.22 * 12, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                    }
                }
                Text {
                    id: tagText
                    anchors.centerIn: parent
                    text: root.svc && root.svc.signedIn && root.svc.unread > 0
                        ? root.svc.unread + " NEW"
                        : (root.svc ? root.svc.entries.length : 0) + " ON LIST"
                    color: Qt.darker(root.accent, root.lightPlate ? 1.9 : 1.0)
                    font.family: root.t.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.ExtraBold
                    font.styleName: root.t.fontStyleBold
                    font.letterSpacing: 0.4
                }
            }

            // The plate opens your profile.
            MouseArea {
                anchors.fill: parent
                enabled: !!root.svc && !!root.svc.user && !!root.svc.user.siteUrl
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: Qt.openUrlExternally(root.svc.user.siteUrl)
            }
        }

        // ===================================================== list page
        Column {
            id: listPage
            visible: root.shownPage === "list"
            width: col.width
            spacing: 10
            opacity: root.pageIn
            x: (1 - root.pageIn) * 18

        // ===== the heading (+ the anime / manga switch) =====
        Item {
            visible: !!root.svc && root.svc.configured
            width: col.width
            height: 26

            // A slanted tab with a diamond, like the shell's SectionTab.
            Item {
                id: tab
                anchors.verticalCenter: parent.verticalCenter
                width: tabText.implicitWidth + 40
                height: 22

                Rectangle {
                    anchors.fill: parent
                    anchors.rightMargin: 4
                    radius: 8
                    color: root.t.chipFill
                    transform: Matrix4x4 {
                        matrix: Qt.matrix4x4(1, -0.2, 0, 0.2 * 11, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                    }
                }
                Rectangle {
                    x: 11
                    anchors.verticalCenter: parent.verticalCenter
                    width: 7
                    height: 7
                    rotation: 45
                    color: root.t.dark ? root.t.accentMint : root.t.colBorder
                }
                Text {
                    id: tabText
                    x: 24
                    anchors.verticalCenter: parent.verticalCenter
                    text: (root.s.sortBy === "airing" ? "AIRING SOON" : "RECENT") + (root.kind === "MANGA" && root.both || root.s.listType === "MANGA" ? " · READING" : " · WATCHING")
                    color: root.t.chipInk
                    font.family: root.t.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.ExtraBold
                    font.styleName: root.t.fontStyleBold
                    font.letterSpacing: 0.6
                }
            }

            // Watching | Reading: a mint thumb that slides (and overshoots) under the choice.
            Item {
                id: seg
                visible: root.both
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 164
                height: 26
                readonly property real slot: (width - 6) / 2

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2.4
                    color: root.t.surfaceHover
                    border.width: root.t.borderWidth
                    border.color: root.t.line
                }
                Rectangle {
                    x: 3 + (root.kind === "MANGA" ? seg.slot : 0)
                    y: 3
                    width: seg.slot
                    height: seg.height - 6
                    radius: height / 2.4
                    color: root.t.accentMint
                    border.width: 2
                    border.color: root.t.colBorder
                    Behavior on x { NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.8 } }
                }
                Repeater {
                    model: [{ id: "ANIME", label: "Watching" }, { id: "MANGA", label: "Reading" }]
                    delegate: Item {
                        required property var modelData
                        required property int index
                        x: 3 + index * seg.slot
                        width: seg.slot
                        height: seg.height
                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            color: root.kind === modelData.id ? root.t.colBorder : root.t.inkSub
                            font.family: root.t.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.ExtraBold
                            font.styleName: root.t.fontStyleBold
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.kind = modelData.id
                        }
                    }
                }
            }

            Text {
                visible: !root.both
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                text: root.svc ? AL.countText(root.svc.entries) : ""
                color: root.t.inkSub
                font.family: root.t.fontFamily
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
        }

        // ===== the list =====
        Item {
            visible: !!root.svc && root.svc.configured && root.shownEntries.length > 0
            width: col.width
            height: root.visibleRows * root.rowH + (root.visibleRows - 1) * root.rowGap

            Flickable {
                id: list
                anchors.fill: parent
                contentWidth: width
                contentHeight: rows.height
                clip: true
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: rows
                    width: list.width
                    spacing: root.rowGap

                    Repeater {
                        model: root.shownEntries
                        delegate: EntryRow {
                            required property var modelData
                            required property int index
                            // One after another as the card opens.
                            readonly property real local: Math.max(0, Math.min(1, root.enter * 1.6 - index * 0.12))
                            width: rows.width
                            t: root.t
                            entry: modelData
                            lang: root.s.titleLanguage
                            nowSec: root.svc ? root.svc.nowSec : 0
                            canBump: !!root.svc && root.svc.signedIn
                            bumping: !!root.svc && !!root.svc.bumping[modelData.id]
                            onBumpRequested: root.svc.bump(modelData)
                            opacity: local
                            x: (1 - local) * 18
                        }
                    }
                }
            }

            // A thin scroll thumb on the right while there is more.
            Rectangle {
                visible: list.interactive
                x: parent.width - 3
                width: 3
                radius: 1.5
                color: root.t.line
                height: Math.max(24, parent.height * list.height / Math.max(1, list.contentHeight))
                y: (parent.height - height) * (list.contentY / Math.max(1, list.contentHeight - list.height))
            }
        }

        // ===== nothing to show / something wrong / not set up =====
        Rectangle {
            visible: root.configured && root.shownEntries.length === 0
            width: col.width
            height: note.implicitHeight + 28
            radius: 12
            color: root.t.surfaceHover
            border.width: root.t.borderWidth - 0.5
            border.color: root.t.line

            Column {
                id: note
                x: 14
                y: 14
                width: parent.width - 28
                spacing: 8

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: !root.svc ? "Loading…"
                        : !root.svc.configured ? "Connect your AniList"
                        : root.svc.error !== "" ? root.svc.error
                        : root.svc.loading ? "Loading your list…"
                        : "Nothing on your list right now"
                    color: root.t.ink
                    font.family: root.t.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.ExtraBold
                    font.styleName: root.t.fontStyleBold
                }
            }
        }

        // An error while there IS a list: one quiet line over it.
        Text {
            visible: !!root.svc && root.svc.error !== "" && root.shownEntries.length > 0
            width: col.width
            elide: Text.ElideRight
            text: "⚠ " + (root.svc ? root.svc.error : "")
            color: root.t.inkSub
            font.family: root.t.fontFamily
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }

        } // list page

        // ===================================================== account page
        Column {
            id: accountPage
            visible: root.shownPage === "account"
            width: col.width
            spacing: 10
            opacity: root.pageIn
            x: (1 - root.pageIn) * 18

            // Signed in: who, and sign out.
            Rectangle {
                visible: !!root.svc && root.svc.signedIn
                width: parent.width
                height: signedCol.implicitHeight + 24
                radius: 12
                color: root.t.surfaceHover
                border.width: root.t.borderWidth - 0.5
                border.color: root.t.line

                Column {
                    id: signedCol
                    x: 14
                    y: 12
                    width: parent.width - 28
                    spacing: 8
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: "Signed in" + (root.svc && root.svc.user ? " as " + root.svc.user.name : "")
                        color: root.t.ink
                        font.family: root.t.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.ExtraBold
                        font.styleName: root.t.fontStyleBold
                    }
                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: "Private lists, notifications and +1 are on. The token stays on this computer."
                        color: root.t.inkSub
                        font.family: root.t.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }
                    Key {
                        t: root.t
                        icon: "logout"
                        label: "Sign out"
                        onClicked: root.svc.signOut()
                    }
                }
            }

            // ---- a public profile
            StepTab { visible: !!root.svc && !root.svc.signedIn; text: "PUBLIC PROFILE · READ ONLY" }
            Row {
                visible: !!root.svc && !root.svc.signedIn
                width: parent.width
                spacing: 8
                Field {
                    id: userField
                    t: root.t
                    width: parent.width - useKey.width - 8
                    icon: "person"
                    placeholder: "Your AniList username"
                    text: root.s.username || ""
                    onCommitted: v => userField.error = !root.svc.useUsername(v)
                    onValueChanged: userField.error = false
                }
                Key {
                    id: useKey
                    t: root.t
                    label: "Use"
                    accent: userField.value.trim() !== "" && userField.value.trim() !== (root.s.username || "")
                    onClicked: userField.commit()
                }
            }
            Hint {
                visible: !!root.svc && !root.svc.signedIn
                text: userField.error ? "A username is letters and digits only."
                    : (root.s.username ? "Showing " + root.s.username + "'s public list." : "Your list has to be public on AniList.")
            }

            // ---- signing in
            StepTab { visible: !!root.svc && !root.svc.signedIn; text: "SIGN IN · PRIVATE LISTS AND +1" }
            Column {
                visible: !!root.svc && !root.svc.signedIn
                width: parent.width
                spacing: 8

                // 1. the API client (AniList wants one per app; made once)
                Step {
                    number: "1"
                    text: "Make an API client on AniList, once. Name it anything; set its Redirect URL to:"
                }
                Row {
                    x: 26
                    spacing: 8
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: urlText.implicitWidth + 16
                        height: 24
                        radius: 7
                        color: root.t.chipFill
                        Text {
                            id: urlText
                            anchors.centerIn: parent
                            text: root.svc ? root.svc.redirectUrl : ""
                            color: root.t.chipInk
                            font.family: root.t.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.ExtraBold
                            font.styleName: root.t.fontStyleBold
                        }
                    }
                    Key {
                        t: root.t
                        icon: "content_copy"
                        keyHeight: 24
                        radius: 8
                        onClicked: root.svc.copy(root.svc.redirectUrl)
                    }
                    Key {
                        t: root.t
                        icon: "open_in_new"
                        label: "Open"
                        keyHeight: 24
                        radius: 8
                        onClicked: Qt.openUrlExternally(AL.DEVELOPER_URL)
                    }
                }

                // 2. its ID
                Step { number: "2"; text: "Paste the client's ID here:" }
                Field {
                    id: idField
                    x: 26
                    width: parent.width - 26
                    t: root.t
                    icon: "key"
                    digitsOnly: true
                    placeholder: "Client ID (a number)"
                    text: root.s.clientId || ""
                    onCommitted: v => idField.error = !root.svc.useClientId(v)
                    onValueChanged: idField.error = false
                }

                // 3. go
                Step { number: "3"; text: "Approve SekaiPop in the browser. That's it." }
                Row {
                    x: 26
                    spacing: 8
                    Key {
                        t: root.t
                        icon: "login"
                        label: root.svc && root.svc.authState === "waiting" ? "Waiting for AniList…" : "Sign in with AniList"
                        accent: true
                        busy: !!root.svc && root.svc.authState !== ""
                        enabled: AL.cleanClientId(idField.value) !== ""
                        onClicked: {
                            if (idField.value.trim() !== (root.s.clientId || ""))
                                root.svc.useClientId(idField.value)
                            root.svc.startSignIn()
                        }
                    }
                    Key {
                        visible: !!root.svc && root.svc.authState === "waiting"
                        t: root.t
                        label: "Cancel"
                        onClicked: root.svc.cancelSignIn()
                    }
                }
            }
            Hint {
                visible: !!root.svc && root.svc.signInNote !== ""
                text: root.svc ? root.svc.signInNote : ""
                strong: true
            }
            // The other way: a token copied from AniList (a client whose redirect URL is the pin page).
            Text {
                visible: !!root.svc && !root.svc.signedIn
                text: "Have a token already? Copy it, then <u>paste it here</u>."
                textFormat: Text.StyledText
                color: pasteArea.containsMouse ? root.t.ink : root.t.inkSub
                font.family: root.t.fontFamily
                font.pixelSize: 10
                font.weight: Font.DemiBold
                MouseArea {
                    id: pasteArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.svc.pasteToken()
                }
            }
        }

        // ===================================================== settings page
        Column {
            id: settingsPage
            visible: root.shownPage === "settings"
            width: col.width
            spacing: 9
            opacity: root.pageIn
            x: (1 - root.pageIn) * 18

            StepTab { text: "SETTINGS" }
            Repeater {
                model: root.settingsRows
                delegate: ChoiceRow {
                    required property var modelData
                    required property int index
                    readonly property real local: Math.max(0, Math.min(1, root.enter * 1.6 - index * 0.08))
                    width: settingsPage.width
                    t: root.t
                    label: modelData.label
                    options: modelData.options
                    current: root.s[modelData.key]
                    onPicked: v => root.svc.setSetting(modelData.key, v)
                    opacity: local
                }
            }
            Hint { text: "Saved as you pick. The same settings are in Settings › Desktop › Plugins › AniList." }
        }

        // ===== keys =====
        Item {
            width: col.width
            height: keys.height

            Row {
                id: keys
                spacing: 8

                // list page
                Key {
                    visible: root.shownPage === "list"
                    t: root.t
                    icon: "refresh"
                    label: "Refresh"
                    busy: !!root.svc && root.svc.loading
                    onClicked: root.svc.refresh()
                }
                Key {
                    visible: root.shownPage === "list"
                    t: root.t
                    icon: "tune"
                    onClicked: root.go("settings")
                }
                Key {
                    visible: root.shownPage === "list"
                    t: root.t
                    icon: root.svc && root.svc.signedIn ? "account_circle" : "login"
                    label: root.svc && root.svc.signedIn ? "" : "Sign in"
                    onClicked: root.go("account")
                }
                Key {
                    visible: root.shownPage === "list"
                    t: root.t
                    icon: "open_in_new"
                    label: "AniList"
                    onClicked: {
                        const u = root.svc.user && root.svc.user.siteUrl ? root.svc.user.siteUrl : "https://anilist.co"
                        Qt.openUrlExternally(u)
                        root.host.popup.close()
                    }
                }

                // account / settings pages
                Key {
                    visible: root.shownPage !== "list" && root.configured
                    t: root.t
                    icon: "arrow_back"
                    label: "Back"
                    onClicked: root.go("list")
                }
                Key {
                    visible: root.shownPage === "account" && !root.configured
                    t: root.t
                    icon: "tune"
                    label: "Settings"
                    onClicked: root.go("settings")
                }
                Key {
                    visible: root.shownPage === "settings" && !root.configured
                    t: root.t
                    icon: "login"
                    label: "Connect"
                    onClicked: root.go("account")
                }
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: keys.verticalCenter
                anchors.verticalCenterOffset: -2
                visible: root.shownPage === "list"
                text: root.svc && root.svc.updatedAt > 0 ? AL.ago((root.svc.now - root.svc.updatedAt) / 1000) : ""
                color: root.t.inkSub
                font.family: root.t.fontFamily
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }
        }
    }
}
