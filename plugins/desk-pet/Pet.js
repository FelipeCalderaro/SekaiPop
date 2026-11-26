.pragma library

// The desk pet's behaviour: one pure step function, tested by tests/tst_pet.qml.
//
// A state is { mode, x, target, until, facing }:
//   mode    "sit" | "walk" | "dance" | "sleep" | "happy"
//   x       where it stands, 0 (left end of its strip) .. 1 (right end)
//   target  where a walk goes
//   until   when the current mode ends (ms), for sit / walk / happy
//   facing  -1 left, 1 right
// The widget animates x itself over the walk's duration; step() only decides.
//
// Priority: a click's "happy" first, then sleep (you are idle), then dance (music plays), then
// wandering: sit a few seconds, walk somewhere, sit again.

var WALK_MS_PER_STRIP = 9000      // crossing the whole strip takes 9 s

function start(now) {
    return { mode: "sit", x: 0.5, target: 0.5, until: now + 2000, facing: 1 }
}

function walkMs(from, to) {
    return Math.max(600, Math.round(Math.abs(to - from) * WALK_MS_PER_STRIP))
}

// inp: { now, playing, idle, rnd: () => [0, 1), clicked }
function step(st, inp) {
    var s = { mode: st.mode, x: st.x, target: st.target, until: st.until, facing: st.facing }
    var now = inp.now

    if (inp.clicked) {
        s.mode = "happy"
        s.until = now + 1400
        s.target = s.x
        return s
    }
    if (s.mode === "happy" && now < s.until)
        return s
    if (inp.idle) {
        if (s.mode === "walk")           // stop where it is (the widget's x is close enough)
            s.x = s.target
        s.mode = "sleep"
        return s
    }
    if (inp.playing) {
        if (s.mode === "walk")
            s.x = s.target
        s.mode = "dance"
        return s
    }
    // wandering
    if (s.mode === "sleep" || s.mode === "dance" || s.mode === "happy") {
        s.mode = "sit"
        s.until = now + 1500
        return s
    }
    if (s.mode === "walk") {
        if (now >= s.until) {
            s.x = s.target
            s.mode = "sit"
            s.until = now + 2000 + Math.round(inp.rnd() * 4000)
        }
        return s
    }
    // sit
    if (now >= s.until) {
        var t = inp.rnd()
        if (Math.abs(t - s.x) < 0.15)            // not a shuffle on the spot
            t = s.x < 0.5 ? Math.min(1, s.x + 0.35) : Math.max(0, s.x - 0.35)
        s.target = t
        s.facing = t < s.x ? -1 : 1
        s.mode = "walk"
        s.until = now + walkMs(s.x, t)
    }
    return s
}

// What its name tag says under it, per mode (words, not only a pose)
function mood(mode) {
    return { sit: "", walk: "", dance: "♪", sleep: "Zz", happy: "♥" }[mode] || ""
}
