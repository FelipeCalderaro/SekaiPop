import QtQuick
import QtWebSockets
import "Market.js" as MK

// The market ticker's data (docs/PLUGINS.md, "A service"), from Binance's public market-data
// endpoints (data-api.binance.vision, data-stream.binance.vision): no account, no key, read only.
//
//   - the chosen pair's candles: fetched once (REST), then kept live by a WebSocket stream that
//     sends the forming candle about once a second;
//   - the watchlist's 24 h price and change: fetched every 30 s.
// Everything stops while the widget isn't on screen (host.working) or is paused.
QtObject {
    id: svc
    required property var host

    readonly property var symbols: {
        const s = MK.parseSymbols(svc.host.settings.symbols)
        return s.length ? s : ["BTCUSDT"]
    }
    property string symbol: svc.symbols[0]
    readonly property string interval: MK.INTERVALS.indexOf(svc.host.settings.interval) >= 0 ? svc.host.settings.interval : "15m"
    readonly property int count: Math.max(20, Math.min(120, svc.host.settings.candles))

    property var candles: []
    property var tickers: ({})
    property bool paused: false
    property string error: ""
    property bool live: false
    property var updated: 0
    readonly property bool active: svc.host.working && !svc.paused

    function select(sym) {
        if (MK.validSymbol(sym) && sym !== svc.symbol)
            svc.symbol = sym
    }
    function setInterval(iv) {
        if (MK.INTERVALS.indexOf(iv) >= 0)
            svc.host.setSetting("interval", iv)
    }
    function togglePause() { svc.paused = !svc.paused }

    onSymbolsChanged: if (svc.symbols.indexOf(svc.symbol) < 0) svc.symbol = svc.symbols[0]
    onSymbolChanged: svc.reload()
    onIntervalChanged: svc.reload()
    onActiveChanged: if (svc.active) svc.reload()
    Component.onCompleted: if (svc.active) svc.reload()

    function get(url, done) {
        const x = new XMLHttpRequest()
        x.onreadystatechange = () => {
            if (x.readyState === XMLHttpRequest.DONE)
                done(x.status, x.responseText)
        }
        x.open("GET", url)
        x.send()
    }

    function reload() {
        if (!svc.active)
            return
        const want = svc.symbol + "|" + svc.interval
        svc.get("https://data-api.binance.vision/api/v3/klines?symbol=" + svc.symbol + "&interval=" + svc.interval + "&limit=" + svc.count,
                (status, text) => {
            if (want !== svc.symbol + "|" + svc.interval)
                return                      // the pair changed while this was on its way
            const k = status === 200 ? MK.parseKlines(text) : null
            if (k) {
                svc.candles = k
                svc.error = ""
                svc.updated = Date.now()
            } else {
                svc.error = MK.errorWords(status)
                retry.restart()
            }
        })
        svc.fetchTickers()
    }

    function fetchTickers() {
        const q = encodeURIComponent(JSON.stringify(svc.symbols))
        svc.get("https://data-api.binance.vision/api/v3/ticker/24hr?symbols=" + q, (status, text) => {
            const t = status === 200 ? MK.parseTickers(text) : null
            if (t)
                svc.tickers = t
        })
    }

    property Timer tickerTimer: Timer {
        interval: 30000
        repeat: true
        running: svc.active
        onTriggered: svc.fetchTickers()
    }
    property Timer retry: Timer {
        interval: 60000
        onTriggered: svc.reload()
    }

    property WebSocket stream: WebSocket {
        url: "wss://data-stream.binance.vision/ws/" + svc.symbol.toLowerCase() + "@kline_" + svc.interval
        active: svc.active && svc.error === "" && svc.candles.length > 0
        onTextMessageReceived: message => {
            const k = MK.parseStream(message)
            if (k) {
                svc.candles = MK.applyCandle(svc.candles, k, svc.count)
                svc.updated = Date.now()
            }
        }
        onStatusChanged: {
            svc.live = svc.stream.status === WebSocket.Open
            if (svc.stream.status === WebSocket.Error)
                reconnect.restart()
        }
    }
    // a dropped stream comes back by itself (the url is the same, so flip it off and on)
    property Timer reconnect: Timer {
        interval: 5000
        onTriggered: {
            svc.stream.active = false
            svc.stream.active = Qt.binding(() => svc.active && svc.error === "" && svc.candles.length > 0)
        }
    }
}
