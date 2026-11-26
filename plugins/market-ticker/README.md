# Market Ticker

A live candlestick chart (or a line) for a crypto pair, its price and 24 h change, and a watchlist
strip, from **Binance's public market data**: no account, no key, read only.

Add it from Edit Desktop's shelf. **Watchlist** (Settings > Desktop > Plugins > Market Ticker) is
Binance pairs separated by spaces, `BTCUSDT ETHUSDT SOLUSDT`; the first is charted, click another
in the strip to chart it. The interval keys (1m to 1D) change the candle size.

- Rising candles are **filled**, falling ones **hollow**; changes carry ▲ / ▼ and words. So it
  reads without colour, and in the Monochrome theme.
- Hover the chart for that candle's time, open, high, low and close.
- **Live**: the candles come once by REST (`data-api.binance.vision`) and then stay live over a
  WebSocket (`data-stream.binance.vision`), about one update a second; the watchlist's 24 h prices
  every 30 s. A dropped stream reconnects by itself.
- Everything stops while the widget isn't on screen, and with the **pause** key.
- In words when it can't: no connection, a pair Binance doesn't know, or Binance refusing your
  region (HTTP 451, e.g. the United States: Binance.US is a different service).

Not investment advice; prices are Binance's, a second or two behind.

Files: `Service.qml` (REST + WebSocket), `Widget.qml` (the chart is a Canvas), `Market.js` (pure
functions: parsing, prices, the grid), `kit/`. Tests: `sh sekaipop/tests/plugin-widgets-test/run.sh market-ticker`.
