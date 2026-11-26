import QtQuick

// Loads a fixture's `.pragma library` file by URL for render.qml: QML can only import a JS
// file by a fixed path, so this writes a one-line component that imports it and hands it back.
QtObject {
    id: root
    property url source
    readonly property var lib: {
        const qml = 'import QtQuick; import "' + root.source + '" as F; QtObject { readonly property var f: F }'
        const o = Qt.createQmlObject(qml, root, "fixture")
        return o.f
    }
}
