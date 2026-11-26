import QtQuick
import QtTest
import "../../modules/common/functions/PluginManifest.js" as PM
import "../../modules/common/functions/PluginForm.js" as PF

// Every bundled widget plugin (plugins/*) through the shell's own manifest rules and Settings form:
// it loads, with the files it has, and nothing it says about its settings is dropped (a field the
// shell doesn't take for that setting's type is silently left out, so a test has to look).
//   QML_XHR_ALLOW_FILE_READ=1 qmltestrunner -platform offscreen -input tests/plugin-widgets-test/tst_manifests.qml
TestCase {
    name: "BundledManifests"

    readonly property string root: Qt.resolvedUrl("../../../plugins/").toString()
    readonly property var ids: ["countdowns", "gif-frame", "ping-board", "cover-wall", "market-ticker", "rain-radar", "desk-pet"]

    function read(url) {
        const x = new XMLHttpRequest()
        x.open("GET", url, false)
        x.send()
        return x.responseText
    }

    function exists(url) {
        const x = new XMLHttpRequest()
        x.open("GET", url, false)
        x.send()
        return x.status === 200 || (x.status === 0 && x.responseText !== "")
    }

    function test_each_loads_and_keeps_its_settings_info_data() {
        return ids.map(id => ({ tag: id, id: id }))
    }

    function test_each_loads_and_keeps_its_settings_info(data) {
        const dir = root + data.id + "/"
        const text = read(dir + "plugin.json")
        verify(text !== "", "plugin.json is there")
        const files = ["Widget.qml", "Bar.qml", "Popup.qml", "Service.qml"].filter(f => exists(dir + f)).join(" ")
        const r = PM.parse(text, data.id, files)
        verify(r.ok, r.error || "")
        const raw = JSON.parse(text)
        compare(r.plugin.files.service, exists(dir + "Service.qml"))
        verify(r.plugin.files.widget)

        const info = raw.settingsInfo || {}
        for (const k in info) {
            const kept = r.plugin.settingsInfo[k]
            verify(kept !== undefined, k + ": settingsInfo for a declared setting")
            for (const f of ["label", "description", "group", "unit", "multiline", "min", "max", "step"])
                if (info[k][f] !== undefined)
                    verify(kept[f] !== undefined, k + "." + f + " was dropped by the shell (wrong for a " + typeof raw.settings[k] + ")")
            if (info[k].choices) {
                verify(kept.choices !== undefined, k + ".choices was dropped (choices are for text settings)")
                verify(kept.choices.some(c => c.value === raw.settings[k]), k + ": its default is one of its choices")
            }
        }
        // the form Settings draws: every setting has a row and no default is shown as "outside"
        const form = PF.form(r.plugin, r.plugin.settings)
        let rows = 0
        for (const g of form)
            for (const row of g.rows) {
                rows++
                verify(!row.outside, data.id + "." + row.key + ": the default is outside its own range or choices")
            }
        compare(rows, Object.keys(raw.settings || {}).length)
    }
}
