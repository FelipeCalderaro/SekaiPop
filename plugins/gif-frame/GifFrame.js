.pragma library

// The GIF frame plugin's logic: pure functions, tested by tests/tst_gif_frame.qml.

var EXTS = ["gif", "webp", "apng", "png", "jpg", "jpeg", "avif", "bmp"]
var ANIMATED = ["gif", "webp", "apng", "png"]   // AnimatedImage plays these (a still png just shows)

function ext(name) {
    var m = String(name || "").toLowerCase().match(/\.([a-z0-9]+)$/)
    return m ? m[1] : ""
}

function isPicture(name) { return EXTS.indexOf(ext(name)) >= 0 }

// "~/x" -> "/home/you/x"; trims quotes a file manager's "copy path" may add.
function expand(path, home) {
    var p = String(path || "").trim().replace(/^["']|["']$/g, "")
    if (p.indexOf("file://") === 0)
        p = decodeURIComponent(p.slice(7))
    if (p === "~")
        return home
    if (p.indexOf("~/") === 0)
        return home + p.slice(1)
    return p
}

// A path is a folder to pick from when it doesn't name a picture.
function isFolder(path) { return path !== "" && !isPicture(path) }

// The next picture from a folder: random, never the same one twice in a row (when there is a
// choice). `rnd` is a number in [0, 1), passed in so tests can fix it.
function pickNext(list, current, rnd) {
    var pics = []
    for (var i = 0; i < list.length; i++)
        if (isPicture(list[i]))
            pics.push(list[i])
    if (pics.length === 0)
        return ""
    if (pics.length === 1)
        return pics[0]
    var others = pics.filter(function (p) { return p !== current })
    return others[Math.min(others.length - 1, Math.floor(rnd * others.length))]
}

// The picture's box inside the frame: `width` wide, as tall as the picture's shape asks, kept
// between a strip (0.4 of the width) and a tall portrait (1.6), so one odd file can't make a
// pillar or a ribbon on the desktop. Without a known size yet: 3:4.
function boxHeight(width, imgW, imgH) {
    if (!(imgW > 0 && imgH > 0))
        return Math.round(width * 0.75)
    var h = width * imgH / imgW
    return Math.round(Math.max(width * 0.4, Math.min(width * 1.6, h)))
}

// The caption's words, or the file's name (without extension) when "showName" is on.
function caption(text, file, showName) {
    var t = String(text || "").trim()
    if (t !== "")
        return t
    if (!showName || !file)
        return ""
    var base = String(file).split("/").pop()
    return base.replace(/\.[^.]+$/, "").replace(/[_-]+/g, " ")
}
