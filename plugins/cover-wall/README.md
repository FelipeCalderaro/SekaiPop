# Cover Wall

What's playing as a record that spins (its cover as the label), with **play / pause** and
**next**, over a wall of the albums you played lately. It works with any player that talks MPRIS:
Spotify, mpv, a browser tab.

Add it from Edit Desktop's shelf.

- A track goes on the wall when it has a cover and has played for a moment. Two songs of one album
  are one cover; the newest is first. The album playing now wears an accent ring and a badge.
- Click a cover to search for it on Spotify or YouTube Music (**Click a cover to**), or nothing.
- The wall is kept in `${XDG_CACHE_HOME:-~/.cache}/sekaipop/cover-wall/history.json` (titles,
  albums, artists and cover addresses; the pictures themselves are not downloaded). Delete the file
  to clear it.
- The record turns only while music plays and the widget is on screen. Nothing is polled: it
  listens to the players' own signals.

Settings: **Covers per row** (3 to 6), **Rows** (1 to 4), **Spinning record** (off: the wall only).

Files: `Service.qml` (the players and the history), `Widget.qml`, `CoverWall.js` (pure functions),
`kit/`. Tests: `sh sekaipop/tests/plugin-widgets-test/run.sh cover-wall`.
