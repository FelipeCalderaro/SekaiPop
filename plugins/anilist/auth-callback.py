#!/usr/bin/env python3
"""Catches the AniList sign-in for the SekaiPop AniList plugin.

AniList's implicit grant sends the browser to the API client's redirect URL with the token in
the address's #fragment, which a browser never sends to a server. So this serves one small page
at http://localhost:<port>/callback that reads the fragment and posts the token back here; the
token is printed on stdout for the plugin (Service.qml), and the server exits.

    auth-callback.py <port> [seconds]      (default: give up after 300 s)

stdout, one line each:   ready | token <token> | error <what> | timeout

It listens on the loopback addresses only (127.0.0.1 and ::1, since a browser may resolve
"localhost" to either), accepts the token only from its own page (the Origin header), and never
writes it anywhere itself.
"""
import http.server
import select
import socket
import sys
import time

PAGE = """<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>SekaiPop · AniList</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
  :root { --line: #555473; --mint: #00ffcb; --cyan: #04feee; }
  body { margin: 0; min-height: 100vh; display: grid; place-items: center; background: #232235;
         font: 600 15px/1.45 "Google Sans Flex", "Google Sans", system-ui, sans-serif; color: #555473; }
  .card { background: #fff; border: 3px solid var(--line); border-radius: 13px; padding: 26px 30px;
          box-shadow: 0 6px 0 #3e3d55; max-width: 380px; text-align: center; }
  .plate { margin: -8px -12px 18px; padding: 14px; border-radius: 12px; border: 3px solid var(--line);
           background: linear-gradient(var(--mint), var(--cyan)); font-weight: 800; letter-spacing: .6px; }
  h1 { font-size: 20px; margin: 0 0 6px; font-weight: 800; }
  p { margin: 0; opacity: .75; }
</style></head>
<body><div class="card"><div class="plate">SEKAIPOP · ANILIST</div>
<h1 id="t">Signing you in…</h1><p id="m">One moment.</p></div>
<script>
  const q = new URLSearchParams(location.hash.slice(1));
  const token = q.get("access_token");
  // The token leaves the address bar (and the history) at once.
  history.replaceState(null, "", location.pathname);
  const show = (t, m) => { document.getElementById("t").textContent = t; document.getElementById("m").textContent = m; };
  if (!token) {
    show("Sign in didn't finish", q.get("error_description") || q.get("error")
      || "AniList sent no token. Check that the API client's redirect URL is this page's address.");
  } else {
    fetch("/token", { method: "POST", headers: { "Content-Type": "text/plain" }, body: token })
      .then(r => r.ok ? show("You're signed in", "Back to SekaiPop: you can close this tab.")
                      : show("Sign in didn't finish", "SekaiPop wasn't listening any more. Try again from the popup."))
      .catch(() => show("Sign in didn't finish", "SekaiPop wasn't listening any more. Try again from the popup."));
  }
</script></body></html>
""".encode()


def say(line):
    print(line, flush=True)


def main():
    port = int(sys.argv[1])
    seconds = int(sys.argv[2]) if len(sys.argv) > 2 else 300
    allowed = {"http://localhost:%d" % port, "http://127.0.0.1:%d" % port, "http://[::1]:%d" % port}
    state = {"token": None}

    class Handler(http.server.BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass

        def do_GET(self):
            if self.path.split("?")[0] != "/callback":
                self.send_error(404)
                return
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Referrer-Policy", "no-referrer")
            self.end_headers()
            self.wfile.write(PAGE)

        def do_POST(self):
            origin = self.headers.get("Origin")
            length = int(self.headers.get("Content-Length") or 0)
            if self.path != "/token" or (origin is not None and origin not in allowed) or not 0 < length <= 4096:
                self.send_error(403)
                return
            token = self.rfile.read(length).decode("utf-8", "replace").strip()
            self.send_response(204)
            self.end_headers()
            if token:
                state["token"] = token

    servers = []
    for family, host in ((socket.AF_INET, "127.0.0.1"), (socket.AF_INET6, "::1")):
        cls = type("Server", (http.server.HTTPServer,), {"address_family": family})
        try:
            servers.append(cls((host, port), Handler))
        except OSError:
            pass  # no IPv6 loopback, or that address is taken: the other one may do
    if not servers:
        say("error port %d is in use" % port)
        return 2

    say("ready")
    deadline = time.time() + seconds
    try:
        while state["token"] is None:
            left = deadline - time.time()
            if left <= 0:
                say("timeout")
                return 1
            ready, _, _ = select.select(servers, [], [], min(1.0, left))
            for srv in ready:
                srv.handle_request()
        say("token " + state["token"])
        return 0
    finally:
        for srv in servers:
            srv.server_close()


if __name__ == "__main__":
    sys.exit(main())
