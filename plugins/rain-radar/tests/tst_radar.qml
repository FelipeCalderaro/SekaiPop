import QtQuick
import QtTest
import "../Radar.js" as RD

// qmltestrunner -platform offscreen -input plugins/rain-radar/tests
TestCase {
    name: "Radar"

    function test_coords() {
        compare(RD.parseCoords("52.52, 13.41").lat, 52.52)
        compare(RD.parseCoords("-33.9 151.2").lon, 151.2)
        compare(RD.parseCoords("Berlin"), null)
        compare(RD.parseCoords("95, 10"), null, "off the map")
    }

    function test_zoom_is_kept_to_the_free_tiles() {
        compare(RD.clampZoom(12), 7)
        compare(RD.clampZoom(1), 3)
        compare(RD.clampZoom("x"), 5)
    }

    function test_tile_math() {
        const c = RD.tileXY(0, 0, 1)
        compare(c.x, 1)
        verify(Math.abs(c.y - 1) < 1e-9, "the equator and prime meridian are the middle of the world")
        const b = RD.tileXY(52.52, 13.41, 6)
        compare(Math.floor(b.x), 34)
        compare(Math.floor(b.y), 20, "y = 20.99 at zoom 6")
    }

    function test_layout_covers_the_view() {
        const tiles = RD.layout(52.52, 13.41, 6, 340, 240)
        verify(tiles.length >= 4 && tiles.length <= 9)
        // the centre point lands in the middle of the view
        const c = RD.tileXY(52.52, 13.41, 6)
        const t = tiles.find(t => t.x === Math.floor(c.x) && t.y === Math.floor(c.y))
        verify(t !== undefined)
        verify(Math.abs(t.left + (c.x - Math.floor(c.x)) * 256 - 170) <= 1)
        verify(Math.abs(t.top + (c.y - Math.floor(c.y)) * 256 - 120) <= 1)
        // across the date line, x wraps
        verify(RD.layout(0, 179.9, 3, 600, 200).some(t => t.x === 0))
        verify(RD.layout(0, 179.9, 3, 600, 200).every(t => t.x >= 0 && t.x < 8))
    }

    function test_frames_and_urls() {
        const f = RD.frames('{"host":"https://tc.example","radar":{"past":[{"time":100,"path":"/v2/radar/a"}],"nowcast":[{"time":700,"path":"/v2/radar/b"}]}}')
        compare(f.frames.length, 2)
        verify(f.frames[1].forecast)
        compare(RD.radarUrl(f.host, "/v2/radar/a", 6, 34, 21, 2, true, false), "https://tc.example/v2/radar/a/256/6/34/21/2/1_0.png")
        compare(RD.baseUrl(false, 6, 34, 21), "https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer/tile/6/21/34", "Esri wants z/y/x")
        compare(RD.frames("nope"), null)
    }

    function test_words() {
        const now = 1000 * 1000
        compare(RD.frameWords(1000, now), "now")
        compare(RD.frameWords(1000 - 1200, now), "20 min ago")
        compare(RD.frameWords(1000 + 600, now), "in 10 min")
        const g = RD.geocoded('{"results":[{"name":"Berlin","latitude":52.5,"longitude":13.4,"country_code":"DE"}]}')
        compare(g.label, "Berlin, DE")
        compare(RD.geocoded('{"results":[]}'), null)
    }
}
