import QtQuick
import QtTest
import "../Market.js" as MK

// qmltestrunner -platform offscreen -input plugins/market-ticker/tests
TestCase {
    name: "Market"

    function test_symbols() {
        compare(MK.parseSymbols("btcusdt eth-usdt, SOL/USDT BTCUSDT x $(ls)"), ["BTCUSDT", "ETHUSDT", "SOLUSDT"])
        compare(MK.parseSymbols("A1111 A2222 A3333 A4444 A5555 A6666 A7777 A8888 A9999").length, 8)
        verify(!MK.validSymbol("btcusdt"), "symbols are upper case by the time they are used")
    }

    function test_split_and_label() {
        compare(MK.pairLabel("BTCUSDT"), "BTC / USDT")
        compare(MK.pairLabel("ETHBTC"), "ETH / BTC")
        compare(MK.split("DOGEFDUSD").base, "DOGE")
        compare(MK.pairLabel("WEIRDPAIR"), "WEIRDPAIR")
    }

    function test_klines_and_stream() {
        const k = MK.parseKlines('[[1000,"1.0","2.0","0.5","1.5","10",1999]]')
        compare(k.length, 1)
        compare(k[0].c, 1.5)
        compare(MK.parseKlines("nope"), null)
        const st = MK.parseStream('{"e":"kline","k":{"t":2000,"o":"1.5","h":"3","l":"1","c":"2.5","v":"4"}}')
        compare(st.t, 2000)
        compare(st.h, 3)
        compare(MK.parseStream('{"e":"trade"}'), null)
    }

    function test_apply_candle() {
        let c = [{ t: 1, c: 1 }, { t: 2, c: 2 }]
        c = MK.applyCandle(c, { t: 2, c: 2.5 }, 3)
        compare(c.length, 2, "the forming candle is replaced")
        compare(c[1].c, 2.5)
        c = MK.applyCandle(c, { t: 3, c: 3 }, 3)
        c = MK.applyCandle(c, { t: 4, c: 4 }, 3)
        compare(c.map(x => x.t).join(","), "2,3,4", "kept to max")
        compare(MK.applyCandle(c, { t: 1, c: 9 }, 3), c, "an older candle is ignored")
    }

    function test_tickers() {
        const t = MK.parseTickers('[{"symbol":"BTCUSDT","lastPrice":"97120.5","priceChangePercent":"-1.25","highPrice":"99000","lowPrice":"95000"}]')
        compare(t.BTCUSDT.pct, -1.25)
        compare(MK.parseTickers("{}"), null)
    }

    function test_prices() {
        compare(MK.fmtPrice(97120.49), "97,120")
        compare(MK.fmtPrice(3412.555), "3,413")
        compare(MK.fmtPrice(70.789), "70.79")
        compare(MK.fmtPrice(0.18341), "0.1834")
        compare(MK.fmtPrice(0.00001234), "0.00001234")
        compare(MK.fmtPrice(NaN), "—")
    }

    function test_change_in_words() {
        compare(MK.fmtChange(2.153).text, "▲ 2.15%")
        compare(MK.fmtChange(-0.4).words, "down 0.40%")
        compare(MK.fmtChange(0).words, "flat")
        verify(!MK.fmtChange(-1).up)
    }

    function test_range_and_ticks() {
        const r = MK.range([{ l: 100, h: 110 }, { l: 95, h: 105 }])
        verify(r.lo < 95 && r.hi > 110)
        const flat = MK.range([{ l: 5, h: 5 }])
        verify(flat.hi > flat.lo, "never zero tall")
        compare(MK.ticks(57300, 61700, 4), [58000, 59000, 60000, 61000])
        compare(MK.ticks(1, 1, 4), [])
    }

    function test_index_and_words() {
        compare(MK.indexAt(0, 100, 10), 0)
        compare(MK.indexAt(99, 100, 10), 9)
        compare(MK.indexAt(150, 100, 10), 9)
        compare(MK.indexAt(5, 100, 0), -1)
        compare(MK.errorWords(0), "No connection to Binance")
        compare(MK.errorWords(451), "Binance's market data isn't available from your region")
    }
}
