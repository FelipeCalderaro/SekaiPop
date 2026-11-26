import QtQuick

// One setting on the popup's Settings page: its name on the left, its choices as small keys on
// the right, the chosen one lit in the accent (the way the shell's Settings chips light up).
//
//   ChoiceRow { t: host.theme; label: "Lists"; current: settings.listType
//               options: [{ value: "ANIME", label: "Anime" }, ...]; onPicked: v => ... }
Item {
    id: row

    required property var t
    property string label: ""
    property var current
    property var options: []      // [{ value, label }]
    property real labelWidth: 80

    signal picked(var value)

    implicitHeight: Math.max(name.implicitHeight, chips.implicitHeight)

    Text {
        id: name
        width: row.labelWidth
        anchors.top: parent.top
        anchors.topMargin: 6
        text: row.label
        elide: Text.ElideRight
        color: row.t.inkSub
        font.family: row.t.fontFamily
        font.pixelSize: 11
        font.weight: Font.ExtraBold
        font.styleName: row.t.fontStyleBold
    }

    Flow {
        id: chips
        x: row.labelWidth
        width: row.width - row.labelWidth
        spacing: 5

        Repeater {
            model: row.options
            delegate: Key {
                required property var modelData
                t: row.t
                label: modelData.label
                keyHeight: 24
                padding: 16
                radius: 8
                accent: row.current === modelData.value
                onClicked: if (row.current !== modelData.value) row.picked(modelData.value)
            }
        }
    }
}
