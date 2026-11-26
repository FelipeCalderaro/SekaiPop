import QtQuick
import QtTest
import "../PingBoard.js" as PB

// qmltestrunner -platform offscreen -input plugins/ping-board/tests
TestCase {
    name: "PingBoard"

    function test_hosts() {
        const h = PB.parseHosts("1.1.1.1 Cloudflare\n# off\n\nexample.org\n::1 Local six\n$(rm -rf ~) bad\n-c 9 flag")
        compare(h.length, 3, "a shell trick and a flag-looking word are left out")
        compare(h[0].label, "Cloudflare")
        compare(h[1].label, "example.org", "no name: the address")
        compare(h[2].address, "::1")
        compare(PB.parseHosts("a\nb\nc\nd\ne\nf\ng").length, 6, "at most 6")
    }

    function test_results() {
        compare(PB.parseResult("1.1.1.1 11.4").ms, 11.4)
        compare(PB.parseResult("1.1.1.1 -").ms, null)
        compare(PB.parseResult("garbage"), null)
    }

    function test_push_keeps_last() {
        let s = []
        for (let i = 0; i < 40; i++)
            s = PB.push(s, i, 30)
        compare(s.length, 30)
        compare(s[29], 39)
    }

    function test_stats_and_words() {
        const st = PB.stats([10, 20, null, 30])
        compare(st.loss, 25)
        compare(st.avg, 20)
        compare(st.jitter, 10)
        compare(PB.verdict(st).word, "25% lost")
        verify(PB.verdict(st).warn)
        compare(PB.verdict(PB.stats([10, 11, 12])).word, "OK")
        compare(PB.verdict(PB.stats([10, 11, null, null, null])).word, "Down", "three misses in a row")
        compare(PB.verdict(PB.stats([200, 210, 190])).word, "Slow")
        compare(PB.verdict(PB.stats([])).word, "Waiting")
    }

    function test_text() {
        compare(PB.msText(null), "No answer")
        compare(PB.msText(0.84), "0.8 ms")
        compare(PB.msText(123.6), "124 ms")
        compare(PB.mbps(39000000), "312 Mbps")
        compare(PB.mbps(1050000), "8.4 Mbps")
        compare(PB.ago(1000, 1000 + 30000), "just now")
        compare(PB.ago(1000, 1000 + 4 * 60000), "4 min ago")
    }

    function test_bars() {
        const b = PB.bars([10, null, 100], 50)
        compare(b[1], -1, "a lost answer")
        compare(b[2], 1)
        verify(Math.abs(PB.bars([10], 50)[0] - 0.2) < 1e-9, "a quiet line stays low")
    }
}
