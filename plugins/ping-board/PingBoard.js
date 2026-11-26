.pragma library

// The ping board's logic: pure functions, tested by tests/tst_ping_board.qml.

// The "hosts" setting: one per line, "address [label]". An address is a host name, an IPv4 or an
// IPv6 address; anything else is left out (it is handed to ping as an argument, never to a shell,
// but there is no reason to pass on junk). At most 6.
function parseHosts(text) {
    var out = []
    var lines = String(text || "").split("\n")
    for (var i = 0; i < lines.length && out.length < 6; i++) {
        var s = lines[i].trim()
        if (s === "" || s.charAt(0) === "#")
            continue
        var parts = s.split(/\s+/)
        var addr = parts[0]
        if (!/^[A-Za-z0-9:][A-Za-z0-9.:-]{0,252}$/.test(addr))
            continue
        out.push({ address: addr, label: parts.slice(1).join(" ") || addr })
    }
    return out
}

// One line of the service's ping script: "<address> <ms>" or "<address> -" (no answer).
function parseResult(line) {
    var m = String(line || "").trim().match(/^(\S+)\s+(\S+)$/)
    if (!m)
        return null
    var ms = m[2] === "-" ? null : parseFloat(m[2])
    if (ms !== null && !(ms >= 0))
        return null
    return { address: m[1], ms: ms }
}

// Add one answer (ms or null) to a history, keeping the last `keep`.
function push(samples, ms, keep) {
    var next = (samples || []).concat([ms])
    return next.length > keep ? next.slice(next.length - keep) : next
}

// { last, avg, min, max, jitter, loss (0..100), count }. null samples are lost answers.
function stats(samples) {
    var got = (samples || []).filter(function (x) { return x !== null && x !== undefined })
    var n = (samples || []).length
    var r = { last: n ? samples[n - 1] : null, avg: null, min: null, max: null, jitter: null,
              loss: n ? Math.round(100 * (n - got.length) / n) : 0, count: n, trailingLost: 0 }
    for (var k = n - 1; k >= 0 && (samples[k] === null || samples[k] === undefined); k--)
        r.trailingLost++
    if (got.length) {
        var sum = 0, min = got[0], max = got[0], jit = 0
        for (var i = 0; i < got.length; i++) {
            sum += got[i]
            if (got[i] < min) min = got[i]
            if (got[i] > max) max = got[i]
            if (i > 0) jit += Math.abs(got[i] - got[i - 1])
        }
        r.avg = sum / got.length
        r.min = min
        r.max = max
        r.jitter = got.length > 1 ? jit / (got.length - 1) : 0
    }
    return r
}

// "12 ms", "0.8 ms", "No answer"
function msText(ms) {
    if (ms === null || ms === undefined)
        return "No answer"
    return (ms < 10 ? ms.toFixed(1) : String(Math.round(ms))) + " ms"
}

// How it's doing, in words: { word, warn }. warn = amber ("look"), never red: the design system
// keeps red for harm, and a slow ping is not harm.
function verdict(st) {
    if (st.count === 0)
        return { word: "Waiting", warn: false }
    if (st.trailingLost >= 3 || (st.last === null && st.loss >= 50))
        return { word: "Down", warn: true }
    if (st.loss >= 5)
        return { word: st.loss + "% lost", warn: true }
    if (st.avg !== null && st.avg > 150)
        return { word: "Slow", warn: true }
    if (st.jitter !== null && st.jitter > 30)
        return { word: "Jumpy", warn: true }
    return { word: "OK", warn: false }
}

// Bar heights 0..1 for the graph: each answer against the slowest in view (at least `floor` ms,
// so a quiet line stays low instead of filling the graph with noise). Lost answers -> -1.
function bars(samples, floor) {
    var got = (samples || []).filter(function (x) { return x !== null && x !== undefined })
    var top = Math.max(floor || 50, got.length ? Math.max.apply(null, got) : 0)
    return (samples || []).map(function (x) { return x === null || x === undefined ? -1 : Math.max(0.06, x / top) })
}

// curl's speed_download / speed_upload (bytes per second) -> "312 Mbps" / "8.4 Mbps"
function mbps(bytesPerSec) {
    var v = (parseFloat(bytesPerSec) || 0) * 8 / 1e6
    return (v < 10 ? v.toFixed(1) : String(Math.round(v))) + " Mbps"
}

// "just now", "4 min ago", "2 h ago"
function ago(then, now) {
    if (!then)
        return ""
    var s = Math.max(0, Math.round((now - then) / 1000))
    if (s < 60) return "just now"
    if (s < 3600) return Math.round(s / 60) + " min ago"
    if (s < 86400) return Math.round(s / 3600) + " h ago"
    return Math.round(s / 86400) + " d ago"
}
