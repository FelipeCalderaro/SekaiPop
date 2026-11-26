// node plugins/anilist/tests/anilist_unit.js   (from the repository's top folder)
// The AniList plugin's pure logic (AniList.js), and its manifest as the shell itself reads it
// (sekaipop's PluginManifest.js / PluginForm.js), so a mistake there is caught before the shell
// skips the plugin.
const assert = require("assert"), fs = require("fs"), path = require("path")
const here = path.join(__dirname, "..")
const top = path.join(here, "..", "..")

const src = fs.readFileSync(path.join(here, "AniList.js"), "utf8").replace(".pragma library", "")
const names = ["ENDPOINT", "PROFILE_COLORS", "typesFor", "listQuery", "PROGRESS_MUTATION", "body", "splitResponse",
    "errorText", "titleOf", "profileColor", "entryOf", "normalize", "sorted", "countdown", "countdownShort", "ago",
    "nextAiring", "behind", "fraction", "progressText", "bump", "countText", "statsText", "barFace", "isLight",
    "authorizeUrl", "cleanToken", "DEFAULT_PORT", "DEVELOPER_URL", "PIN_URL", "portOf", "redirectUrl",
    "cleanUsername", "cleanClientId", "authLine"]
const AL = new Function(src + ";return {" + names.map(n => n + ":" + n).join(",") + "}")()

