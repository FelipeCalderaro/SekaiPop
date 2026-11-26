import QtQuick
import "AniList.js" as AL

// The AniList entry in the bar (docs/PLUGINS.md, "A bar entry"). The shell draws the pill and
// opens the popup on a left click; this draws what is inside, from the shared service:
//   airing    the next episode to air:          [clock] Ep 8 · 2d 4h
//   progress  what you touched last:            [play]  Frieren  7/28
//   count     how many you are on:              [tv]    5
//   unread    notifications (signed in):        [bell]  3
// (Settings: "Bar shows".) A standing bar puts the icon over a few characters.
//
// Middle click opens your AniList profile, right click asks AniList again.
Item {
    id: root

    required property var host

    readonly property var svc: root.host.service
    readonly property var face: root.svc ? root.svc.face : ({ icon: "live_tv", text: "AniList", short: "AL", tip: "" })

    property string tip: root.face.tip + (root.svc && root.svc.configured
        ? "\nMiddle-click: open AniList · right-click: refresh" : "")
    // Nothing on the list and "Hide when empty" on: no pill at all.
    property bool present: !(root.host.settings.hideWhenEmpty && root.svc && root.svc.configured
        && root.svc.updatedAt > 0 && root.svc.entries.length === 0)

    // A badge in the pill's corner: episodes out you have not watched yet.
    readonly property int behindCount: {
        if (!root.svc)
            return 0
        return root.svc.entries.reduce((n, e) => n + AL.behind(e), 0)
    }

    implicitWidth: root.host.bar.vertical ? col.implicitWidth : row.implicitWidth
    implicitHeight: root.host.bar.vertical ? col.implicitHeight : row.implicitHeight

    // A little spin of the icon while a refresh is out.
    readonly property bool spinning: !!root.svc && root.svc.loading

    Row {
        id: row
        visible: !root.host.bar.vertical
        spacing: 6

        Text {
            id: glyph
            anchors.verticalCenter: parent.verticalCenter
            text: root.face.icon
            color: root.host.bar.ink
            font.family: root.host.theme.iconFont
            font.pixelSize: root.host.bar.capsule ? 16 : 19
            RotationAnimator on rotation {
                running: root.spinning
                from: 0
                to: 360
                duration: 900
                loops: Animation.Infinite
                onRunningChanged: if (!running) glyph.rotation = 0
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.face.text
            color: root.host.bar.ink
            font.family: root.host.theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.ExtraBold
            font.styleName: root.host.theme.fontStyleBold
        }

        // "+2": aired, not watched. Amber: wants a look, is not an error (theme.warnFill).
        Rectangle {
            visible: root.behindCount > 0 && !root.host.bar.capsule
            anchors.verticalCenter: parent.verticalCenter
            width: behindText.implicitWidth + 10
            height: 16
            radius: 8
            color: root.host.theme.warnFill
            border.width: 1.5
            border.color: root.host.theme.colBorder

            Text {
                id: behindText
                anchors.centerIn: parent
                text: "+" + root.behindCount
                color: root.host.theme.colBorder
                font.family: root.host.theme.fontFamily
                font.pixelSize: 10
                font.weight: Font.ExtraBold
                font.styleName: root.host.theme.fontStyleBold
            }
        }
    }

    Column {
        id: col
        visible: root.host.bar.vertical
        spacing: 1

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.face.icon
            color: root.host.bar.ink
            font.family: root.host.theme.iconFont
            font.pixelSize: 19
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.face.short
            color: root.host.bar.ink
            font.family: root.host.theme.fontFamily
            font.pixelSize: 11
            font.weight: Font.ExtraBold
            font.styleName: root.host.theme.fontStyleBold
        }
    }

    // The left button is the shell's (the popup); these two are ours.
    MouseArea {
        anchors.fill: parent
        anchors.margins: -8
        acceptedButtons: Qt.MiddleButton | Qt.RightButton
        onClicked: mouse => {
            if (!root.svc)
                return
            if (mouse.button === Qt.RightButton)
                root.svc.refresh()
            else if (root.svc.user && root.svc.user.siteUrl)
                Qt.openUrlExternally(root.svc.user.siteUrl)
        }
    }
}
