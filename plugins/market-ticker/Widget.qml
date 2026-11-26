import QtQuick
import "kit"
import "Market.js" as MK

// Market Ticker: the chosen pair's live candles (or a line), its price and 24 h change, the
// candle intervals, and the watchlist strip. The data is Service.qml (Binance public market data).
//
// Meaning never rests on colour (docs/DESIGN-SYSTEM.md, Legibility): rising candles are filled,
// falling ones hollow; changes carry ▲ / ▼ and words; the live state is a word next to its dot.
Item {
    id: root
    required property var host

    readonly property var t: root.host.theme
    readonly property var s: root.host.settings
    readonly property var svc: root.host.service
    readonly property var candles: root.svc ? root.svc.candles : []
    readonly property string symbol: root.svc ? root.svc.symbol : ""
    readonly property var tick: root.svc && root.svc.tickers ? root.svc.tickers[root.symbol] : undefined
    readonly property var lastCandle: root.candles.length ? root.candles[root.candles.length - 1] : null
    readonly property real price: root.lastCandle ? root.lastCandle.c : (root.tick ? root.tick.last : NaN)
    readonly property var change: MK.fmtChange(root.tick ? root.tick.pct : 0)
    readonly property bool lightCard: Qt.color(root.t.pSurface).hslLightness > 0.6
    property int hoverIndex: -1
    property date now: new Date()

    implicitWidth: Math.max(340, root.s.width)
    implicitHeight: col.implicitHeight

    Timer {
        interval: 1000
        repeat: true
        running: root.host.working
        onTriggered: root.now = new Date()
    }

    Column {
        id: col
        width: parent.width
        spacing: 10

        // ----- header: tag, pair, live state, pause
        Item {
            width: parent.width
            height: pauseKey.height
            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -root.t.shadowOffset / 2
                spacing: 10
                Tag { anchors.verticalCenter: parent.verticalCenter; t: root.t; text: "Markets" }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: MK.pairLabel(root.symbol)
                    color: root.t.pInk
                    font.family: root.t.fontFamily
                    font.pixelSize: 16
                    font.weight: Font.ExtraBold
                    font.styleName: root.t.fontStyleBold
                }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5
                    readonly property string state: !root.svc ? "Offline" : root.svc.paused ? "Paused"
                        : root.svc.error !== "" ? "Offline" : root.svc.live ? "Live" : "Connecting"
                    Rectangle {
                        id: dot
                        anchors.verticalCenter: parent.verticalCenter
                        width: 8; height: 8; radius: 4
                        color: parent.state === "Live" ? root.t.accentCyan : root.t.pSurfaceDivider
                        border.width: 1.5
                        border.color: root.t.colBorder
                        // Live breathes (docs/DESIGN-SYSTEM.md, states)
                        SequentialAnimation on opacity {
                            running: dot.parent.state === "Live" && root.host.working
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.45; duration: 700; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
                            onRunningChanged: if (!running) dot.opacity = 1
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.state.toUpperCase()
                        color: root.t.pInkSub
                        font.family: root.t.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.ExtraBold
                        font.styleName: root.t.fontStyleBold
                        font.letterSpacing: 0.6
                    }
                }
            }
            Key {
                id: pauseKey
                anchors.right: parent.right
                t: root.t
                keyHeight: 26
                icon: root.svc && root.svc.paused ? "play_arrow" : "pause"
                enabled: root.svc !== null
                onClicked: root.svc.togglePause()
            }
        }

        // ----- price and change
        Row {
            spacing: 12
            Sticker {
                id: priceSticker
                t: root.t
                text: MK.fmtPrice(root.price)
                size: 32
                anchors.verticalCenter: parent.verticalCenter
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                Rectangle {
                    width: chg.implicitWidth + 14
                    height: 22
                    radius: 7
                    color: root.change.up ? root.t.accentMint : root.t.pSurfaceDivider
                    border.width: root.change.up ? 0 : 2
                    border.color: root.t.colBorder
                    Text {
                        id: chg
                        anchors.centerIn: parent
                        text: root.change.text
                        color: root.t.colBorder
                        font.family: root.t.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.ExtraBold
                        font.styleName: root.t.fontStyleBold
                    }
                }
                Text {
                    text: root.tick ? "24 h · " + root.change.words + " · H " + MK.fmtPrice(root.tick.high) + " · L " + MK.fmtPrice(root.tick.low) : "24 h · —"
                    color: root.t.pInkSub
                    font.family: root.t.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
            }
        }

        // ----- the chart
        Block {
            id: chartBlock
            t: root.t
            width: parent.width
            height: 200 + chartBlock.drop
            radius: 12
            drop: 3
            ringWidth: root.t.borderWidth

            Item {
                id: plot
                anchors.fill: parent
                anchors.margins: 8
                anchors.rightMargin: 56          // room for the price labels
                readonly property var r: MK.range(root.candles)
                readonly property real volH: root.s.showVolume ? height * 0.2 : 0
                readonly property real priceH: height - volH - 4
                function yOf(p) { return priceH * (1 - (p - r.lo) / (r.hi - r.lo)) }

                Canvas {
                    id: canvas
                    anchors.fill: parent
                    antialiasing: true
                    property var series: root.candles
                    onSeriesChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    Connections {
                        target: root
                        function onTChanged() { canvas.requestPaint() }
                        function onHoverIndexChanged() { canvas.requestPaint() }
                    }
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        const c = series || []
                        if (c.length === 0)
                            return
                        const ink = String(root.t.pInk)
                        const grid = String(root.t.pSurfaceDivider)
                        const fillUp = String(root.t.accentMint)
                        const hollow = String(root.t.pSurface)
                        const w = width, n = c.length, slot = w / n
                        const body = Math.max(1.5, slot * 0.62)

                        // grid
                        ctx.strokeStyle = grid
                        ctx.lineWidth = 1
                        for (const v of MK.ticks(plot.r.lo, plot.r.hi, 4)) {
                            const y = Math.round(plot.yOf(v)) + 0.5
                            ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(w, y); ctx.stroke()
                        }

                        // volume
                        if (plot.volH > 0) {
                            let vmax = 0
                            for (const k of c) vmax = Math.max(vmax, k.v)
                            for (let i = 0; i < n; i++) {
                                const k = c[i], h = vmax > 0 ? plot.volH * k.v / vmax : 0
                                ctx.fillStyle = k.c >= k.o ? fillUp : grid
                                ctx.globalAlpha = 0.7
                                ctx.fillRect(i * slot + (slot - body) / 2, height - h, body, h)
                            }
                            ctx.globalAlpha = 1
                        }

                        if (root.s.style === "line") {
                            ctx.beginPath()
                            for (let i = 0; i < n; i++) {
                                const x = i * slot + slot / 2, y = plot.yOf(c[i].c)
                                if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                            }
                            ctx.strokeStyle = ink
                            ctx.lineWidth = 2.5
                            ctx.lineJoin = "round"
                            ctx.stroke()
                            ctx.lineTo((n - 1) * slot + slot / 2, plot.priceH)
                            ctx.lineTo(slot / 2, plot.priceH)
                            ctx.closePath()
                            ctx.fillStyle = fillUp
                            ctx.globalAlpha = 0.25
                            ctx.fill()
                            ctx.globalAlpha = 1
                        } else {
                            for (let i = 0; i < n; i++) {
                                const k = c[i], x = i * slot + slot / 2
                                const up = k.c >= k.o
                                // wick
                                ctx.strokeStyle = ink
                                ctx.lineWidth = 1.2
                                ctx.beginPath(); ctx.moveTo(x, plot.yOf(k.h)); ctx.lineTo(x, plot.yOf(k.l)); ctx.stroke()
                                // body: filled when it rose, hollow when it fell
                                const y1 = plot.yOf(Math.max(k.o, k.c)), y2 = plot.yOf(Math.min(k.o, k.c))
                                const bh = Math.max(1.5, y2 - y1)
                                ctx.fillStyle = up ? fillUp : hollow
                                ctx.fillRect(x - body / 2, y1, body, bh)
                                ctx.lineWidth = 1.3
                                ctx.strokeRect(x - body / 2, y1, body, bh)
                            }
                        }

                        // last price: dashed line in ink
                        const last = c[n - 1].c, ly = Math.round(plot.yOf(last)) + 0.5
                        ctx.strokeStyle = ink
                        ctx.lineWidth = 1
                        ctx.beginPath()            // dashed by hand: QML's Canvas has no setLineDash
                        for (let x = 0; x < w; x += 6) { ctx.moveTo(x, ly); ctx.lineTo(Math.min(w, x + 3), ly) }
                        ctx.stroke()

                        // the hovered candle
                        if (root.hoverIndex >= 0 && root.hoverIndex < n) {
                            const hx = Math.round(root.hoverIndex * slot + slot / 2) + 0.5
                            ctx.strokeStyle = ink
                            ctx.globalAlpha = 0.5
                            ctx.beginPath(); ctx.moveTo(hx, 0); ctx.lineTo(hx, height); ctx.stroke()
                            ctx.globalAlpha = 1
                        }
                    }
                }

                // price labels on the right (Text, so they are crisp and use the theme's font)
                Repeater {
                    model: MK.ticks(plot.r.lo, plot.r.hi, 4)
                    Text {
                        required property real modelData
                        x: plot.width + 6
                        y: plot.yOf(modelData) - height / 2
                        visible: y > -4 && y + height < plot.priceH + 4
                        text: MK.fmtPrice(modelData)
                        color: root.t.pInkSub
                        font.family: root.t.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }
                }
                // the last price's chip
                Rectangle {
                    visible: root.lastCandle !== null
                    x: plot.width + 2
                    y: Math.max(0, Math.min(plot.priceH - height, plot.yOf(root.price) - height / 2))
                    width: lastText.implicitWidth + 10
                    height: 18
                    radius: 6
                    color: root.t.chipFill
                    Text {
                        id: lastText
                        anchors.centerIn: parent
                        text: MK.fmtPrice(root.price)
                        color: root.t.chipInk
                        font.family: root.t.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.ExtraBold
                        font.styleName: root.t.fontStyleBold
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    onPositionChanged: mouse => root.hoverIndex = MK.indexAt(mouse.x, width, root.candles.length)
                    onExited: root.hoverIndex = -1
                }

                // the hovered candle's values
                Block {
                    id: tip
                    readonly property var k: root.hoverIndex >= 0 ? root.candles[root.hoverIndex] : null
                    visible: k !== null && k !== undefined
                    t: root.t
                    width: tipText.implicitWidth + 2 * tip.ringWidth + 16
                    height: tipText.implicitHeight + 2 * tip.ringWidth + 10 + tip.drop
                    radius: 8
                    drop: 3
                    ringWidth: root.t.borderWidth
                    x: root.hoverIndex < root.candles.length / 2 ? plot.width - width - 4 : 4
                    y: 4
                    Text {
                        id: tipText
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -1
                        color: root.t.pInk
                        font.family: root.t.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        lineHeight: 1.15
                        text: tip.k ? MK.timeLabel(tip.k.t, root.svc ? root.svc.interval : "15m") + "   " + (tip.k.c >= tip.k.o ? "▲ rose" : "▼ fell")
                            + "\nO " + MK.fmtPrice(tip.k.o) + "   H " + MK.fmtPrice(tip.k.h)
                            + "\nL " + MK.fmtPrice(tip.k.l) + "   C " + MK.fmtPrice(tip.k.c) : ""
                    }
                }

                // nothing to draw: words
                Text {
                    visible: root.candles.length === 0
                    anchors.centerIn: parent
                    width: parent.width - 20
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: root.svc && root.svc.error !== "" ? root.svc.error : "Loading " + MK.pairLabel(root.symbol) + "…"
                    color: root.t.pInkSub
                    font.family: root.t.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
            }
        }

        // ----- intervals
        Row {
            spacing: 6
            Repeater {
                model: MK.INTERVALS
                Key {
                    required property string modelData
                    t: root.t
                    keyHeight: 24
                    radius: 8
                    label: modelData === "1d" ? "1D" : modelData
                    on: root.svc && root.svc.interval === modelData
                    enabled: root.svc !== null
                    onClicked: root.svc.setInterval(modelData)
                }
            }
        }

        // ----- watchlist strip: scrolls only when it doesn't fit, and stops under the pointer
        Item {
            id: strip
            width: parent.width
            height: 30
            clip: true
            readonly property var syms: root.svc ? root.svc.symbols : []
            property real oneW: 0                     // one copy of the chips, measured
            readonly property bool overflow: strip.oneW > strip.width
            HoverHandler { id: stripHover }

            Row {
                id: track
                spacing: 8
                Repeater {
                    model: strip.overflow ? 2 : 1          // a second copy so the loop has no seam
                    Row {
                        required property int index
                        spacing: 8
                        onWidthChanged: if (index === 0) strip.oneW = width
                        Repeater {
                            model: strip.syms
                            Rectangle {
                                id: chip
                                required property string modelData
                                readonly property var tk: root.svc && root.svc.tickers ? root.svc.tickers[modelData] : undefined
                                readonly property var ch: MK.fmtChange(tk ? tk.pct : 0)
                                readonly property bool on: modelData === root.symbol
                                width: chipRow.implicitWidth + 16
                                height: 26
                                radius: 8
                                color: chip.on ? root.t.accentMint : root.t.pSurfaceDivider
                                border.width: 2
                                border.color: chip.on ? root.t.colBorder : root.t.pLine
                                Row {
                                    id: chipRow
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text {
                                        text: MK.split(chip.modelData).base
                                        color: chip.on ? root.t.colBorder : root.t.pInk
                                        font.family: root.t.fontFamily
                                        font.pixelSize: 12
                                        font.weight: Font.ExtraBold
                                        font.styleName: root.t.fontStyleBold
                                    }
                                    Text {
                                        text: chip.tk ? MK.fmtPrice(chip.tk.last) + "  " + chip.ch.text : "—"
                                        color: chip.on ? root.t.colBorder : root.t.pInkSub
                                        font.family: root.t.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.svc.select(chip.modelData)
                                }
                            }
                        }
                    }
                }

                NumberAnimation on x {
                    running: strip.overflow && root.host.working && !stripHover.hovered
                    from: 0
                    to: -(track.width + track.spacing) / 2
                    duration: Math.max(8000, track.width * 25)
                    loops: Animation.Infinite
                }
            }
        }

        Text {
            text: root.svc && root.svc.updated ? "Binance public market data · " + (root.svc.paused ? "paused" : "updated " + Math.max(0, Math.round((root.now - root.svc.updated) / 1000)) + " s ago") : "Binance public market data"
            color: root.t.pInkSub
            font.family: root.t.fontFamily
            font.pixelSize: 10
            font.weight: Font.DemiBold
        }
    }
}
