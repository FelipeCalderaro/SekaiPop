.pragma library

// The lockscreen's colours (sekaipop/modules/common/LockPalette.qml), worked out the same way from
// the same raw palette, for the SDDM theme. The shell writes the raw palette into theme.conf.user
// (scripts/theming/sddm-theme.sh), so the login screen wears the theme you have.
// Pure functions: tests in sekaipop/sddm/tests/tst_palette.qml.

// Virtual Singer: what the theme shows before the shell has written anything.
var DEFAULTS = {
    border: "#555473", A: "#04feee", B: "#00ffcb", deep: "#232235", rimHi: "#9796b8",
    glint: "#a9a6ff", wallMid: "#6e6d94", lockMint: "#7fe8d8", lockPink: "#ff75ac", mono: false
}

// The five card-attribute colours of the typed dots (ThemeSet.attributeColors); Monochrome greys.
var ATTRIBUTES = ["#8EE3EF", "#FF9ECB", "#FFE066", "#B39DDB", "#A5E6A5"]
var ATTRIBUTES_MONO = ["#d9d9d9", "#8a8a8a", "#f2f2f2", "#6e6e6e", "#bdbdbd"]

function isHex(v) { return typeof v === "string" && /^#[0-9a-fA-F]{6}$/.test(v) }

// config (SDDM's theme.conf + theme.conf.user, values are strings) -> the raw palette
// lockMint / lockPink are optional, as in the shell's palettes: a theme without them gets them
// worked out from its accents (colours() below). Virtual Singer's own two are only the default
// when the config says nothing about the palette at all.
function raw(cfg) {
    var out = {}
    var given = !!cfg && isHex(cfg.border)
    for (var k in DEFAULTS) {
        var v = cfg ? cfg[k] : undefined
        if (k === "mono")
            out.mono = v === true || v === "true"
        else if (k === "lockMint" || k === "lockPink")
            out[k] = isHex(v) ? v : (given ? undefined : DEFAULTS[k])
        else
            out[k] = isHex(v) ? v : DEFAULTS[k]
    }
    return out
}

function hue(c) { return c.hslHue < 0 ? 0 : c.hslHue }
function clamp(x) { return Math.max(0, Math.min(1, x)) }
function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

// raw palette -> every colour the theme draws with (LockPalette's names)
function colours(p) {
    var hsl = function (h, s, l, a) { return Qt.hsla(h, p.mono ? 0 : clamp(s), clamp(l), a === undefined ? 1 : a) }
    var cBorder = Qt.color(p.border), cA = Qt.color(p.A), cB = Qt.color(p.B), cDeep = Qt.color(p.deep)
    var cRim = Qt.color(p.rimHi), cGlint = Qt.color(p.glint), cWall = Qt.color(p.wallMid)
    var mint = p.lockMint !== undefined ? Qt.color(p.lockMint) : hsl(hue(cB), Math.min(cB.hslSaturation, 0.75), 0.72)
    var pink = p.lockPink !== undefined ? Qt.color(p.lockPink) : hsl(hue(cA), Math.min(cA.hslSaturation, 0.95), 0.73)
    var band = hsl(hue(cGlint), Math.min(cGlint.hslSaturation, 0.6), 0.62, 0.55)
    var scrimBase = Qt.darker(cBorder, 1.45)
    return {
        cBorder: cBorder, mint: mint, pink: pink,
        mintDeep: hsl(hue(mint), 0.6, 0.52),
        paper: hsl(hue(cB), 0.6, 0.99),
        panel: alpha(Qt.darker(cBorder, 1.15), 0.85),
        panelEdge: alpha(cRim, 0.4),
        divider: alpha(cBorder, 0.5),
        cap: alpha(Qt.darker(cBorder, 1.2), 0.85),
        capHover: alpha(Qt.lighter(Qt.darker(cBorder, 1.2), 1.35), 0.92),
        well: Qt.darker(cBorder, 1.35),
        periwinkle: cGlint,
        band: band,
        bandClear: alpha(band, 0),
        lavenderText: hsl(hue(cGlint), 0.8, 0.89),
        subText: alpha(cBorder, 0.667),
        shadow: alpha(cDeep, 0.25),
        scrimTop: alpha(scrimBase, 0.1),
        scrimClear: alpha(scrimBase, 0),
        scrimBottom: alpha(scrimBase, 0.6),
        fallbackTop: Qt.lighter(cWall, 1.1),
        fallbackBottom: Qt.darker(cBorder, 1.6),
        sparkle: hsl(hue(cA), 1, 0.94),
        attributes: p.mono ? ATTRIBUTES_MONO : ATTRIBUTES
    }
}

// A colour of the dots by the character's place, as the lockscreen does.
function dotColour(cols, index) { return cols.attributes[index % cols.attributes.length] }

// "Wrong password" and friends: what the bubble says after a failed login.
function failureWords(capsLock) {
    return capsLock ? "Wrong password · Caps Lock is on" : "Wrong password"
}
