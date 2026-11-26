.pragma library

// A stand-in for the shell's ThemeSet (modules/common/ThemeSet.qml), for drawing a plugin's widget
// outside the shell (render.qml). Only the names a plugin is promised (docs/PLUGINS.md) and the
// ones the shell's own formulas build them from, with the same formulas, so a render looks like
// the real thing in each mode: "light", "dark" (the classic white cards) and "darker".

var PALETTES = {
    vs:        { border: "#555473", A: "#04feee", B: "#00ffcb", deep: "#232235", divider: "#e4e4ec" },
    leoneed:   { border: "#2d3775", A: "#8ea3ff", B: "#9fd8ff", deep: "#181e3f", divider: "#dee1f2" },
    mmj:       { border: "#39662d", A: "#a4ee55", B: "#7fe9a8", deep: "#223c1b", divider: "#e3f1df" },
    vbs:       { border: "#561938", A: "#ff5c9a", B: "#ff96c0", deep: "#43142c", divider: "#f5dbe8" },
    wxs:       { border: "#6a3c11", A: "#ffa51f", B: "#ffd54a", deep: "#4b2a0c", divider: "#f9e7d7" },
    nightcord: { border: "#43285f", A: "#c08cf2", B: "#e2b5ff", deep: "#2b1a3d", divider: "#e8dff1" },
    mono:      { border: "#444444", A: "#f4f4f4", B: "#bdbdbd", deep: "#1a1a1a", divider: "#ececec" }
}

function rgb(h) { h = String(h).replace("#", ""); return [0, 2, 4].map(function (i) { return parseInt(h.substr(i, 2), 16) / 255 }) }
function hex(c) { return "#" + c.map(function (v) { var x = Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16); return x.length < 2 ? "0" + x : x }).join("") }
// Qt.tint(base, Qt.rgba(tint, a)) == mix(base, tint, a)
function mix(a, b, t) { var x = rgb(a), y = rgb(b); return hex([0, 1, 2].map(function (i) { return x[i] * (1 - t) + y[i] * t })) }
function hsv(c) {
    var r = c[0], g = c[1], b = c[2], mx = Math.max(r, g, b), mn = Math.min(r, g, b), d = mx - mn, h = 0
    if (d) h = mx === r ? ((g - b) / d) % 6 : mx === g ? (b - r) / d + 2 : (r - g) / d + 4
    return [(h * 60 + 360) % 360, mx ? d / mx : 0, mx]
}
function fromHsv(h, s, v) {
    var c = v * s, x = c * (1 - Math.abs((h / 60) % 2 - 1)), m = v - c, r = 0, g = 0, b = 0
    if (h < 60) { r = c; g = x } else if (h < 120) { r = x; g = c } else if (h < 180) { g = c; b = x }
    else if (h < 240) { g = x; b = c } else if (h < 300) { r = x; b = c } else { r = c; b = x }
    return hex([r + m, g + m, b + m])
}
function lighter(h, f) { var q = hsv(rgb(h)), v = q[2] * f, s = q[1]; if (v > 1) { s = Math.max(0, s - (v - 1)); v = 1 } return fromHsv(q[0], s, v) }
function darker(h, f) { var q = hsv(rgb(h)); return fromHsv(q[0], q[1], q[2] / f) }
// #AARRGGBB, the form QML reads (it doesn't parse CSS rgba())
function alpha(h, a) { var x = Math.round(a * 255).toString(16); return "#" + (x.length < 2 ? "0" + x : x) + String(h).replace("#", "") }

function theme(mode, name) {
    var p = PALETTES[name || "vs"] || PALETTES.vs
    var dark = mode !== "light", dk = mode === "darker", classic = mode === "dark"
    var B = p.border
    var surface = dk ? darker(p.deep, 1.4) : (dark ? lighter(p.deep, 1.18) : "#ffffff")
    var t = {
        dark: dark, darker: dk, classic: classic, mono: name === "mono",
        colBorder: B, accentCyan: p.A, accentMint: p.B, textWhite: "#ffffff", warnFill: "#ffb74d",
        surface: surface,
        surfaceHover: dark ? lighter(surface, 1.35) : "#f2f2f2",
        surfaceDivider: dark ? lighter(surface, 1.75) : p.divider,
        ink: dark ? p.divider : B,
        line: dk ? darker(B, 1.35) : (dark ? B : mix("#ffffff", B, 0.42)),
        lineShadow: dk ? darker(B, 1.8) : (dark ? darker(B, 1.3) : mix("#ffffff", B, 0.30)),
        ringWhite: dk ? lighter(surface, 2.0) : (dark ? mix("#ffffff", B, 0.08) : "#ffffff"),
        surfaceRing: dk ? lighter(surface, 1.6) : (dark ? mix("#ffffff", B, 0.18) : "#d9d9d9"),
        chipFill: dk ? darker(B, 1.35) : (dark ? B : mix("#ffffff", B, 0.14)),
        chipInk: dark ? "#ffffff" : B,
        fontFamily: "Google Sans Flex", fontStyleBold: "ExtraBold", iconFont: "Material Symbols Rounded",
        borderWidth: 3, radiusOuter: 13, shadowOffset: 4, outerRingWidth: 4
    }
    t.inkSub = alpha(t.ink, 0.667)
    t.pSurface = classic ? "#ffffff" : t.surface
    t.pSurfaceHover = classic ? "#f2f2f2" : t.surfaceHover
    t.pSurfaceDivider = classic ? p.divider : t.surfaceDivider
    t.pSurfaceRing = classic ? "#d9d9d9" : t.surfaceRing
    t.pRingWhite = classic ? "#ffffff" : t.ringWhite
    t.pLine = classic ? B : t.line
    t.pLineShadow = classic ? B : t.lineShadow
    t.pInk = classic ? B : t.ink
    t.pInkSub = classic ? alpha(B, 0.667) : t.inkSub
    return t
}
