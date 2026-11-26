# The bundled widget plugins

Seven desktop widgets ship as plugins in `plugins/`. `install.sh` installs them with the rest (as it
does AniList); each one stays off until you add it from **Edit Desktop's shelf**. Their settings are
in **Settings > Desktop > Plugins**, drawn from each `plugin.json`.

| Plugin | What it is | Data | README |
| --- | --- | --- | --- |
| **Market Ticker** (`market-ticker`) | Live candlestick (or line) chart, price sticker, 24 h change, intervals, watchlist strip | Binance public market data: REST + WebSocket, no key | [README](../plugins/market-ticker/README.md) |
| **Ping Board** (`ping-board`) | Up to 6 hosts with bar graphs and words (OK, Slow, 13% lost, Down), speed test key | system `ping`; speed test: `curl` to speed.cloudflare.com, only on the key | [README](../plugins/ping-board/README.md) |
| **GIF Frame** (`gif-frame`) | A looping GIF / WebP / APNG / picture in a Polaroid, taped or block frame; a folder rotates | local files | [README](../plugins/gif-frame/README.md) |
| **Cover Wall** (`cover-wall`) | What's playing as a spinning record, over the albums you played lately | MPRIS (any player); history in `~/.cache/sekaipop/cover-wall/` | [README](../plugins/cover-wall/README.md) |
| **Countdowns** (`countdowns`) | Stickers counting down to dates (yearly ones too) | its own setting | [README](../plugins/countdowns/README.md) |
| **Rain Radar** (`rain-radar`) | The radar around you as a loop on a grey map, frame strip | RainViewer (radar), Open-Meteo (place), Esri canvas tiles (map), no keys | [README](../plugins/rain-radar/README.md) |
| **Desk Pet** (`desk-pet`) | Mochi, who wanders a strip of the desktop, dances to music, naps when you're idle, hops when clicked | MPRIS, Wayland idle | [README](../plugins/desk-pet/README.md) |

## What they share

- **The design system** (docs/DESIGN-SYSTEM.md), rebuilt from the theme names a plugin is promised
  (docs/PLUGINS.md): blocks with an outline, a pale ring and a hard shadow straight down; keycaps
  that drop and spring back (80 ms in, 260 ms OutBack out); stickers with an outline and a hard
  shadow; slanted section tags with a diamond. Amber means "look" (a lost ping, a slow host), never
  red; meaning never rests on colour alone (filled vs hollow candles, ▲ / ▼ with words, a stub for
  a lost ping), so every widget reads in the Monochrome theme.
- **Only while shown.** Timers, fetches, streams and animations run while `host.working` is true;
  under Focus Mode or switched off, they stop.
- **Words for problems**: no connection, a region Binance refuses, a folder with no pictures, a
  line of dates it can't read.
- **The kit** (`examples/plugin-kit/`): `Block`, `Key`, `Icon`, `Sticker`, `Tag`. A plugin can't
  import another plugin's files (each is installed on its own), so each carries a copy in its
  `kit/` folder; `examples/plugin-kit/sync.sh` copies it and the tests check the copies match.
- **Service and widget apart.** Anything that needs Quickshell (`Process`, MPRIS, the idle monitor,
  `FileView`) is in the plugin's `Service.qml`; `Widget.qml` only draws from `host.service`. The
  logic is in a `.js` file of pure functions. That is what lets them be tested without a shell.

## Checking them

```sh
sh sekaipop/tests/plugin-widgets-test/run.sh            # all of them
sh sekaipop/tests/plugin-widgets-test/run.sh desk-pet   # one
```

For each plugin it checks that every QML file parses, that `plugin.json` is valid, that `kit/`
matches the kit, runs the plugin's own unit tests (`plugins/<id>/tests/tst_*.qml`, with Qt's
`qmltestrunner`), and draws `Widget.qml` in Light, Dark and Darker with a stand-in theme
(`FakeTheme.js`, the shell's formulas) and sample data (`fixtures/<id>.js`), failing on any QML
error. Last, every manifest goes through the shell's own `PluginManifest.js` and `PluginForm.js`
(`tst_manifests.qml`), checking that no setting description is silently dropped. The PNGs are kept
to look at (the folder is printed at the end).

To draw one widget yourself:

```sh
sh sekaipop/tests/plugin-widgets-test/render.sh plugins/market-ticker /tmp/m.png darker vs fixtures/market-ticker.js
```

Needs Qt 6's `qml` and `qmltestrunner` (qt6-declarative) and `python3`; no running shell, no node.
`Service.qml` files can't be drawn this way (they need Quickshell's runtime); they are syntax
checked, and their logic is in the tested `.js` files.
