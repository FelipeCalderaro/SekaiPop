.pragma library
// real BTCUSDT 15 m candles and 24 h tickers saved from Binance (btc-15m.json, tickers.json)
function read(name) {
    var x = new XMLHttpRequest()
    x.open("GET", Qt.resolvedUrl(name), false)
    x.send()
    return x.responseText
}
function service(Qt) {
    var k = JSON.parse(read("btc-15m.json")).map(function (a) { return { t: +a[0], o: +a[1], h: +a[2], l: +a[3], c: +a[4], v: +a[5] } })
    var tk = {}
    JSON.parse(read("tickers.json")).forEach(function (a) { tk[a.symbol] = { last: +a.lastPrice, pct: +a.priceChangePercent, high: +a.highPrice, low: +a.lowPrice } })
    return {
        symbols: ["BTCUSDT", "ETHUSDT", "SOLUSDT", "DOGEUSDT"], symbol: "BTCUSDT", interval: "15m",
        candles: k, tickers: tk, paused: false, error: "", live: true, updated: Date.now() - 2000,
        select: function () {}, setInterval: function () {}, togglePause: function () {}
    }
}
