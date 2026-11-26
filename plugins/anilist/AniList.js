.pragma library

// Everything the AniList plugin works out without touching QML: the GraphQL it sends, how it
// reads the answer, and the words and numbers it shows. Pure functions, so
// tests/anilist_unit.js runs them in node (or any plain JS engine).

var ENDPOINT = "https://graphql.anilist.co"

// AniList's named profile colours (Settings > Account > Profile colour on anilist.co). A
// profile can also hold a "#rrggbb" of its own.
var PROFILE_COLORS = {
    blue: "#3db4f2", purple: "#c063ff", pink: "#fc9dd6", orange: "#ef881a",
    red: "#e13333", green: "#4cca51", gray: "#677b94"
}

var MEDIA_FIELDS = "id siteUrl episodes chapters volumes format status averageScore"
    + " title { romaji english native userPreferred }"
    + " coverImage { medium large color }"
    + " nextAiringEpisode { episode airingAt timeUntilAiring }"

var ENTRY_FIELDS = "id status progress progressVolumes score(format: POINT_10_DECIMAL) updatedAt"
    + " media { " + MEDIA_FIELDS + " }"

var USER_FIELDS = "id name siteUrl bannerImage avatar { large medium }"
    + " options { titleLanguage profileColor }"
    + " statistics { anime { count episodesWatched minutesWatched meanScore }"
    + " manga { count chaptersRead volumesRead meanScore } }"

// "ANIME" | "MANGA" | "BOTH" -> the list types to ask for.
function typesFor(listType) {
    if (listType === "BOTH")
        return ["ANIME", "MANGA"]
    return [listType === "MANGA" ? "MANGA" : "ANIME"]
}

// The one query a refresh sends. Signed in (`auth`): the Viewer, and its lists by `$uid`
// (unknown on the very first call: the lists then come back "not found", the Viewer still
// arrives, and the next call has the id). Not signed in: a public profile by `$name`.
function listQuery(auth, listType) {
    var who = auth ? "userId: $uid" : "userName: $name"
    var lists = typesFor(listType).map(function (t) {
        return t.toLowerCase() + ": MediaListCollection(" + who + ", type: " + t
            + ", status_in: [CURRENT, REPEATING], sort: UPDATED_TIME_DESC)"
            + " { lists { entries { " + ENTRY_FIELDS + " } } }"
    })
    var head = auth
        ? "Viewer { " + USER_FIELDS + " unreadNotificationCount }"
        : "User(name: $name) { " + USER_FIELDS + " }"
    return "query (" + (auth ? "$uid: Int" : "$name: String") + ") { " + head + " " + lists.join(" ") + " }"
}

var PROGRESS_MUTATION = "mutation ($id: Int, $progress: Int, $status: MediaListStatus)"
    + " { SaveMediaListEntry(id: $id, progress: $progress, status: $status) { id progress status } }"

// The request body, as curl sends it.
function body(query, variables) {
    return JSON.stringify({ query: query, variables: variables || {} })
}

// curl prints the answer, then "\n<http code>" (-w). -> { code, json, text }
function splitResponse(out) {
    var s = String(out || "")
    var cut = s.lastIndexOf("\n")
    var code = cut >= 0 ? parseInt(s.slice(cut + 1), 10) : 0
    var text = cut >= 0 ? s.slice(0, cut) : s
    var json = null
    try {
        json = JSON.parse(text)
    } catch (e) {
        json = null
    }
    return { code: isFinite(code) ? code : 0, json: json, text: text }
}

