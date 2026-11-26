import QtQuick
import "Radar.js" as RD

// The rain radar's data (docs/PLUGINS.md, "A service"): where (a place name looked up once with
// Open-Meteo's geocoding, the service the shell's weather card uses, or "lat, lon" as typed) and
// RainViewer's list of radar frames (the last ~2 hours, every 10 min), fetched again every
// 10 minutes while the widget is on screen. No account, no key. The tiles themselves are
// pictures the widget loads.
QtObject {
    id: svc
    required property var host

    property var place: null          // { lat, lon, label }
    property string host_: ""         // RainViewer's tile host
    property var frames: []
    property string error: ""
    property var fetchedAt: 0

    readonly property string query: String(svc.host.settings.place || "").trim()
    onQueryChanged: svc.locate()
    Component.onCompleted: svc.locate()

    function get(url, done) {
        const x = new XMLHttpRequest()
        x.onreadystatechange = () => { if (x.readyState === XMLHttpRequest.DONE) done(x.status, x.responseText) }
        x.open("GET", url)
        x.send()
    }

    function locate() {
        const c = RD.parseCoords(svc.query)
        if (c) {
            svc.place = { lat: c.lat, lon: c.lon, label: c.lat.toFixed(2) + ", " + c.lon.toFixed(2) }
            svc.error = ""
            return
        }
        if (svc.query === "") {
            svc.place = null
            svc.error = "Set a place in Settings > Desktop > Plugins > Rain Radar"
            return
        }
        const q = svc.query
        svc.get("https://geocoding-api.open-meteo.com/v1/search?count=1&name=" + encodeURIComponent(q), (status, text) => {
            if (q !== svc.query)
                return
            const p = status === 200 ? RD.geocoded(text) : null
            svc.place = p
            svc.error = p ? "" : status === 0 ? "No connection" : "Couldn't find “" + q + "” (try a city, or lat, lon)"
        })
    }

    function refresh() {
        svc.get("https://api.rainviewer.com/public/weather-maps.json", (status, text) => {
            const f = status === 200 ? RD.frames(text) : null
            if (f && f.frames.length) {
                svc.host_ = f.host
                svc.frames = f.frames
                svc.fetchedAt = Date.now()
                if (svc.place) svc.error = ""
            } else if (svc.frames.length === 0) {
                svc.error = status === 0 ? "No connection to RainViewer" : "RainViewer answered " + status
            }
        })
    }

    property Timer timer: Timer {
        interval: 600000
        repeat: true
        running: svc.host.working
        triggeredOnStart: true
        onTriggered: svc.refresh()
    }
}
