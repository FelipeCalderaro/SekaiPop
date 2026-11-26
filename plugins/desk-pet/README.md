# Desk Pet

**Mochi**, a little round creature drawn in the shell's own style (thick outline, pale ring, a
hard shadow on the ground), who lives on a strip of your desktop:

- **wanders**: sits a few seconds, walks somewhere else, sits again;
- **dances** while music plays (any MPRIS player), with a ♪ over its head;
- **naps** when you've been idle for **Naps after** minutes (Wayland's idle notification, the one
  hypridle uses; Keep Awake or a playing video keeps it awake), with Zz;
- **hops** with a ♥ when you click it, even out of a nap.

Add it from Edit Desktop's shelf and drag the strip where you want it to live (above the dock, under
the clock...). In Edit Desktop a dashed floor shows how far it roams; **Strip width** sets it. It
can be on one monitor at a time.

What it can't do: walk over your windows or the bar (a plugin widget is a card on the desktop
layer), or react to notifications (the shell owns those; plugins don't see them).

Settings: **Name** (its tag; empty for none), **Colour** (the theme's mint or cyan, or pink,
yellow, lilac), **Size** (0.8 to 2), **Dances to music**.

Everything moves only while it is on screen, and it does nothing at all while hidden (Focus Mode,
switched off). The art is original, made of shapes in `Mochi.qml`; no sprites or pictures.

Files: `Service.qml` (music and idle), `Widget.qml` (the strip, movement, stickers), `Mochi.qml`
(the character), `Pet.js` (its behaviour: one pure step function), `kit/`.
Tests: `sh sekaipop/tests/plugin-widgets-test/run.sh desk-pet`.
