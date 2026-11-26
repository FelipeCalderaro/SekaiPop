// node tests/bar-wrap-test/bar_wrap_unit.js   (run from the sekaipop folder)
// Per-monitor bar control (hide, own edge, wrap on a narrow screen). Quickshell can't be run
// here, so the arithmetic (BarWrap.js) is run in node and the wiring is read off the source.
const assert = require("assert"), fs = require("fs"), path = require("path")
const locate = require("../lib/locate")
const read = rel => fs.readFileSync(locate(rel), "utf8")
const code = s => s.replace(/\/\*[\s\S]*?\*\//g, "").replace(/(^|[^:"'])\/\/.*$/gm, "$1")
const balanced = (f, s) => { for (const [a, b] of [["{", "}"], ["(", ")"], ["[", "]"]])
    assert.strictEqual(s.split(a).length, s.split(b).length, f + ": " + a + b + " unbalanced") }

const src = read("modules/sekai/bar/BarWrap.js").replace(".pragma library", "")
const W = new Function(src + ";return { rowsFor, rowOf, rowCenter, settle, alone, ZONE_GAP }")()

// ===== rows =====
// a 1920 bar with a typical layout fits on one row
assert.strictEqual(W.rowsFor(450, 420, 400, 1888), 1)
// a portrait 1080 bar: the centre zone goes under the sides
assert.strictEqual(W.rowsFor(450, 420, 400, 1048), 2)
// so narrow that even the sides don't share a row: one zone per row
assert.strictEqual(W.rowsFor(450, 420, 400, 800), 3)
// the wider side decides one row (the centre is dead centre), not the plain sum
assert.strictEqual(W.rowsFor(700, 300, 100, 1200), 2, "700+300+100 < 1200 but the centre would hit the left zone")
// no centre zone: left, then right under it
assert.strictEqual(W.rowsFor(600, 0, 600, 1300), 1)
assert.strictEqual(W.rowsFor(600, 0, 600, 1000), 2)
assert.strictEqual(W.rowOf("left", 2, false), 0)
assert.strictEqual(W.rowOf("right", 2, false), 1)
// with a centre zone
assert.strictEqual(W.rowOf("left", 2, true), 0)
assert.strictEqual(W.rowOf("right", 2, true), 0)
assert.strictEqual(W.rowOf("center", 2, true), 1)
assert.deepStrictEqual(["left", "center", "right"].map(z => W.rowOf(z, 3, true)), [0, 1, 2])
assert.deepStrictEqual(["left", "center", "right"].map(z => W.rowOf(z, 1, true)), [0, 0, 0])

// ===== alignment: a zone alone on its row is centred (no staircase) =====
assert.deepStrictEqual(["left", "center", "right"].map(z => W.alone(z, 1, true)), [false, false, false])
assert.deepStrictEqual(["left", "center", "right"].map(z => W.alone(z, 2, true)), [false, true, false], "left + right share row 0")
assert.deepStrictEqual(["left", "right"].map(z => W.alone(z, 2, false)), [true, true])
assert.deepStrictEqual(["left", "center", "right"].map(z => W.alone(z, 3, true)), [true, true, true])

// ===== row centres =====
// one row: the middle of the box, as the bar always was
assert.strictEqual(W.rowCenter(61, 1, 48, 0), 30.5)
// two rows 48 apart in a 109 box: centred as a block
assert.strictEqual(W.rowCenter(109, 2, 48, 0), 30.5)
assert.strictEqual(W.rowCenter(109, 2, 48, 1), 78.5)

// ===== hysteresis =====
assert.strictEqual(W.settle(1, 2, 2), 2, "grows at once")
assert.strictEqual(W.settle(2, 1, 2), 2, "fits only without slack: stays")
assert.strictEqual(W.settle(2, 1, 1), 1, "fits with slack: shrinks")
assert.strictEqual(W.settle(3, 1, 2), 2, "shrinks only as far as the slack allows")

// ===== wiring =====
const files = {
    sb: "modules/sekai/bar/Status_Bar.qml",
    bar: "modules/sekai/bar/Bar.qml",
    pos: "services/BarPositionService.qml",
    shell: "shell.qml",
    page: "modules/sekai/settings/SettingsPageBar.qml",
    set: "services/SettingsService.qml",
    pre: "services/DesktopPresetService.qml"
}
const c = {}
for (const k in files) {
    c[k] = code(read(files[k]))
    balanced(files[k], c[k])
}

// Status_Bar: the zones sit on their rows, and the math is BarWrap's
assert(/import "BarWrap\.js" as BarWrap/.test(c.sb))
for (const z of ["left", "center", "right"])
    assert(c.sb.includes('status_Bar.rowCenter(status_Bar.rowOf("' + z + '"))'), z + " zone not on its row")
assert(!/id: centerGroup\s+anchors\.centerIn/.test(c.sb), "centre zone still centred in the whole bar")
assert(/anchors\.left: status_Bar\.vertical \|\| status_Bar\.aloneOnRow\("left"\) \? undefined : parent\.left/.test(c.sb), "left zone not centred when alone")
assert(/anchors\.right: status_Bar\.vertical \|\| status_Bar\.aloneOnRow\("right"\) \? undefined : parent\.right/.test(c.sb), "right zone not centred when alone")
assert(/property bool wrapAllowed: true/.test(c.sb))
assert(/readonly property real extraThickness: \(status_Bar\.rows - 1\) \* status_Bar\.rowStep/.test(c.sb))
// the fit is measured without the media pill's live width (it depends on the rows)
assert(/id === "media"\)\s+iw = Math\.min\(status_Bar\.mediaNeed/.test(c.sb))

// Bar.qml: the window and the status bar grow by the extra rows, and it is reported
assert(/\+ win\.extraThickness\) \* win\.uiScale/.test(c.bar), "strip ignores extra rows")
assert(/mt\.capBarHeight : 61\) \+ win\.extraThickness/.test(c.bar), "status bar height ignores extra rows")
assert(/wrapAllowed: win\.wrapAllowed/.test(c.bar))
assert(/BarPositionService\.reportExtra\(win\.screenName, win\.barPosition, win\.extraThickness\)/.test(c.bar))

