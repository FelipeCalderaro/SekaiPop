# Ping Board

Live ping to up to 6 hosts, each a row with its last answer, a bar graph of the last 30 and how
it's doing in words (OK, Slow, Jumpy, 13% lost, Down). A lost answer is a short amber stub in the
graph. Under them, a **Test speed** key.

Add it from Edit Desktop's shelf. **Hosts** (Settings > Desktop > Plugins > Ping Board) is one per
line, an address and a name: `1.1.1.1 Cloudflare`. It pings every **Ping every** seconds, only
while the widget is on screen.

- Ping is the system's `ping` (iputils), one packet per host per round, all hosts at once. Host
  names are passed to it as arguments, never as shell text, and anything that isn't a host name or
  an IP address is left out.
- The speed test runs only when you press it: `curl` downloads 25 MB from and uploads 10 MB to
  `speed.cloudflare.com`, and reports what curl measured. Nothing else is sent.

Files: `Service.qml` (the pinging and the speed test), `Widget.qml` (what it draws),
`PingBoard.js` (pure functions), `kit/`.
Tests: `sh sekaipop/tests/plugin-widgets-test/run.sh ping-board`.
