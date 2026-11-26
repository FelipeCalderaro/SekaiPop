.pragma library

// The Quick Panel's Idle & Sleep card (quickPanel/IdleDialog.qml): the steps its - / + keys go
// through, and how a time is said. The same settings as Settings > General > Idle & sleep
// (idle.lock, idle.screenOff, idle.sleep in minutes, 0 = never; idle.sleepAction); this card
// only steps through rounder values, so a few presses reach any common choice.
// Pure functions: tests/quick-idle-test/tst_idle_steps.qml.

var LOCK_STEPS = [0, 1, 2, 3, 5, 10, 15, 20, 30, 45, 60, 90, 120]
var SCREEN_STEPS = [0, 1, 2, 3, 5, 10, 15, 20, 30, 45, 60, 90, 120]
var SLEEP_STEPS = [0, 5, 10, 15, 20, 30, 45, 60, 90, 120, 180, 240]

function stepsFor(key) {
    return key === "idle.sleep" ? SLEEP_STEPS : (key === "idle.screenOff" ? SCREEN_STEPS : LOCK_STEPS)
}

// The next value from `current` in direction `dir` (+1 / -1). A value that isn't one of the steps
// (set to 7 in Settings) goes to the next step that way, not back to a round one behind it.
// At either end it stays.
function step(steps, current, dir) {
    var c = Math.round(+current || 0)
    if (dir > 0) {
        for (var i = 0; i < steps.length; i++)
            if (steps[i] > c)
                return steps[i]
        return steps[steps.length - 1]
    }
    for (var j = steps.length - 1; j >= 0; j--)
        if (steps[j] < c)
            return steps[j]
    return steps[0]
}

// 0 -> "Never", 5 -> "5 min", 60 -> "1 h", 90 -> "1 h 30 min"
function label(minutes) {
    var m = Math.round(+minutes || 0)
    if (m <= 0)
        return "Never"
    if (m < 60)
        return m + " min"
    var h = Math.floor(m / 60), r = m % 60
    return h + " h" + (r ? " " + r + " min" : "")
}

// The tile's second line: the first thing that will happen. Short, it is a pill's subtitle.
//   "Lock 5 min", "Screen off 10 min", "Sleep 30 min", "Never"
function summary(lock, screenOff, sleep, action) {
    var items = []
    if (lock > 0) items.push({ m: lock, w: "Lock" })
    if (screenOff > 0) items.push({ m: screenOff, w: "Screen off" })
    if (sleep > 0) items.push({ m: sleep, w: action === "hibernate" ? "Hibernate" : "Sleep" })
    if (items.length === 0)
        return "Never"
    items.sort(function (a, b) { return a.m - b.m })
    return items[0].w + " " + label(items[0].m)
}

// A warning in words when the order makes one of them pointless: the screen turning off after the
// machine already slept, or locking after it slept. "" when the order is fine.
function orderNote(lock, screenOff, sleep, action) {
    var sleepWord = action === "hibernate" ? "hibernates" : "sleeps"
    if (sleep > 0 && lock > 0 && lock > sleep)
        return "It " + sleepWord + " before it locks; the lock comes when it wakes."
    if (sleep > 0 && screenOff > 0 && screenOff >= sleep)
        return "It " + sleepWord + " before the screen would turn off."
    return ""
}