// the service: per-monitor choices, and its ipc
for (const f of ["prefsFor", "positionFor", "hiddenOn", "wrapFor", "setScreenPref", "thicknessOn", "reservedOn", "reportExtra"])
    assert(new RegExp("function " + f + "\\(").test(c.pos), "BarPositionService." + f)
for (const f of ["setscreen", "hidescreen", "wrapscreen", "getscreen"])
    assert(new RegExp("function " + f + "\\(").test(c.pos), "ipc barposition " + f)

// shell.qml: a hidden monitor gets no bar, each gets its own edge, and the dock finds its
// monitor's bar by screen rather than by position in the list
assert(/!BarPositionService\.hiddenOn\(s\.name\)/.test(c.shell))
assert(/position: BarPositionService\.positionFor\(s\.name\)/.test(c.shell))
assert(/bars\.instances\.find\(b => b\.screen === Quickshell\.screens\[i\]\)/.test(c.shell))
assert(!/bars\.instances\[i\]/.test(c.shell), "dock still pairs bars by index")

// the setting exists, and presets never carry it (output names are this machine's)
assert(/"bar\.screens": "\{\}"/.test(c.set))
assert(/"bar\.screens"/.test(c.pre))

// Settings: the This monitor card
assert(/BarPositionService\.setScreenPref\(page\.screenName, "hidden"/.test(c.page))
assert(/BarPositionService\.setScreenPref\(page\.screenName, "position"/.test(c.page))
assert(/BarPositionService\.setScreenPref\(page\.screenName, "wrap"/.test(c.page))

// nothing that offsets itself from the bar still reads the shell-wide edge's thickness
const offsetters = ["modules/sekai/notificationPopup/NotificationPopup.qml", "modules/sekai/onScreenDisplay/OSDPopup.qml",
    "modules/sekai/onScreenDisplay/RecordingIndicator.qml", "modules/sekai/regionSelector/RegionPreview.qml",
    "ReloadPopup.qml", "modules/sekai/keyboard/OnScreenKeyboard.qml", "modules/sekai/dock/Dock.qml"]
for (const f of offsetters) {
    const s = code(read(f))
    assert(!/BarPositionService\.(thickness|reserved)\b/.test(s), f + " reads the shell-wide bar thickness")
}

console.log("bar wrap / per-monitor bar: ok")
