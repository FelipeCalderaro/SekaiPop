import QtQuick
import QtTest
import "../CoverWall.js" as CW

// qmltestrunner -platform offscreen -input plugins/cover-wall/tests
TestCase {
    name: "CoverWall"

    function track(title, album, artist, art) {
        return { title: title, album: album, artist: artist, art: art === undefined ? "https://x/" + title + ".jpg" : art, player: "spotify" }
    }

    function test_album_key() {
        compare(CW.albumKey(track("A", "Album", "Me")), CW.albumKey(track("B", "album", "me")), "two songs of one album")
        verify(CW.albumKey(track("Single", "", "Me")) !== CW.albumKey(track("Other", "", "Me")), "singles are their own")
    }

    function test_art() {
        verify(CW.usableArt("https://i.scdn.co/image/ab"))
        verify(CW.usableArt("file:///tmp/cover.png"))
        verify(CW.usableArt("data:image/png;base64,AAAA"))
        verify(!CW.usableArt(""))
        verify(!CW.usableArt("spotify:image:ab"))
    }

    function test_remember() {
        let h = []
        h = CW.remember(h, track("1", "A", "x"), 1, 3)
        h = CW.remember(h, track("2", "B", "x"), 2, 3)
        h = CW.remember(h, track("3", "A", "x"), 3, 3)
        compare(h.length, 2, "album A moved to the front, not added twice")
        compare(h[0].title, "3")
        h = CW.remember(h, track("4", "C", "x"), 4, 3)
        h = CW.remember(h, track("5", "D", "x"), 5, 3)
        compare(h.length, 3, "kept to max")
        compare(h.map(e => e.album).join(""), "DCA", "newest first; the oldest (B) fell off")
        compare(CW.remember(h, track("6", "E", "x", ""), 6, 3), h, "no cover: not added")
    }

    function test_load_is_forgiving() {
        compare(CW.load("not json", 5).length, 0)
        compare(CW.load('{"a":1}', 5).length, 0)
        const ok = CW.load(JSON.stringify([{ key: "k", title: "t", art: "https://a" }, { key: 1 }, null]), 5)
        compare(ok.length, 1)
    }

    function test_search_url() {
        const e = { title: "Song", album: "Album Name", artist: "Me & You" }
        compare(CW.searchUrl("spotify", e), "https://open.spotify.com/search/Album%20Name%20Me%20%26%20You")
        compare(CW.searchUrl("youtube", e), "https://music.youtube.com/search?q=Album%20Name%20Me%20%26%20You")
        compare(CW.searchUrl("off", e), "")
    }

    function test_subtitle() {
        compare(CW.subtitle({ album: "A", artist: "B" }), "A · B")
        compare(CW.subtitle({ album: "", artist: "B" }), "B")
    }
}
