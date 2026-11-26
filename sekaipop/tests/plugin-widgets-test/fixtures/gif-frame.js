.pragma library
// the sample GIF next to this file, in a polaroid with a caption
function settings() {
    var here = Qt.resolvedUrl(".").toString().replace("file://", "")
    return { source: here + "sample.gif", caption: "Ichika's day off", tilt: -3 }
}
