import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import "../../common/functions/IdleSteps.js" as IS

// The card that drops over the phone's screen from the Idle & Sleep tile: the same times as
// Settings > General > Idle & sleep, without leaving the Quick Panel.
//
//   Lock after         idle.lock        (minutes, Never = 0)
//   Screen off after   idle.screenOff
//   Sleep after        idle.sleep       and Sleep by: Suspend / Hibernate (idle.sleepAction)
//
// The - / + keys step through round values (IdleSteps.js). When hypridle isn't using these
// times yet (your own hypridle.conf), it says so in amber, with where to switch it over.
// Pure UI, like NightLightDialog.qml: QuickPanelFace.qml feeds it, its signal becomes
// SettingsService.set() in QuickPanel.qml.
Item {
    id: root

    readonly property var mt: Theme.of(QsWindow.window)

    property bool open: false
    property int lock: 5
    property int screenOff: 10
    property int sleep: 15
    property string sleepAction: "suspend"
    property bool linked: true            // hypridle reads these times (IdleService.linked === "yes")
    property bool canHibernate: true

    signal closeRequested()
    signal settingRequested(string key, var value)

    readonly property string note: !root.linked
        ? "These times aren't used yet: your hypridle.conf has its own. Settings > General > Idle & sleep > Use these times."
        : IS.orderNote(root.lock, root.screenOff, root.sleep, root.sleepAction)

    anchors.fill: parent
    visible: opacity > 0
    opacity: root.open ? 1 : 0
    Behavior on opacity {
        NumberAnimation { duration: root.open ? 140 : 220 }
    }

    // A round - / + key of a row (the same look as Night Light's hour steppers); dimmed at an end.
    component StepKey: Item {
        id: stepKey
        required property var row
        required property int dir
        readonly property bool atEnd: IS.step(stepKey.row.steps, stepKey.row.value, stepKey.dir) === stepKey.row.value
        width: 40
        height: 40
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        Rectangle {
            anchors.fill: parent
            radius: 20
            color: keyArea.containsMouse && !stepKey.atEnd ? mt.pSurfaceHover : "transparent"
            border.width: 2
            border.color: mt.pLine
            opacity: stepKey.atEnd ? 0.45 : 1
            antialiasing: true
            MaterialIcon {
                anchors.centerIn: parent
                name: stepKey.dir < 0 ? "remove" : "add"
                size: 22
                color: mt.pInk
            }
        }
        MouseArea {
            id: keyArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: !stepKey.atEnd
            cursorShape: Qt.PointingHandCursor
            onClicked: root.settingRequested(stepKey.row.modelData.key, IS.step(stepKey.row.steps, stepKey.row.value, stepKey.dir))
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: mt.phoneScreenInset
        radius: mt.phoneCornerRadius - mt.phoneScreenInset
        color: mt.scrim
        opacity: root.open ? 0.55 : 0
        antialiasing: true
        Behavior on opacity {
            NumberAnimation { duration: 220 }
        }
        MouseArea {
            anchors.fill: parent
            onClicked: root.closeRequested()
        }
    }

    // the hard shadow
    Rectangle {
        x: 40 + (mt.quickFlat ? 0 : 5)
        y: 200 + 4
        width: 575
        height: card.height
        radius: 41
        color: mt.pLineShadow
        antialiasing: true
    }

    Rectangle {
        id: card
        x: 40
        y: 200
        width: 575
        height: body.y + body.height + 28
        radius: 41
        color: mt.pSurface
        border.width: 3
        border.color: mt.pLine
        clip: true
        antialiasing: true

        MouseArea { anchors.fill: parent }

        Text {
            x: 28
            y: 26
            text: "Idle & Sleep"
            color: mt.pInk
            font.family: mt.fontFamily
            font.pixelSize: 26
            font.weight: Font.ExtraBold
            font.styleName: mt.fontStyleBold
        }

        Text {
            x: 28
            y: 66
            width: card.width - 56
            wrapMode: Text.WordWrap
            text: "After how long without input. Keep Awake, and a video playing, hold all three off."
            color: mt.pInkSub
            font.family: mt.fontFamily
            font.pixelSize: 13
        }

        Column {
            id: body
            x: 28
            y: 108
            width: card.width - 56
            spacing: 12

            Repeater {
                model: [
                    { key: "idle.lock", icon: "lock_clock", label: "Lock after" },
                    { key: "idle.screenOff", icon: "desktop_access_disabled", label: "Screen off after" },
                    { key: "idle.sleep", icon: "bedtime", label: root.sleepAction === "hibernate" ? "Hibernate after" : "Sleep after" }
                ]

                delegate: Item {
                    id: row
                    required property var modelData
                    readonly property int value: modelData.key === "idle.lock" ? root.lock
                        : modelData.key === "idle.screenOff" ? root.screenOff : root.sleep
                    readonly property var steps: IS.stepsFor(modelData.key)

                    width: body.width
                    height: 48

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: row.modelData.icon
                        size: 24
                        color: mt.pInk
                    }
                    Text {
                        x: 36
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.label
                        color: mt.pInk
                        font.family: mt.fontFamily
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12
                        StepKey { row: row; dir: -1 }
                        Text {
                            width: 104
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignHCenter
                            text: IS.label(row.value)
                            color: mt.pInk
                            font.family: mt.fontFamily
                            font.pixelSize: 17
                            font.weight: Font.ExtraBold
                            font.styleName: mt.fontStyleBold
                        }
                        StepKey { row: row; dir: 1 }
                    }
                }
            }

            Rectangle {
                width: body.width
                height: 2
                color: mt.pSurfaceDivider
            }

            // Sleep by: two pills, the chosen one lit ("on" = the accent gradient)
            Item {
                width: body.width
                height: 40
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Sleep by"
                    color: mt.pInk
                    font.family: mt.fontFamily
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    Repeater {
                        model: [
                            { id: "suspend", label: "Suspend" },
                            { id: "hibernate", label: "Hibernate" }
                        ]
                        delegate: Rectangle {
                            id: pick
                            required property var modelData
                            readonly property bool on: root.sleepAction === modelData.id
                            width: pickLabel.implicitWidth + 32
                            height: 36
                            radius: 18
                            border.width: 2
                            border.color: mt.pLine
                            antialiasing: true
                            color: pickArea.containsMouse && !pick.on ? mt.pSurfaceHover : mt.pSurface
                            gradient: pick.on ? onGrad : null
                            Gradient {
                                id: onGrad
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: mt.accentMint }
                                GradientStop { position: 1.0; color: mt.accentCyan }
                            }
                            Text {
                                id: pickLabel
                                anchors.centerIn: parent
                                text: pick.modelData.label
                                color: pick.on ? mt.colBorder : mt.pInk
                                font.family: mt.fontFamily
                                font.pixelSize: 14
                                font.weight: Font.ExtraBold
                                font.styleName: mt.fontStyleBold
                            }
                            MouseArea {
                                id: pickArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.settingRequested("idle.sleepAction", pick.modelData.id)
                            }
                        }
                    }
                }
            }

            Text {
                visible: root.sleepAction === "hibernate" && !root.canHibernate
                width: body.width
                wrapMode: Text.WordWrap
                text: "This machine can't hibernate as it is set up (it needs a swap as big as your memory): Hibernate would do nothing."
                color: mt.pInkSub
                font.family: mt.fontFamily
                font.pixelSize: 12
            }

            // what wants a look, in amber with dark ink (docs/DESIGN-SYSTEM.md: amber is "look", not an error)
            Rectangle {
                visible: root.note !== ""
                width: body.width
                height: noteText.implicitHeight + 20
                radius: 14
                color: mt.warnFill
                border.width: 2
                border.color: mt.colBorder
                antialiasing: true
                Text {
                    id: noteText
                    anchors.fill: parent
                    anchors.margins: 10
                    anchors.leftMargin: 14
                    wrapMode: Text.WordWrap
                    verticalAlignment: Text.AlignVCenter
                    text: root.note
                    color: mt.colBorder
                    font.family: mt.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
            }
        }
    }
}
