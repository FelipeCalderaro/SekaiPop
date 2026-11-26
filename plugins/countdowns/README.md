# Countdowns

Stickers counting down to the days you're waiting for. The nearest one is a big sticker on a block
with a track that fills over its last 30 days; the next ones are rows under it.

Add it from Edit Desktop's shelf. The dates are its **Dates** setting (Settings > Desktop >
Plugins > Countdowns), one per line:

```
2026-12-24 Christmas            a day
2026-12-24 18:30 Concert        a day and a time
12-24 Birthday                  every year (month-day)
# a line starting with # is skipped
```

A line it can't read is counted under the stickers in words, never dropped silently. A date drops
off the day after (turn on **Keep passed ones** to keep it). It ticks every 30 seconds, only while
it is on screen.

Files: `Widget.qml` (what it draws), `Countdown.js` (the dates and words; pure functions),
`kit/` (the shell's block, keys and stickers, from `examples/plugin-kit`).
Tests: `sh sekaipop/tests/plugin-widgets-test/run.sh countdowns`.
