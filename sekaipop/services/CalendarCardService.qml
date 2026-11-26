pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../modules/common/functions/EventMath.js" as EM
import qs.modules.common

// The desktop calendar card's state — the events and deadlines, where the card
// sits and whether it's shown — kept as its own singleton (like
// WeatherCardService.qml, TodoService.qml) so anything else can add an event
// without touching CalendarCardWidget.qml:
//
//   import qs.services
//   ...
//   CalendarCardService.add({ title: "Rehearsal", date: "2026-10-23", time: "14:00" })
//
// CalendarCardWidget.qml is the only thing that draws it. The events are yours,
// like the To-Do's tasks: they are not part of a desktop preset, and nothing
// here deletes one behind your back (no expiry). All the rules about what an
// event is — a real day, a title, a 24 h time, a colour 0..4, a deadline you can
// tick off — are in modules/common/functions/EventMath.js.
//
// `events` is a plain array that is replaced on every change (never edited in
// place), so everything that reads it re-reads it, and `byDay` — the same events
// grouped by date, for the month grid — is rebuilt with it.
//
// Persistence is the same convention as TodoService: a tiny shell script
// (calendarcard-state.sh) run as a Process. Position is saved straight away, the
// events are debounced.
Singleton {
    id: root

    // The events, in the order EventMath.sorted gives (date, all-day first, time): yours
    // (`mine`, the only ones saved) and the subscribed calendars' (`remote`, read-only,
    // `remote: true`, ids "g:N"), merged. Everything that draws reads this one.
    property var events: []
    property var mine: []

    // ===== subscribed calendars (Google, any .ics link) =====
    // scripts/calendar/ics-sync.py: the links live in ~/.config/sekaipop/calendars.json
    // (yours only, never in settings.json or a preset), the events it last fetched in
    // ~/.cache/sekaipop/calendar/events.json. Google Calendar: a calendar's Settings ->
    // Integrate calendar -> "Secret address in iCal format". No API key, no OAuth.
    //   calendars   [{ name, color, host }]  (never the link itself)
    //   syncErrors  [{ name, error }] from the last fetch
    //   syncedAt    "YYYY-MM-DD HH:MM" of the last fetch, "" = never
    //   syncing     a fetch is under way
    property var remote: []
    property var calendars: []
    property var syncErrors: []
    property string syncedAt: ""
    readonly property bool syncing: fetcher.running
    // How often the calendars are fetched again while the shell runs, in minutes.
    property int syncMinutes: 15
    readonly property string syncScript: Directories.script("calendar/ics-sync.py")
    // { "2026-10-23": [event, ...] }
    property var byDay: ({})
    readonly property int count: root.events.length
    readonly property bool full: root.mine.length >= EM.MAX_EVENTS

    // False until the saved state has been read. Nothing is written before
    // then, or a fresh start would overwrite what's on disk with an empty list.
    property bool loaded: false

    // Off until you add it (Edit Desktop, Settings -> Desktop, or the ipc): a
    // shell update must not put a new card over your desktop by itself.
    property bool shown: false       // ipc: calendarcard toggle / show / hide

    // The card's size. "full" is the card as it has always been; "2x2" is the footprint the
    // clock, user card and weather card share (320 x 276), so the cards line up as a set.
    // Remembered across restarts. Switch it in Settings -> Desktop, with the size key that
    // shows on the card while it is selected in Edit Desktop, or `ipc call calendarcard size 2x2|full`.
    property string size: "full"
    readonly property bool small: root.size === "2x2"
    property real posX: -1           // -1 = never placed; widget picks a default
    property real posY: -1
    // The shell scale (ShellScale) posX / posY were saved at, in design pixels
    // (same idea as WeatherCardService): 0 = saved before this was kept.
    property real posScale: 0
    // The monitor (output name, e.g. "DP-1") the card was last dropped on.
    // Empty = never dropped yet (the widget uses the first screen).
    property string screenName: ""

    // ===== events =====
    function setEvents(list) {
        root.mine = EM.sorted(list)
        root.rebuild()
    }

    function rebuild() {
        const s = EM.sorted(root.mine.concat(root.remote))
        root.events = s
        root.byDay = EM.byDay(s)
    }

    // An event from a subscribed calendar: shown, never changed from here.
    function isRemote(e) {
        return !!e && e.remote === true
    }

    // The fetch's events -> the card's shape (EventMath.clean), each marked remote.
    function setRemote(list) {
        const out = []
        const src = Array.isArray(list) ? list : []
        for (let i = 0; i < src.length && out.length < 3000; i++) {
            const c = EM.clean(src[i])
            if (!c)
                continue
            c.id = "g:" + i
            c.remote = true
            c.src = typeof src[i].src === "string" ? src[i].src : ""
            out.push(c)
        }
        root.remote = out
        root.rebuild()
    }

    function applyFetch(text) {
        try {
            const r = JSON.parse(text)
            root.setRemote(r.events)
            root.syncErrors = Array.isArray(r.errors) ? r.errors : []
            root.syncedAt = typeof r.at === "string" ? r.at : ""
        } catch (e) {
            // A half-written cache or a crashed fetch: keep what is shown.
        }
    }

    function sync() {
        if (!fetcher.running && root.calendars.length > 0)
            fetcher.running = true
    }

    function refreshCalendars() {
        if (!lister.running)
            lister.running = true
    }

    // Adds a calendar from its secret link. The link goes to the script on stdin, so it
    // never shows in the process list. done(error): "" when it worked.
    property var addDone: null
    function addCalendar(name, url, done) {
        if (adder.running)
            return
        root.addDone = done || null
        adder.name = String(name || "").trim() || "Calendar"
        adder.url = String(url || "").trim()
        adder.running = true
    }

    function removeCalendar(index) {
        Quickshell.execDetached(["python3", "-I", root.syncScript, "remove", String(index)])
        // Its events go at the next fetch; drop them from the card now too.
        const gone = root.calendars[index] ? root.calendars[index].name : ""
        root.calendars = root.calendars.filter((c, i) => i !== index)
        root.setRemote(root.remote.filter(e => e.src !== gone))
        relistTimer.restart()
    }

    Timer {
        id: relistTimer
        interval: 400
        onTriggered: { root.refreshCalendars(); root.sync() }
    }

    Process {
        id: lister
        running: true
        command: ["python3", "-I", root.syncScript, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const l = JSON.parse(text)
                    root.calendars = Array.isArray(l) ? l : []
                } catch (e) {
                    root.calendars = []
                }
                // First list at startup: fetch fresh once the cached events are up.
                if (!root.startedSync) {
                    root.startedSync = true
                    root.sync()
                }
            }
        }
    }
    property bool startedSync: false

    // What the last fetch found, so the card is full straight away at startup.
    Process {
        running: true
        command: ["python3", "-I", root.syncScript, "cached"]
        stdout: StdioCollector {
            onStreamFinished: root.applyFetch(text)
        }
    }

    Process {
        id: fetcher
        command: ["python3", "-I", root.syncScript, "fetch"]
        stdout: StdioCollector {
            onStreamFinished: root.applyFetch(text)
        }
    }

    Process {
        id: adder
        property string name: ""
        property string url: ""
        stdinEnabled: true
        command: ["python3", "-I", root.syncScript, "add", adder.name]
        onStarted: {
            adder.write(adder.url + "\n")
            adder.url = ""
            adder.stdinEnabled = false
        }
        stderr: StdioCollector {
            id: adderErr
        }
        onExited: (code) => {
            adder.stdinEnabled = true
            const done = root.addDone
            root.addDone = null
            if (done)
                done(code === 0 ? "" : (adderErr.text.trim() || "couldn't add it"))
            if (code === 0) {
                root.refreshCalendars()
                fetchSoon.restart()
            }
        }
    }

    Timer {
        id: fetchSoon
        interval: 500
        onTriggered: root.sync()
    }

    Timer {
        interval: Math.max(5, root.syncMinutes) * 60000
        repeat: true
        running: root.calendars.length > 0
        onTriggered: root.sync()
    }

    function find(id) {
        for (const e of root.events) {
            if (e.id === id)
                return e
        }
        return null
    }

    // Adds one event ({ title, date, time?, note?, color?, kind? }). Returns its
    // id, or "" when it is not an event (no title, not a real day) or the list
    // is full.
    function add(fields) {
        if (!root.loaded || root.full)
            return ""
        const c = EM.clean(fields)
        if (!c)
            return ""
        c.id = EM.newId(root.mine)
        root.setEvents(root.mine.concat([c]))
        root.persist()
        return c.id
    }

    // Changes some fields of an event. Returns whether anything changed; an
    // edit that would make it not an event (blank title, bad day) is refused
    // and the event stays as it was.
    function update(id, fields) {
        const old = root.find(id)
        if (!old || root.isRemote(old))
            return false
        const next = EM.changed(old, fields)
        if (!next)
            return false
        root.setEvents(root.mine.map(e => e.id === id ? next : e))
        root.persist()
        return true
    }

    function setDone(id, done) {
        return root.update(id, { done: done === true })
    }

    function remove(id) {
        const e = root.find(id)
        if (!e || root.isRemote(e))
            return false
        root.setEvents(root.mine.filter(e => e.id !== id))
        root.persist()
        return true
    }

    // ===== card =====
    // Saved straight away (no wait): a refresh or reload right after you drop
    // the card must not be able to beat the save.
    function setPosition(x, y, screen, scale) {
        if (!root.loaded)
            return
        root.posX = x
        root.posY = y
        if (typeof scale === "number" && scale > 0)
            root.posScale = scale
        if (typeof screen === "string" && screen !== "")
            root.screenName = screen
        saveTimer.stop()
        saver.save(root.snapshot())
    }

    function setShown(value) {
        root.shown = value
        root.persist()
    }

    // "2x2" (or "small") and "full"; anything else is "full".
    function setSize(value) {
        const v = (value === "2x2" || value === "small") ? "2x2" : "full"
        if (v === root.size)
            return
        root.size = v
        root.persist()
    }

    function toggleSize() {
        root.setSize(root.small ? "full" : "2x2")
    }

    // ===== persistence =====
    readonly property string script: Directories.script("state/calendarcard-state.sh")

    function snapshot() {
        return JSON.stringify({
            x: root.posX,
            y: root.posY,
            scale: root.posScale,
            screen: root.screenName,
            shown: root.shown,
            size: root.size,
            events: root.mine
        })
    }

    function restore(text) {
        try {
            const s = JSON.parse(text)
            if (typeof s.x === "number")
                root.posX = s.x
            if (typeof s.y === "number")
                root.posY = s.y
            if (typeof s.scale === "number" && s.scale > 0)
                root.posScale = s.scale
            if (typeof s.screen === "string")
                root.screenName = s.screen
            root.shown = s.shown !== false
            root.size = s.size === "2x2" ? "2x2" : "full"
            root.setEvents(EM.parseAll(s.events))
        } catch (e) {
            // No file yet (first run) or an unreadable one: start with none.
        }
        root.loaded = true
    }

    // Runs once, at startup.
    Process {
        running: true
        command: ["sh", root.script, "load"]
        stdout: StdioCollector {
            onStreamFinished: root.restore(text)
        }
    }

    function persist() {
        if (root.loaded)
            saveTimer.restart()
    }

    Timer {
        id: saveTimer
        interval: 300
        onTriggered: saver.save(root.snapshot())
    }

    // Fire-and-forget save. Queues at most one pending snapshot behind an
    // in-flight save rather than dropping it, so the *last* state is what
    // ends up on disk (same reasoning as TodoService's `saver`).
    Process {
        id: saver

        property var pending: null

        function save(json) {
            if (saver.running) {
                saver.pending = json
                return
            }
            saver.pending = null
            saver.exec(["sh", root.script, "save", json])
        }

        onExited: {
            if (saver.pending !== null) {
                const json = saver.pending
                saver.pending = null
                saver.exec(["sh", root.script, "save", json])
            }
        }
    }
}
