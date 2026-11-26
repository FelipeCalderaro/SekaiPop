.pragma library
// playing album 3, with seven covers on the wall
function service(Qt) {
    var here = Qt.resolvedUrl(".").toString()
    var names = ["Hibana", "Sekai", "Tell Your World", "Ready Steady", "Unknown Mother Goose", "Rokuchounen", "Senbonzakura"]
    var hist = names.map(function (n, i) { return { key: "k" + i, title: n, album: n, artist: "Various", art: here + "covers/c" + (i + 1) + ".png" } })
    return {
        now: { title: "Tell Your World", artist: "livetune", album: "Tell Your World EP", art: here + "covers/c3.png" },
        nowKey: "k2", playing: true, canNext: true, canToggle: true, history: hist,
        togglePlaying: function () {}, next: function () {}
    }
}