// What went wrong, in words, or "" when nothing did. `partialOk`: an answer with data AND
// errors is fine (the signed-in first call, see listQuery).
function errorText(res, partialOk) {
    if (res.code === 0)
        return "No connection to AniList"
    if (res.code === 429)
        return "AniList says slow down · trying again later"
    if (res.code === 401 || res.code === 400 && /invalid token/i.test(res.text))
        return "The saved token was refused · sign in again"
    if (!res.json)
        return "AniList answered " + res.code
    var errs = res.json.errors || []
    var hasData = !!res.json.data && Object.keys(res.json.data).some(function (k) { return res.json.data[k] })
    if (errs.length === 0 || partialOk && hasData)
        return ""
    var m = String(errs[0].message || "error")
    if (/user not found/i.test(m))
        return "No AniList user by that name"
    if (/private/i.test(m))
        return "That list is private · sign in to see it"
    if (/unauthori[sz]ed/i.test(m))
        return "The saved token was refused · sign in again"
    return m
}

// AniList's title in the language asked for. `lang`: "user" (the profile's own choice,
// userPreferred), "romaji", "english" or "native"; anything missing falls back to romaji.
function titleOf(title, lang) {
    var t = title || {}
    var pick = lang === "english" ? t.english
        : lang === "native" ? t.native
        : lang === "romaji" ? t.romaji
        : t.userPreferred
    return String(pick || t.romaji || t.english || t.native || "Untitled")
}

