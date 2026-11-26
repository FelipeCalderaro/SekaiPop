# GIF Frame

A looping GIF (or WebP, APNG, any picture) on the desktop, in a **Polaroid** (with a caption),
**Taped** (washi tape over the corners) or **Block** frame, tilted a little if you like.

Add it from Edit Desktop's shelf and set **Picture or folder** (Settings > Desktop > Plugins >
GIF Frame):

- a file, `~/Pictures/cat.gif`: that one;
- a folder, `~/Pictures/gifs`: a random one, a different one every **Change every** minutes (never
  the same one twice in a row). A file it can't open is skipped.

Hover the picture for **pause / play** and **next**. It only plays while it is on screen, so it
stops under Focus Mode and when switched off. **Play** off holds the first frame until you press
play. The frame follows the picture's shape, kept between a wide strip and a tall portrait.

Files: `Widget.qml`, `GifFrame.js` (pure functions), `kit/` (from `examples/plugin-kit`).
Tests: `sh sekaipop/tests/plugin-widgets-test/run.sh gif-frame`.
