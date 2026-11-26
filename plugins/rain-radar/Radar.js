.pragma library

// The rain radar's logic: pure functions, tested by tests/tst_radar.qml.
// Map tiles are the usual Web Mercator ("slippy map") tiles: zoom z has 2^z x 2^z tiles of 256 px.

var TILE = 256
var MIN_ZOOM = 3
var MAX_ZOOM = 7            // RainViewer's free radar tiles stop at zoom 7

function clampZoom(z) { return Math.max(MIN_ZOOM, Math.min(MAX_ZOOM, Math.round(+z || 5))) }

// "14.15, 121.47" -> { lat, lon } | null
function parseCoords(text) {
    var m = String(text || "").trim().match(/^(-?\d+(?:\.\d+)?)\s*[,;\s]\s*(-?\d+(?:\.\d+)?)$/)
    if (!m)
        return null
    var lat = +m[1], lon = +m[2]
    if (Math.abs(lat) > 85 || Math.abs(lon) > 180)
        return null
    return { lat: lat, lon: lon }
}

// Fractional tile coordinates of a point at zoom z.
function tileXY(lat, lon, z) {
    var n = Math.pow(2, z)
    var rad = lat * Math.PI / 180
    return {
        x: (lon + 180) / 360 * n,
        y: (1 - Math.log(Math.tan(rad) + 1 / Math.cos(rad)) / Math.PI) / 2 * n
    }
}

// The tiles that cover a W x H view centred on (lat, lon), each with where it goes:
// [{ x, y, z, left, top }]. x wraps around the date line; rows off the map are left out.
function layout(lat, lon, z, W, H) {
    var c = tileXY(lat, lon, z), n = Math.pow(2, z)
    var x0 = Math.floor(c.x - W / 2 / TILE), x1 = Math.floor(c.x + W / 2 / TILE)
    var y0 = Math.floor(c.y - H / 2 / TILE), y1 = Math.floor(c.y + H / 2 / TILE)
    var out = []
    for (var ty = y0; ty <= y1; ty++) {
        if (ty < 0 || ty >= n)
            continue
        for (var tx = x0; tx <= x1; tx++)
            out.push({ x: ((tx % n) + n) % n, y: ty, z: z,
                       left: Math.round(W / 2 + (tx - c.x) * TILE), top: Math.round(H / 2 + (ty - c.y) * TILE) })
    }
    return out
}

// RainViewer's weather-maps.json -> { host, frames: [{ time, path, forecast }] } | null
function frames(json) {
    var d
    try { d = typeof json === "string" ? JSON.parse(json) : json } catch (e) { return null }
    if (!d || !d.host || !d.radar)
        return null
    var out = []
    var past = d.radar.past || [], cast = d.radar.nowcast || []
    for (var i = 0; i < past.length; i++)
        if (past[i] && past[i].path) out.push({ time: +past[i].time, path: past[i].path, forecast: false })
    for (var j = 0; j < cast.length; j++)
        if (cast[j] && cast[j].path) out.push({ time: +cast[j].time, path: cast[j].path, forecast: true })
    return { host: d.host, frames: out }
}

// A radar tile: {host}{path}/{size}/{z}/{x}/{y}/{color}/{smooth}_{snow}.png
function radarUrl(host, path, z, x, y, color, smooth, snow) {
    return host + path + "/" + TILE + "/" + z + "/" + x + "/" + y + "/" + color + "/" + (smooth ? 1 : 0) + "_" + (snow ? 1 : 0) + ".png"
}

// The map under it: Esri's light or dark grey canvas (no labels clutter, no key). Note the tile
// order: Esri's tile/{z}/{y}/{x}. (CARTO's basemaps now ask for an API key, so they aren't used.)
function baseUrl(dark, z, x, y) {
    return "https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/" + (dark ? "World_Dark_Gray_Base" : "World_Light_Gray_Base")
        + "/MapServer/tile/" + z + "/" + y + "/" + x
}

// "now", "20 min ago", "in 10 min" for a frame (unix seconds) against now (ms)
function frameWords(t, nowMs) {
    var mins = Math.round((t * 1000 - nowMs) / 60000)
    if (Math.abs(mins) < 3) return "now"
    if (mins < 0) return (-mins) + " min ago"
    return "in " + mins + " min"
}

function clock(t) {
    var d = new Date(t * 1000)
    return (d.getHours() < 10 ? "0" : "") + d.getHours() + ":" + (d.getMinutes() < 10 ? "0" : "") + d.getMinutes()
}

// Open-Meteo geocoding -> { lat, lon, label } | null
function geocoded(json) {
    var d
    try { d = typeof json === "string" ? JSON.parse(json) : json } catch (e) { return null }
    var r = d && d.results && d.results[0]
    if (!r || !(r.latitude === +r.latitude))
        return null
    return { lat: +r.latitude, lon: +r.longitude, label: r.name + (r.country_code ? ", " + r.country_code : "") }
}