function profileColor(c) {
    if (!c)
        return ""
    var s = String(c).toLowerCase()
    if (/^#[0-9a-f]{6}$/.test(s))
        return s
    return PROFILE_COLORS[s] || ""
}

// One list entry, flat: what the popup and the bar read.
function entryOf(e, kind) {
    var m = e.media || {}
    var air = m.nextAiringEpisode || null
    var total = kind === "MANGA" ? (m.chapters || 0) : (m.episodes || 0)
    return {
        id: e.id,
        mediaId: m.id || 0,
        kind: kind,
        status: e.status || "CURRENT",
        progress: e.progress || 0,
        volumes: e.progressVolumes || 0,
        total: total,
        score: e.score || 0,
        updatedAt: e.updatedAt || 0,
        title: m.title || {},
        cover: m.coverImage ? (m.coverImage.large || m.coverImage.medium || "") : "",
        color: m.coverImage && m.coverImage.color ? String(m.coverImage.color) : "",
        siteUrl: m.siteUrl || "",
        format: m.format || "",
        mediaStatus: m.status || "",
        averageScore: m.averageScore || 0,
        nextEpisode: air ? air.episode : 0,
        airingAt: air ? air.airingAt : 0
    }
}

// The answer -> { user, unread, entries }. Entries of every list asked for, newest change
// first, each entry once.
function normalize(json, listType) {
    var d = (json && json.data) || {}
    var u = d.Viewer || d.User || null
    var seen = {}
    var entries = []
    typesFor(listType).forEach(function (t) {
        var col = d[t.toLowerCase()]
        var lists = col && col.lists ? col.lists : []
        lists.forEach(function (l) {
            (l.entries || []).forEach(function (e) {
                if (!e || seen[e.id])
                    return
                seen[e.id] = true
                entries.push(entryOf(e, t))
            })
        })
    })
    entries.sort(function (a, b) { return b.updatedAt - a.updatedAt })
    return {
        user: u,
        unread: d.Viewer && d.Viewer.unreadNotificationCount ? d.Viewer.unreadNotificationCount : 0,
        entries: entries
    }
}

// "updated": newest change first (the list as it came). "airing": the next episode to air
// first, then the rest as they came.
function sorted(entries, by, nowSec) {
    if (by !== "airing")
        return entries.slice()
    return entries.slice().sort(function (a, b) {
        var aa = a.airingAt > nowSec ? a.airingAt : Infinity
        var bb = b.airingAt > nowSec ? b.airingAt : Infinity
        if (aa !== bb)
            return aa - bb
        return b.updatedAt - a.updatedAt
    })
}

// "2d 4h", "4h 12m", "12m", "now".
function countdown(sec) {
    if (!(sec > 0))
        return "now"
    var d = Math.floor(sec / 86400)
    var h = Math.floor(sec % 86400 / 3600)
    var m = Math.floor(sec % 3600 / 60)
    if (d > 0)
        return d + "d " + h + "h"
    if (h > 0)
        return h + "h " + m + "m"
    return Math.max(1, m) + "m"
}

// The largest unit only, for a standing bar: "2d", "4h", "12m".
function countdownShort(sec) {
    return countdown(sec).split(" ")[0]
}

// "just now", "3 min ago", "2 h ago", "4 d ago".
function ago(sec) {
    if (sec < 45)
        return "just now"
    if (sec < 3600)
        return Math.round(sec / 60) + " min ago"
    if (sec < 86400)
        return Math.round(sec / 3600) + " h ago"
    return Math.round(sec / 86400) + " d ago"
}

// The anime entry whose next episode airs soonest, or null.
function nextAiring(entries, nowSec) {
    var best = null
    entries.forEach(function (e) {
        if (e.kind === "ANIME" && e.airingAt > nowSec && (!best || e.airingAt < best.airingAt))
            best = e
    })
    return best
}

// Episodes out that you have not watched yet (0 for a finished show: its total is known and
// nothing is airing, so "behind" would be every episode left).
function behind(e) {
    if (e.kind !== "ANIME" || !e.nextEpisode)
        return 0
    return Math.max(0, e.nextEpisode - 1 - e.progress)
}

// How far through it you are, 0..1. Without a known total, against what has aired so far.
function fraction(e) {
    var of = e.total > 0 ? e.total : (e.nextEpisode > 1 ? e.nextEpisode - 1 : 0)
    if (of <= 0)
        return 0
    return Math.max(0, Math.min(1, e.progress / of))
}

// "7 / 12 ep", "41 ch", "7 / ? ep".
function progressText(e) {
    var unit = e.kind === "MANGA" ? "ch" : "ep"
    if (e.total > 0)
        return e.progress + " / " + e.total + " " + unit
    return e.progress + " " + unit
}

// What +1 sends: the next progress, and COMPLETED when that is the last one.
function bump(e) {
    var p = e.progress + 1
    var out = { id: e.id, progress: p }
    if (e.total > 0 && p >= e.total)
        out.status = "COMPLETED"
    return out
}

function plural(n, one, many) {
    return n + " " + (n === 1 ? one : (many || one + "s"))
}

// "5 watching", "2 reading", "5 watching · 2 reading".
function countText(entries) {
    var a = entries.filter(function (e) { return e.kind === "ANIME" }).length
    var m = entries.length - a
    var parts = []
    if (a > 0 || m === 0)
        parts.push(a + " watching")
    if (m > 0)
        parts.push(m + " reading")
    return parts.join(" · ")
}

// "245 ep · 3.4 days · mean 78" / "1,204 ch · mean 81".
function statsText(user, kind) {
    var st = user && user.statistics ? user.statistics[kind === "MANGA" ? "manga" : "anime"] : null
    if (!st)
        return ""
    var parts = []
    if (kind === "MANGA") {
        parts.push(Number(st.chaptersRead || 0).toLocaleString() + " ch")
    } else {
        parts.push(Number(st.episodesWatched || 0).toLocaleString() + " ep")
        var days = (st.minutesWatched || 0) / 1440
        if (days > 0)
            parts.push((days >= 10 ? Math.round(days) : days.toFixed(1)) + " days")
    }
    if (st.meanScore)
        parts.push("mean " + Math.round(st.meanScore))
    return parts.join(" · ")
}

// What the bar entry shows. `mode`: "airing" | "progress" | "count" | "unread".
// -> { icon, text, short, tip }   (short: a standing bar's few characters)
function barFace(mode, state, nowSec, lang) {
    var entries = state.entries || []
    if (!state.configured)
        return { icon: "live_tv", text: "AniList", short: "AL", tip: "AniList · click to set up" }
    if (state.error && entries.length === 0)
        return { icon: "cloud_off", text: "AniList", short: "!", tip: state.error }
    if (state.loading && entries.length === 0)
        return { icon: "live_tv", text: "…", short: "…", tip: "Loading your AniList…" }

    var tip = [countText(entries)]
    var next = nextAiring(entries, nowSec)
    if (next)
        tip.push(titleOf(next.title, lang) + " · ep " + next.nextEpisode + " in " + countdown(next.airingAt - nowSec))
    if (state.unread > 0)
        tip.push(plural(state.unread, "notification"))
    var tipText = tip.join("\n")

    if (mode === "unread" && state.signedIn)
        return { icon: state.unread > 0 ? "notifications_active" : "notifications", text: String(state.unread),
                 short: String(state.unread), tip: tipText }
    if (mode === "progress" && entries.length > 0) {
        var e = entries[0]
        var name = titleOf(e.title, lang)
        if (name.length > 18)
            name = name.slice(0, 17).replace(/\s+$/, "") + "…"
        return { icon: e.kind === "MANGA" ? "menu_book" : "play_circle", text: name + "  " + e.progress
                 + (e.total > 0 ? "/" + e.total : ""), short: String(e.progress), tip: tipText }
    }
    if (mode === "airing" && next)
        return { icon: "schedule", text: "Ep " + next.nextEpisode + " · " + countdown(next.airingAt - nowSec),
                 short: countdownShort(next.airingAt - nowSec), tip: tipText }
    return { icon: "live_tv", text: String(entries.length), short: String(entries.length), tip: tipText }
}

// Light or dark ink for text on `hex` ("#rrggbb" or "#aarrggbb"): relative luminance.
function isLight(hex) {
    var s = String(hex || "").replace("#", "")
    if (s.length === 8)
        s = s.slice(2)
    if (s.length !== 6)
        return false
    var c = [0, 2, 4].map(function (i) {
        var v = parseInt(s.slice(i, i + 2), 16) / 255
        return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)
    })
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2] > 0.45
}

