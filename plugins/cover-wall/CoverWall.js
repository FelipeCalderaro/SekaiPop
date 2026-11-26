.pragma library

// The cover wall's logic: pure functions, tested by tests/tst_cover_wall.qml.

// One entry per album: the same album from a different song moves to the front instead of
// appearing twice. A single (no album) counts as its own title.
function albumKey(t) {
    var album = String(t.album || "").trim().toLowerCase()
    var artist = String(t.artist || "").trim().toLowerCase()
    return (album !== "" ? album : "title:" + String(t.title || "").trim().toLowerCase()) + "\u0001" + artist
}

// Covers it can show: a web picture, a file, or one handed over inline. Anything else
// (an empty string, a player's own scheme) has no cover, so the track isn't added.
function usableArt(url) {
    var u = String(url || "")
    return /^(https?:\/\/|file:\/\/|data:image\/)/.test(u)
}

// The history with `t` ({ title, artist, album, art, player }) at the front. Kept to `max`.
function remember(list, t, now, max) {
    if (!t || !usableArt(t.art) || String(t.title || "").trim() === "")
        return list
    var key = albumKey(t)
    var out = [{ key: key, title: t.title, artist: t.artist || "", album: t.album || "", art: t.art,
                 player: t.player || "", at: now }]
    for (var i = 0; i < (list || []).length && out.length < max; i++)
        if (list[i] && list[i].key !== key)
            out.push(list[i])
    return out
}

// Read back what was saved; anything malformed is dropped rather than breaking the wall.
function load(text, max) {
    var v
    try { v = JSON.parse(text) } catch (e) { return [] }
    if (!Array.isArray(v))
        return []
    return v.filter(function (e) {
        return e && typeof e.key === "string" && typeof e.title === "string" && usableArt(e.art)
    }).slice(0, max)
}

// Where a click on a cover searches. kind: "spotify" | "youtube" | "off"
function searchUrl(kind, e) {
    var q = encodeURIComponent(((e.album || e.title) + " " + (e.artist || "")).trim())
    if (kind === "spotify")
        return "https://open.spotify.com/search/" + q
    if (kind === "youtube")
        return "https://music.youtube.com/search?q=" + q
    return ""
}

// "Album · Artist", leaving out what's empty
function subtitle(e) {
    return [e.album, e.artist].filter(function (x) { return x && String(x).trim() !== "" }).join(" · ")
}