// ===== queries =====
const pub = AL.listQuery(false, "ANIME")
assert(/^query \(\$name: String\)/.test(pub) && /User\(name: \$name\)/.test(pub), "public query asks by name")
assert(/anime: MediaListCollection\(userName: \$name, type: ANIME, status_in: \[CURRENT, REPEATING\]/.test(pub))
assert(!/manga:/.test(pub))
const both = AL.listQuery(true, "BOTH")
assert(/^query \(\$uid: Int\)/.test(both) && /Viewer \{/.test(both) && /unreadNotificationCount/.test(both))
assert(/anime: MediaListCollection\(userId: \$uid/.test(both) && /manga: MediaListCollection\(userId: \$uid/.test(both))
assert.deepStrictEqual(AL.typesFor("MANGA"), ["MANGA"])
assert.deepStrictEqual(AL.typesFor("nonsense"), ["ANIME"])
assert.deepStrictEqual(JSON.parse(AL.body("q", { a: 1 })), { query: "q", variables: { a: 1 } })

// ===== answers =====
const r = AL.splitResponse('{"data":{"x":1}}\n200')
assert.strictEqual(r.code, 200)
assert.deepStrictEqual(r.json, { data: { x: 1 } })
assert.strictEqual(AL.splitResponse("\n000").code, 0)
assert.strictEqual(AL.errorText(AL.splitResponse("\n000"), false), "No connection to AniList")
assert(/slow down/.test(AL.errorText(AL.splitResponse("{}\n429"), false)))
const notFound = AL.splitResponse('{"errors":[{"message":"User not found","status":404}],"data":{"User":null,"anime":null}}\n404')
assert.strictEqual(AL.errorText(notFound, false), "No AniList user by that name")
assert(/refused/.test(AL.errorText(AL.splitResponse('{"errors":[{"message":"Unauthorized."}]}\n401'), false)))
// the signed-in first call: the Viewer arrives, the lists don't yet; that is fine
const first = AL.splitResponse('{"errors":[{"message":"User not found"}],"data":{"Viewer":{"id":7},"anime":null}}\n200')
assert.strictEqual(AL.errorText(first, true), "")
assert.notStrictEqual(AL.errorText(first, false), "")
assert.strictEqual(AL.errorText(AL.splitResponse('{"data":{"Viewer":{"id":1}}}\n200'), false), "")

const media = (id, extra) => Object.assign({ id: id, siteUrl: "https://anilist.co/anime/" + id, episodes: 12, format: "TV",
    title: { romaji: "Romaji " + id, english: "English " + id, native: "ネイティブ", userPreferred: "Pref " + id },
    coverImage: { large: "L" + id, medium: "M" + id, color: "#e4a15d" }, nextAiringEpisode: null }, extra || {})
const json = { data: {
    Viewer: { id: 7, name: "me", unreadNotificationCount: 3, statistics: { anime: { episodesWatched: 1234, minutesWatched: 30000, meanScore: 77.6 } } },
    anime: { lists: [
        { entries: [
            { id: 1, progress: 3, updatedAt: 100, media: media(11, { nextAiringEpisode: { episode: 6, airingAt: 5000 } }) },
            { id: 2, progress: 12, updatedAt: 300, media: media(12) }
        ] },
        // REPEATING list holding the same entry again: kept once
        { entries: [{ id: 1, progress: 3, updatedAt: 100, media: media(11) }] }
    ] },
    manga: { lists: [{ entries: [{ id: 3, progress: 40, updatedAt: 200, media: media(13, { episodes: null, chapters: 0 }) }] }] }
} }
const got = AL.normalize(json, "BOTH")
assert.strictEqual(got.user.name, "me")
assert.strictEqual(got.unread, 3)
assert.deepStrictEqual(got.entries.map(e => e.id), [2, 3, 1], "newest change first, each once")
assert.deepStrictEqual(got.entries.map(e => e.kind), ["ANIME", "MANGA", "ANIME"])
const ep = got.entries.find(e => e.id === 1)
assert.strictEqual(ep.nextEpisode, 6)
assert.strictEqual(ep.airingAt, 5000)
assert.strictEqual(ep.cover, "L11")
assert.strictEqual(AL.normalize({ data: {} }, "ANIME").entries.length, 0)
assert.strictEqual(AL.normalize(null, "ANIME").user, null)

// ===== words and numbers =====
assert.strictEqual(AL.titleOf(ep.title, "user"), "Pref 11")
assert.strictEqual(AL.titleOf(ep.title, "english"), "English 11")
assert.strictEqual(AL.titleOf({ romaji: "R" }, "english"), "R", "falls back to romaji")
assert.strictEqual(AL.titleOf({}, "native"), "Untitled")
assert.strictEqual(AL.profileColor("blue"), "#3db4f2")
assert.strictEqual(AL.profileColor("#ABCDEF"), "#abcdef")
assert.strictEqual(AL.profileColor("chartreuse"), "")
assert.strictEqual(AL.countdown(2 * 86400 + 4 * 3600 + 59), "2d 4h")
assert.strictEqual(AL.countdown(4 * 3600 + 12 * 60), "4h 12m")
assert.strictEqual(AL.countdown(30), "1m")
assert.strictEqual(AL.countdown(0), "now")
assert.strictEqual(AL.countdownShort(4 * 3600 + 12 * 60), "4h")
assert.strictEqual(AL.ago(10), "just now")
assert.strictEqual(AL.ago(180), "3 min ago")
assert.strictEqual(AL.ago(7200), "2 h ago")
assert.strictEqual(AL.nextAiring(got.entries, 1000).id, 1)
assert.strictEqual(AL.nextAiring(got.entries, 6000), null, "already aired")
assert.strictEqual(AL.behind(ep), 2, "episodes 4 and 5 are out, you are on 3")
assert.strictEqual(AL.behind(got.entries[0]), 0, "nothing airing: not behind")
assert.strictEqual(AL.fraction({ progress: 3, total: 12, nextEpisode: 0 }), 0.25)
assert.strictEqual(AL.fraction({ progress: 3, total: 0, nextEpisode: 7 }), 0.5, "no total: against what has aired")
assert.strictEqual(AL.fraction({ progress: 3, total: 0, nextEpisode: 0 }), 0)
assert.strictEqual(AL.progressText({ kind: "ANIME", progress: 7, total: 12 }), "7 / 12 ep")
assert.strictEqual(AL.progressText({ kind: "MANGA", progress: 41, total: 0 }), "41 ch")
assert.deepStrictEqual(AL.bump({ id: 9, progress: 3, total: 12 }), { id: 9, progress: 4 })
assert.deepStrictEqual(AL.bump({ id: 9, progress: 11, total: 12 }), { id: 9, progress: 12, status: "COMPLETED" })
assert.deepStrictEqual(AL.bump({ id: 9, progress: 50, total: 0 }), { id: 9, progress: 51 }, "unknown total never completes")
assert.strictEqual(AL.countText(got.entries), "2 watching · 1 reading")
assert.strictEqual(AL.countText([]), "0 watching")
assert.strictEqual(AL.statsText(got.user, "ANIME"), Number(1234).toLocaleString() + " ep · 21 days · mean 78", "10+ days: whole days")
assert.strictEqual(AL.statsText({ statistics: { anime: { episodesWatched: 40, minutesWatched: 4896 } } }, "ANIME"), "40 ep · 3.4 days")
assert.strictEqual(AL.statsText(null, "ANIME"), "")
assert.deepStrictEqual(AL.sorted(got.entries, "airing", 1000).map(e => e.id), [1, 2, 3])
assert.deepStrictEqual(AL.sorted(got.entries, "updated", 1000).map(e => e.id), [2, 3, 1])

// ===== the bar's face =====
const st = { configured: true, signedIn: true, loading: false, error: "", entries: got.entries, unread: 3 }
assert.strictEqual(AL.barFace("airing", st, 1000, "user").text, "Ep 6 · 1h 6m")
assert.strictEqual(AL.barFace("airing", st, 1000, "user").short, "1h")
assert.strictEqual(AL.barFace("airing", st, 9999, "user").text, "3", "nothing airing: the count")
assert.strictEqual(AL.barFace("count", st, 1000, "user").icon, "live_tv")
assert.strictEqual(AL.barFace("unread", st, 1000, "user").text, "3")
assert.strictEqual(AL.barFace("unread", Object.assign({}, st, { signedIn: false }), 1000, "user").text, "3", "unread needs sign-in: the count")
assert.strictEqual(AL.barFace("progress", st, 1000, "user").text, "Pref 12  12/12")
assert(/notification/.test(AL.barFace("count", st, 1000, "user").tip))
assert.strictEqual(AL.barFace("airing", { configured: false, entries: [] }, 0, "user").tip, "AniList · click to set up")
assert.strictEqual(AL.barFace("airing", { configured: true, error: "boom", entries: [] }, 0, "user").icon, "cloud_off")
assert.strictEqual(AL.barFace("airing", { configured: true, loading: true, entries: [] }, 0, "user").text, "…")

// ===== ink, sign-in =====
assert.strictEqual(AL.isLight("#ffffff"), true)
assert.strictEqual(AL.isLight("#04feee"), true, "the default cyan takes dark ink")
assert.strictEqual(AL.isLight("#3db4f2"), false)
assert.strictEqual(AL.isLight("#232235"), false)
assert.strictEqual(AL.isLight("#ff04feee"), true, "#aarrggbb")
assert.strictEqual(AL.authorizeUrl(" 12345 "), "https://anilist.co/api/v2/oauth/authorize?client_id=12345&response_type=token")
assert.strictEqual(AL.authorizeUrl("abc"), "")
assert.strictEqual(AL.authorizeUrl(""), "")
const jwt = "eyJ" + "a".repeat(60) + ".eyJ" + "b".repeat(60) + "." + "c".repeat(40)
assert.strictEqual(AL.cleanToken("  Bearer " + jwt + "\n"), jwt)
assert.strictEqual(AL.cleanToken(jwt.slice(0, 50)), "", "too short")
assert.strictEqual(AL.cleanToken("hello world"), "")

// ===== connecting from the popup =====
assert.strictEqual(AL.redirectUrl(47823), "http://localhost:47823/callback")
assert.strictEqual(AL.redirectUrl("50000"), "http://localhost:50000/callback")
assert.strictEqual(AL.portOf(80), AL.DEFAULT_PORT, "privileged ports fall back")
assert.strictEqual(AL.portOf("nope"), AL.DEFAULT_PORT)
assert.strictEqual(AL.cleanUsername("  Felipe123 "), "Felipe123")
assert.strictEqual(AL.cleanUsername("@Felipe"), "Felipe")
assert.strictEqual(AL.cleanUsername("https://anilist.co/user/Felipe/animelist"), "Felipe", "a pasted profile link works")
assert.strictEqual(AL.cleanUsername("bad name!"), "")
assert.strictEqual(AL.cleanClientId(" 12345 "), "12345")
assert.strictEqual(AL.cleanClientId("12a"), "")
assert.deepStrictEqual(AL.authLine("ready"), { kind: "ready", value: "" })
assert.deepStrictEqual(AL.authLine("token abc.def.ghi\n"), { kind: "token", value: "abc.def.ghi" })
assert.deepStrictEqual(AL.authLine("error port 47823 is in use"), { kind: "error", value: "port 47823 is in use" })
assert.deepStrictEqual(AL.authLine("Traceback (most recent call last):"), { kind: "", value: "" })

// the popup's Settings page offers every setting a person chooses (not the account ones)
const popup = fs.readFileSync(path.join(here, "Popup.qml"), "utf8")
const manifest = JSON.parse(fs.readFileSync(path.join(here, "plugin.json"), "utf8"))
for (const k of Object.keys(manifest.settings)) {
    if (["username", "clientId", "callbackPort"].indexOf(k) >= 0)
        continue
    assert(popup.includes('key: "' + k + '"'), "the popup's Settings page lacks " + k)
}
// and every choice it offers is one the manifest allows
const rows = Array.from(popup.matchAll(/\{ key: "(\w+)", label: "[^"]*", options: (\[.*?\]) \}/g))
assert.strictEqual(rows.length, Object.keys(manifest.settings).length - 3, "every Settings-page row was checked")
for (const m of rows) {
    const values = JSON.parse(m[2].replace(/(\w+):/g, '"$1":'))
    const info = manifest.settingsInfo[m[1]] || {}
    for (const v of values) {
        assert.strictEqual(typeof v.value, typeof manifest.settings[m[1]], m[1] + ": wrong type " + v.value)
        if (info.choices)
            assert(info.choices.some(c => (c.value || c) === v.value), m[1] + ": " + v.value + " is not a choice")
        if (info.min !== undefined)
            assert(v.value >= info.min && v.value <= info.max, m[1] + ": " + v.value + " out of range")
    }
}
// the callback helper the service starts is there
assert(fs.existsSync(path.join(here, "auth-callback.py")))
assert(/root\.host\.path\("auth-callback\.py"\)/.test(fs.readFileSync(path.join(here, "Service.qml"), "utf8")))

// ===== the manifest, as the shell reads it =====
const mf = rel => fs.readFileSync(path.join(top, "sekaipop", "modules", "common", "functions", rel), "utf8").replace(".pragma library", "")
const PM = new Function(mf("PluginManifest.js") + ";return { parse: parse, API_VERSION: API_VERSION }")()
const PF = new Function("console", mf("PluginForm.js") + ";return { form: form }")(console)
const files = ["Bar.qml", "Popup.qml", "Service.qml"].filter(f => fs.existsSync(path.join(here, f)))
assert.strictEqual(files.length, 3)
assert(!fs.existsSync(path.join(here, "Widget.qml")), "bar-only: no desktop widget")
const p = PM.parse(fs.readFileSync(path.join(here, "plugin.json"), "utf8"), "anilist", files.join(" "))
assert(p.ok, "the shell would skip it: " + JSON.stringify(p))
assert.strictEqual(p.plugin.api, PM.API_VERSION)
assert(p.plugin.bar && p.plugin.files.bar && p.plugin.files.popup && p.plugin.files.service)
assert.deepStrictEqual(Object.keys(p.plugin.secrets), ["token"])
// every setting keeps all its settingsInfo (a field wrong for its setting would be dropped)
const raw = JSON.parse(fs.readFileSync(path.join(here, "plugin.json"), "utf8"))
for (const k of Object.keys(raw.settingsInfo)) {
    assert(k in raw.settings, "settingsInfo for an unknown setting: " + k)
    for (const f of Object.keys(raw.settingsInfo[k]))
        assert(p.plugin.settingsInfo[k] && f in p.plugin.settingsInfo[k], k + "." + f + " was dropped by the shell")
}
// every choice default is one of its choices; every range holds its default
for (const k of Object.keys(raw.settings)) {
    const info = raw.settingsInfo[k] || {}
    if (info.choices)
        assert(info.choices.some(c => (c.value || c) === raw.settings[k]), k + " default is not a choice")
    if (info.min !== undefined)
        assert(raw.settings[k] >= info.min && raw.settings[k] <= info.max, k + " default out of range")
}
// and Settings can draw a form for it
const groups = PF.form(p.plugin, raw.settings)
assert(Array.isArray(groups) && groups.length > 0, "no settings form")

// the theme names the QML uses are ones the plugin api promises (docs/PLUGINS.md)
const doc = fs.readFileSync(path.join(top, "docs", "PLUGINS.md"), "utf8")
const promised = doc.split("<!-- theme-names -->")[1].split("<!-- /theme-names -->")[0]
const used = new Set()
for (const f of ["Bar.qml", "Popup.qml", "EntryRow.qml", "Key.qml", "Plate.qml", "Field.qml", "ChoiceRow.qml"]) {
    const q = fs.readFileSync(path.join(here, f), "utf8")
    for (const m of q.matchAll(/\b(?:t|theme)\.([a-zA-Z]+)\b/g))
        used.add(m[1])
}
for (const n of used)
    assert(new RegExp("`" + n + "`").test(promised), "theme." + n + " is not a promised theme name")

console.log("anilist plugin: ok")
