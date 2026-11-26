import QtQuick
import QtTest
import "../sekaipop/Palette.js" as P

// /usr/lib/qt6/bin/qmltestrunner -platform offscreen -input sddm/tests/tst_palette.qml   (from sekaipop/)
TestCase {
    name: "SddmPalette"

    function near(a, b) { return Math.abs(a - b) < 0.02 }

    function test_defaults_when_nothing_is_written() {
        const p = P.raw({})
        compare(p.border, "#555473")
        compare(p.lockMint, "#7fe8d8", "Virtual Singer's own mint")
        verify(!p.mono)
    }

    function test_values_are_checked() {
        const p = P.raw({ border: "#561938", A: "red", lockMint: "#zzzzzz", mono: "yes" })
        compare(p.border, "#561938")
        compare(p.A, "#04feee", "not a colour: the default")
        compare(p.lockMint, undefined, "a palette was given without a mint: worked out, not Virtual Singer's")
        verify(!p.mono)
    }

    function test_same_formulas_as_the_lockscreen() {
        const vs = P.colours(P.raw({}))
        verify(Qt.colorEqual(vs.mint, "#7fe8d8"))
        verify(Qt.colorEqual(vs.well, Qt.darker("#555473", 1.35)), "the dark well inside a pill")
        verify(near(vs.panel.a, 0.85), "the side panel at 85%")
        verify(near(vs.scrimBottom.a, 0.6))
        // a theme without its own mint: from accent B, as LockPalette does
        const vbs = P.colours(P.raw({ border: "#561938", A: "#ff5c9a", B: "#ff96c0", deep: "#43142c", rimHi: "#d777a8", glint: "#ffa5c7", wallMid: "#c53c82" }))
        verify(near(vbs.mint.hslHue, Qt.color("#ff96c0").hslHue), "mint takes B's hue")
        verify(near(vbs.mint.hslLightness, 0.72))
        verify(near(vbs.pink.hslHue, Qt.color("#ff5c9a").hslHue), "pink takes A's hue")
    }

    function test_monochrome_has_no_hue() {
        const m = P.colours(P.raw({ border: "#444444", A: "#f4f4f4", B: "#bdbdbd", glint: "#d0d0d0", mono: "true" }))
        verify(near(m.band.hslSaturation, 0), "no colour cast")
        verify(near(m.mintDeep.hslSaturation, 0))
        compare(P.dotColour(m, 0), "#d9d9d9", "grey dots")
    }

    function test_dots_and_words() {
        const c = P.colours(P.raw({}))
        compare(P.dotColour(c, 0), "#8EE3EF")
        compare(P.dotColour(c, 6), "#FF9ECB", "the five colours go round")
        compare(P.failureWords(false), "Wrong password")
        compare(P.failureWords(true), "Wrong password · Caps Lock is on")
    }
}
