.pragma library
// Berlin, with a real frame list saved from RainViewer (radar-maps.json). The tiles load from the
// network when the render runs; without one, the map stays empty and the rest still draws.
function service(Qt) {
    var x = new XMLHttpRequest()
    x.open("GET", Qt.resolvedUrl("radar-maps.json"), false)
    x.send()
    var d = JSON.parse(x.responseText)
    var frames = d.radar.past.map(function (f) { return { time: f.time, path: f.path, forecast: false } })
    return { place: { lat: 52.52, lon: 13.41, label: "Berlin, DE" }, host_: d.host, frames: frames, error: "", refresh: function () {} }
}
