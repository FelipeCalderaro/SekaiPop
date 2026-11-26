import QtQuick

// A text field on the shell's block (docs/DESIGN-SYSTEM.md): an inset well (surfaceHover fill,
// outline) that takes a mint ring while you type. Enter (or leaving the field) commits;
// Escape gives the keyboard back. `error` shakes it and turns the outline amber.
//
//   Field { t: host.theme; placeholder: "AniList username"; text: settings.username
//           onCommitted: v => ok = svc.useUsername(v) }
Item {
    id: field

    required property var t
    property string text: ""
    property string placeholder: ""
    property string icon: ""
    property bool digitsOnly: false
    property bool error: false

    signal committed(string value)

    // The typed text; follows `text` until the field is edited.
    property alias value: input.text
    readonly property bool editing: input.activeFocus

    implicitHeight: 34
    implicitWidth: 200

    onTextChanged: if (!input.activeFocus) input.text = field.text
    Component.onCompleted: input.text = field.text

    function commit() {
        field.committed(input.text.trim())
    }

    // A small side-to-side shake when the value was refused.
    onErrorChanged: if (field.error) shake.restart()
    SequentialAnimation {
        id: shake
        NumberAnimation { target: well; property: "x"; to: -5; duration: 45 }
        NumberAnimation { target: well; property: "x"; to: 4; duration: 60 }
        NumberAnimation { target: well; property: "x"; to: -2; duration: 60 }
        NumberAnimation { target: well; property: "x"; to: 0; duration: 80; easing.type: Easing.OutBack }
    }

    Rectangle {
        id: well
        width: field.width
        height: field.height
        radius: 10
        color: field.t.surfaceHover
        border.width: field.t.borderWidth
        border.color: field.error ? field.t.warnFill : (input.activeFocus ? field.t.colBorder : field.t.line)
        antialiasing: true
        Behavior on border.color { ColorAnimation { duration: 120 } }

        // The mint ring while typing (inside the outline, so nothing moves).
        Rectangle {
            anchors.fill: parent
            anchors.margins: field.t.borderWidth
            radius: 7
            color: "transparent"
            border.width: 2
            border.color: field.t.accentMint
            opacity: input.activeFocus ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }

        Text {
            id: glyph
            visible: field.icon !== ""
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            text: field.icon
            color: field.t.inkSub
            font.family: field.t.iconFont
            font.pixelSize: 16
        }

        TextInput {
            id: input
            anchors.left: glyph.visible ? glyph.right : parent.left
            anchors.leftMargin: glyph.visible ? 6 : 12
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            clip: true
            color: field.t.ink
            selectionColor: field.t.accentMint
            selectedTextColor: field.t.colBorder
            selectByMouse: true
            font.family: field.t.fontFamily
            font.pixelSize: 13
            font.weight: Font.Bold
            inputMethodHints: field.digitsOnly ? Qt.ImhDigitsOnly : Qt.ImhNoPredictiveText
            validator: RegularExpressionValidator {
                regularExpression: field.digitsOnly ? /\d{0,10}/ : /.{0,200}/
            }
            onAccepted: {
                field.commit()
                input.focus = false
            }
            onActiveFocusChanged: if (!activeFocus && input.text.trim() !== field.text) field.commit()
            Keys.onEscapePressed: event => {
                input.text = field.text
                input.focus = false
                event.accepted = true
            }

            Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                visible: input.text === "" && !input.activeFocus
                text: field.placeholder
                color: field.t.inkSub
                font: input.font
                elide: Text.ElideRight
            }
        }
    }
}
