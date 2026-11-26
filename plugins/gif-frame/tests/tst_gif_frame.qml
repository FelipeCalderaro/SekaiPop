import QtQuick
import QtTest
import "../GifFrame.js" as GF

// qmltestrunner -platform offscreen -input plugins/gif-frame/tests
TestCase {
    name: "GifFrame"

    function test_pictures() {
        verify(GF.isPicture("a.GIF"))
        verify(GF.isPicture("/x/y.webp"))
        verify(!GF.isPicture("notes.txt"))
        verify(!GF.isPicture("folder"))
    }

    function test_expand() {
        compare(GF.expand("~/Pictures", "/home/me"), "/home/me/Pictures")
        compare(GF.expand("'/tmp/a b.gif'", "/home/me"), "/tmp/a b.gif", "quotes from a file manager's copy")
        compare(GF.expand("file:///tmp/a%20b.gif", "/home/me"), "/tmp/a b.gif")
        compare(GF.expand("  ", "/home/me"), "")
    }

    function test_folder_or_file() {
        verify(GF.isFolder("/home/me/Pictures"))
        verify(!GF.isFolder("/home/me/cat.gif"))
        verify(!GF.isFolder(""))
    }

    function test_pick_never_repeats() {
        const list = ["a.gif", "b.gif", "notes.txt"]
        for (let r = 0; r < 1; r += 0.1)
            compare(GF.pickNext(list, "a.gif", r), "b.gif", "the other one, whatever the dice")
        compare(GF.pickNext(["only.gif"], "only.gif", 0.5), "only.gif", "one file: it stays")
        compare(GF.pickNext(["x.txt"], "", 0.5), "", "nothing to show")
        compare(GF.pickNext(["a.gif", "b.gif", "c.gif"], "", 0.99), "c.gif")
    }

    function test_box_height_is_sane() {
        compare(GF.boxHeight(200, 0, 0), 150, "unknown size: 3:4")
        compare(GF.boxHeight(200, 400, 300), 150)
        compare(GF.boxHeight(200, 1000, 100), 80, "a ribbon is kept to 0.4")
        compare(GF.boxHeight(200, 100, 1000), 320, "a pillar is kept to 1.6")
    }

    function test_caption() {
        compare(GF.caption("Hi", "/a/b.gif", true), "Hi")
        compare(GF.caption("", "/a/my_cat-video.gif", true), "my cat video")
        compare(GF.caption("", "/a/b.gif", false), "")
    }
}
