.pragma library

// The market ticker's logic: pure functions, tested by tests/tst_market.qml. No network here.

var INTERVALS = ["1m", "5m", "15m", "1h", "4h", "1d"]
var QUOTES = ["USDT", "USDC", "FDUSD", "BUSD", "TUSD", "BTC", "ETH", "BNB", "EUR", "TRY", "BRL", "JPY", "GBP"]

function validSymbol(s) { return /^[A-Z0-9]{5,20}$/.test(String(s || "")) }

// "btcusdt eth-usdt, SOLUSDT" -> ["BTCUSDT", "ETHUSDT", "SOLUSDT"] (at most 8, no repeats)
function parseSymbols(text) {
    var out = []
    var parts = String(text || "").toUpperCase().replace(/[-\/]/g, "").split(/[\s,;]+/)
    for (var i = 0; i < parts.length && out.length < 8; i++)
        if (validSymbol(parts[i]) && out.indexOf(parts[i]) < 0)
            out.push(parts[i])
    return out
}

// "BTCUSDT" -> { base: "BTC", quote: "USDT" }
function split(symbol) {
    var s = String(symbol || "")
    for (var i = 0; i < QUOTES.length; i++) {
        var q = QUOTES[i]
        if (s.length > q.length && s.slice(-q.length) === q)
            return { base: s.slice(0, -q.length), quote: q }
    }
    return { base: s, quote: "" }
}

function pairLabel(symbol) {
    var p = split(symbol)
    return p.quote ? p.base + " / " + p.quote : p.base
}

// Binance klines ([[openTime, o, h, l, c, v, ...], ...]) -> [{ t, o, h, l, c, v }]
function parseKlines(json) {
    var a
    try { a = typeof json === "string" ? JSON.parse(json) : json } catch (e) { return null }
    if (!Array.isArray(a))
        return null
    var out = []
    for (var i = 0; i < a.length; i++) {
        var k = a[i]
        if (!Array.isArray(k) || k.length < 6)
            continue
        out.push({ t: +k[0], o: +k[1], h: +k[2], l: +k[3], c: +k[4], v: +k[5] })
    }
    return out
}

// A stream message ({"e":"kline","k":{t,o,h,l,c,v,...}}) -> { t, o, h, l, c, v } | null
function parseStream(text) {
    var m
    try { m = JSON.parse(text) } catch (e) { return null }
    var k = m && (m.k || (m.data && m.data.k))
    if (!k || k.t === undefined)
        return null
    return { t: +k.t, o: +k.o, h: +k.h, l: +k.l, c: +k.c, v: +k.v }
}

// The candles with `k` folded in: the same open time replaces the last candle (it is still forming),
// a newer one is appended and the oldest dropped past `max`. An older one is ignored.
function applyCandle(list, k, max) {
    if (!k)
        return list
    var a = (list || []).slice()
    var last = a.length ? a[a.length - 1] : null
    if (last && k.t === last.t)
        a[a.length - 1] = k
    else if (!last || k.t > last.t)
        a.push(k)
    else
        return list
    return a.length > max ? a.slice(a.length - max) : a
}

// The 24 h tickers -> { SYMBOL: { last, pct, high, low } }
function parseTickers(json) {
    var a
    try { a = typeof json === "string" ? JSON.parse(json) : json } catch (e) { return null }
    if (!Array.isArray(a))
        a = a && a.symbol ? [a] : null
    if (!a)
        return null
    var out = {}
    for (var i = 0; i < a.length; i++)
        if (a[i] && a[i].symbol)
            out[a[i].symbol] = { last: +a[i].lastPrice, pct: +a[i].priceChangePercent, high: +a[i].highPrice, low: +a[i].lowPrice }
    return out
}

// A price, as many decimals as it needs: 97,120 · 3,412.55 · 70.79 · 0.1834 · 0.00001234
function fmtPrice(p) {
    if (p === null || p === undefined || !(p === p) || !isFinite(p))
        return "—"
    var a = Math.abs(p)
    var s
    if (a >= 1000) s = p.toFixed(0)
    else if (a >= 1) s = p.toFixed(2)
    else if (a >= 0.01) s = p.toFixed(4)
    else if (a === 0) s = "0"
    else s = p.toPrecision(4)                   // 0.00001234
    if (s.indexOf("e") >= 0)
        s = p.toFixed(10).replace(/0+$/, "")
    var parts = s.split(".")
    parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",")
    return parts.join(".")
}

// The change, with an arrow and in words, so up and down never rest on colour alone.
function fmtChange(pct) {
    var p = +pct || 0
    var up = p >= 0
    var n = Math.abs(p).toFixed(2) + "%"
    return { text: (up ? "▲ " : "▼ ") + n, words: (p === 0 ? "flat" : (up ? "up " : "down ") + n), up: up }
}

// The visible range of the chart: lows and highs with a little room, never zero tall.
function range(candles) {
    if (!candles || candles.length === 0)
        return { lo: 0, hi: 1 }
    var lo = Infinity, hi = -Infinity
    for (var i = 0; i < candles.length; i++) {
        if (candles[i].l < lo) lo = candles[i].l
        if (candles[i].h > hi) hi = candles[i].h
    }
    var pad = (hi - lo) * 0.08 || Math.abs(hi) * 0.001 || 1
    return { lo: lo - pad, hi: hi + pad }
}

// Up to `n` round price levels inside [lo, hi] for the grid (1, 2 or 5 times a power of ten).
function ticks(lo, hi, n) {
    var span = hi - lo
    if (!(span > 0))
        return []
    var raw = span / Math.max(1, n)
    var mag = Math.pow(10, Math.floor(Math.log(raw) / Math.LN10))
    var norm = raw / mag
    var step = (norm < 1.5 ? 1 : norm < 3 ? 2 : norm < 7 ? 5 : 10) * mag   // the nearest round step
    var out = []
    for (var v = Math.ceil(lo / step) * step; v <= hi; v += step)
        out.push(+v.toPrecision(12))
    return out
}

// The candle under x (0..width) when `count` candles share the width.
function indexAt(x, width, count) {
    if (count <= 0 || width <= 0)
        return -1
    return Math.max(0, Math.min(count - 1, Math.floor(x / (width / count))))
}

// "14:30" for intraday candles, "26 Nov" for daily ones
function timeLabel(t, interval) {
    var d = new Date(t)
    if (interval === "1d" || interval === "1w")
        return d.getDate() + " " + ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][d.getMonth()]
    return (d.getHours() < 10 ? "0" : "") + d.getHours() + ":" + (d.getMinutes() < 10 ? "0" : "") + d.getMinutes()
}

// The error a person reads: HTTP 451 / 403 is Binance refusing the region, 0 is no connection.
function errorWords(status) {
    if (status === 0)
        return "No connection to Binance"
    if (status === 451 || status === 403)
        return "Binance's market data isn't available from your region"
    if (status === 400)
        return "Binance doesn't know that pair"
    if (status === 429 || status === 418)
        return "Binance asked to slow down; trying again in a minute"
    return "Binance answered " + status
}