// The sign-in page (implicit grant). AniList shows the token on its "pin" page for a client
// whose redirect URL is https://anilist.co/api/v2/oauth/pin.
function authorizeUrl(clientId) {
    var id = String(clientId || "").trim()
    if (!/^\d+$/.test(id))
        return ""
    return "https://anilist.co/api/v2/oauth/authorize?client_id=" + id + "&response_type=token"
}

// Signing in from the popup: auth-callback.py listens on this port and AniList sends the browser
// to this address, so it is what the API client's "Redirect URL" must be, exactly.
var DEFAULT_PORT = 47823
var DEVELOPER_URL = "https://anilist.co/settings/developer"
var PIN_URL = "https://anilist.co/api/v2/oauth/pin"

function portOf(p) {
    var n = Math.round(Number(p))
    return n >= 1024 && n <= 65535 ? n : DEFAULT_PORT
}

function redirectUrl(port) {
    return "http://localhost:" + portOf(port) + "/callback"
}

// A username as AniList allows it (letters and digits), or "" for anything else.
function cleanUsername(s) {
    var u = String(s || "").trim().replace(/^@/, "").replace(/^https?:\/\/anilist\.co\/user\//i, "").replace(/\/.*$/, "")
    return /^[A-Za-z0-9]{2,20}$/.test(u) ? u : ""
}

// A client ID as AniList shows it (a number), or "".
function cleanClientId(s) {
    var id = String(s || "").trim()
    return /^\d{1,10}$/.test(id) ? id : ""
}

// One line from auth-callback.py -> { kind: "ready" | "token" | "error" | "timeout" | "", value }
function authLine(line) {
    var s = String(line || "").trim()
    var cut = s.indexOf(" ")
    var kind = cut < 0 ? s : s.slice(0, cut)
    var value = cut < 0 ? "" : s.slice(cut + 1)
    if (["ready", "token", "error", "timeout"].indexOf(kind) < 0)
        return { kind: "", value: "" }
    return { kind: kind, value: value }
}

// A pasted token, cleaned: AniList's are long JWTs (three base64url parts).
function cleanToken(s) {
    var t = String(s || "").replace(/^\s*(Bearer\s+)?/i, "").replace(/\s+/g, "")
    return /^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/.test(t) && t.length > 100 ? t : ""
}
