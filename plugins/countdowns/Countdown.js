.pragma library

// The countdowns plugin's logic: pure functions, tested by tests/tst_countdown.qml
// (qmltestrunner). No dates are read here; `now` is always passed in.
//
// One line of the "events" setting is one countdown:
//   2026-12-24 Christmas            a day
//   2026-12-24 18:30 Concert        a day and a time
//   12-24 Birthday                  every year (month-day): the next one
// Empty lines and lines starting with # are skipped.

function pad(n) { return (n < 10 ? "0" : "") + n }

// One line -> { title, date (Date), allDay, yearly } | null (not understood) | undefined (skip)
function parseLine(line, now) {
    var s = String(line || "").trim()
    if (s === "" || s.charAt(0) === "#")
        return undefined
    var m = s.match(/^(\d{4})-(\d{1,2})-(\d{1,2})(?:[ T](\d{1,2}):(\d{2}))?\s+(.+)$/)
    if (m) {
        var y = +m[1], mo = +m[2], d = +m[3]
        var hasTime = m[4] !== undefined
        var date = new Date(y, mo - 1, d, hasTime ? +m[4] : 0, hasTime ? +m[5] : 0, 0, 0)
        if (date.getMonth() !== mo - 1 || date.getDate() !== d || (hasTime && (+m[4] > 23)))
            return null
        return { title: m[6].trim(), date: date, allDay: !hasTime, yearly: false }
    }
    m = s.match(/^(\d{1,2})-(\d{1,2})\s+(.+)$/)
    if (m) {
        var mo2 = +m[1], d2 = +m[2]
        if (mo2 < 1 || mo2 > 12 || d2 < 1 || d2 > 31)
            return null
        var next = new Date(now.getFullYear(), mo2 - 1, d2)
        if (next.getMonth() !== mo2 - 1)           // 02-30 and the like
            return null
        var today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
        if (next < today)
            next = new Date(now.getFullYear() + 1, mo2 - 1, d2)
        return { title: m[3].trim(), date: next, allDay: true, yearly: true }
    }
    return null
}

// The text -> { items: [...] sorted soonest first, still to come (today counts), bad: n }
function parse(text, now, showPast) {
    var lines = String(text || "").split("\n")
    var items = [], bad = 0
    var today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
    for (var i = 0; i < lines.length; i++) {
        var it = parseLine(lines[i], now)
        if (it === undefined)
            continue
        if (it === null) { bad++; continue }
        var end = it.allDay ? new Date(it.date.getFullYear(), it.date.getMonth(), it.date.getDate() + 1) : it.date
        if (!showPast && end <= now && !(it.allDay && sameDay(it.date, today)))
            continue
        items.push(it)
    }
    items.sort(function (a, b) { return a.date - b.date })
    return { items: items, bad: bad }
}

function sameDay(a, b) {
    return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate()
}

// Whole calendar days from today to the item's day (not 24-hour blocks: 23:00 -> 01:00 is 1 day).
function daysUntil(date, now) {
    var a = Date.UTC(now.getFullYear(), now.getMonth(), now.getDate())
    var b = Date.UTC(date.getFullYear(), date.getMonth(), date.getDate())
    return Math.round((b - a) / 86400000)
}

// What the sticker says: { big: "12", unit: "days", words: "In 12 days" }. Words, not colour,
// carry the meaning, so it reads in Monochrome.
function label(item, now) {
    var days = daysUntil(item.date, now)
    if (days < 0)
        return { big: String(-days), unit: -days === 1 ? "day ago" : "days ago", words: (-days) + (-days === 1 ? " day ago" : " days ago") }
    if (!item.allDay && days <= 1) {
        var mins = Math.round((item.date - now) / 60000)
        if (mins <= 0)
            return { big: "Now", unit: "", words: "Now" }
        if (mins < 60)
            return { big: String(mins), unit: "min", words: "In " + mins + " min" }
        if (mins < 24 * 60) {
            var h = Math.floor(mins / 60)
            return { big: String(h), unit: h === 1 ? "hour" : "hours", words: "In " + h + " h " + (mins % 60) + " min" }
        }
    }
    if (days === 0)
        return { big: "Today", unit: "", words: "Today" }
    if (days === 1)
        return { big: "1", unit: "day", words: "Tomorrow" }
    return { big: String(days), unit: "days", words: "In " + days + " days" }
}

var MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
var DAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

// "Thu 24 Dec · 18:30" (the year only when it isn't this one)
function dateText(item, now, use24h) {
    var d = item.date
    var s = DAYS[d.getDay()] + " " + d.getDate() + " " + MONTHS[d.getMonth()]
    if (d.getFullYear() !== now.getFullYear())
        s += " " + d.getFullYear()
    if (!item.allDay) {
        var h = d.getHours()
        s += " · " + (use24h ? pad(h) + ":" + pad(d.getMinutes())
                             : ((h % 12) || 12) + ":" + pad(d.getMinutes()) + (h < 12 ? " AM" : " PM"))
    }
    if (item.yearly)
        s += " · yearly"
    return s
}

// How far along the wait is, 0..1, for the bar under the first sticker: from `from` (when it was
// added, or 30 days before for anything further) to the date.
function progress(item, now, spanDays) {
    var span = (spanDays || 30) * 86400000
    var left = item.date - now
    if (left <= 0)
        return 1
    return Math.max(0, Math.min(1, 1 - left / span))
}
