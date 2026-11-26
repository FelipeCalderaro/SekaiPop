#!/usr/bin/env python3
"""Spotify target of app-theme.sh: the shell's colours and block look on Spotify, through Spicetify.

    spotify-theme.py apply key=#rrggbb ...   write the SekaiPop theme, select it, hot-reload it
    spotify-theme.py revert                  give Spicetify its previous theme back, delete ours
    spotify-theme.py status                  on | off | blocked | missing
    spotify-theme.py print key=#rrggbb ...   print the color.ini it would write (installs nothing)

Keys are the ones AppThemeService.colours() sends (bg fg surface hover muted accent accent2
border shadow ...); unknown keys are ignored and missing ones fall back to Virtual Singer.

What it writes, and nothing else:
  ~/.config/spicetify/Themes/SekaiPop/color.ini   the colours, one [sekai] scheme
  ~/.config/spicetify/Themes/SekaiPop/user.css    the block look (spotify-theme.user.css, copied)
  Spicetify's config: current_theme, color_scheme, inject_css, replace_colors, set with
  `spicetify config`. Their values from before are kept in
  ~/.local/state/sekaipop/spotify/previous.json and put back by `revert`.

Spotify is never restarted (it would stop the music). The first time, `spicetify apply
--no-restart` (or `backup apply --no-restart` when Spicetify has never patched Spotify)
installs the theme; after that a colour change is `spicetify update`, Spicetify's hot reload.
A running Spotify shows the new colours after Ctrl+Shift+R, or at its next start.

Spicetify patches Spotify's own files, so the Spotify folder must be writable. For the Arch
package (/opt/spotify) that is, once:
    sudo chmod a+wr /opt/spotify && sudo chmod a+wr /opt/spotify/Apps -R
Without it `apply` writes the theme, says so and exits 4; `status` says "blocked".

Exit codes: 0 done, 2 bad arguments, 3 Spicetify not installed, 4 Spotify folder read-only,
1 Spicetify failed (its output goes to stderr).

Tests: SEKAIPOP_SPICETIFY names the spicetify program to run (a stand-in in the tests).
"""
import configparser
import json
import os
import re
import shutil
import subprocess
import sys

THEME = "SekaiPop"
SCHEME = "sekai"
KEYS = ("current_theme", "color_scheme", "inject_css", "replace_colors")
HERE = os.path.dirname(os.path.abspath(__file__))
CSS_SRC = os.path.join(HERE, "spotify-theme.user.css")

# Virtual Singer, Dark: what AppThemeService sends for the default theme
DEFAULTS = {
    "bg": "#232235", "fg": "#e4e4ec", "surface": "#2c2b42", "hover": "#383755",
    "muted": "#8f8f9f", "accent": "#04feee", "accent2": "#00ffcb", "border": "#555473",
    "shadow": "#403f59",
}


# ===== colour maths =====
def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def hexc(c):
    return "#" + "".join("%02x" % round(max(0.0, min(1.0, v)) * 255) for v in c)


def mix(a, b, t):
    """a moved toward b by t (0..1), as #rrggbb."""
    x, y = rgb(a), rgb(b)
    return hexc(tuple(x[i] * (1 - t) + y[i] * t for i in range(3)))


def luminance(h):
    def lin(v):
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = (lin(v) for v in rgb(h))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    la, lb = luminance(a), luminance(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def readable(ink, grounds, toward, need=4.5):
    """`ink` moved toward `toward` until it reads at `need`:1 on every colour in `grounds`."""
    for step in range(21):
        c = mix(ink, toward, step / 20)
        if all(contrast(c, g) >= need for g in grounds):
            return c
    return toward


def best_ink(fill, inks):
    return max(inks, key=lambda c: contrast(c, fill))


# ===== the palette =====
def palette(col):
    """The Spicetify colour scheme, from the shell's colours.

    Same structure as the shell (docs/DESIGN-SYSTEM.md): panels are blocks (fill, outline in
    `line`, hard shadow in `lineShadow`, never black) standing on a darker desk; text is `ink`
    on its own surface; the accent means "on" (play, the active tab, progress)."""
    c = dict(DEFAULTS)
    c.update({k: v for k, v in col.items() if re.fullmatch(r"#[0-9a-fA-F]{6}", v or "")})
    c = {k: v.lower() for k, v in c.items()}
    dark = luminance(c["bg"]) < 0.4
    border = c["border"]

    if dark:
        main = c["bg"]
        desk = mix(main, "#000000", 0.35)
        elevated = c["surface"]
        line = border
        shadow = mix(border, "#000000", 0.23)          # darker(border, 1.3), like `lineShadow`
        ring = mix("#ffffff", border, 0.08)
    else:
        main = "#ffffff"
        desk = mix(c["bg"], c["accent"], 0.18)
        elevated = c["bg"]
        line = mix("#ffffff", border, 0.42)            # tint(#fff, 0.42)
        shadow = mix("#ffffff", border, 0.30)          # tint(#fff, 0.30)
        ring = "#ffffff"
    highlight = mix(main, c["fg"], 0.10)
    highlight_el = mix(elevated, c["fg"], 0.12)
    grounds = [main, elevated, highlight, highlight_el]

    text = readable(c["fg"], grounds, "#ffffff" if dark else "#000000")
    subtext = readable(mix(text, main, 0.32), grounds, text)

    # The accent as a fill (play button, primary buttons, progress): its ink is the theme's
    # dark outline or white, whichever reads; if neither reaches 4.5:1 the fill is pulled
    # toward the outline colour (light mode's mid-tone accents) until white does.
    button = c["accent"]
    inks = [border, "#ffffff", c["bg"] if dark else border]
    on_accent = best_ink(button, inks)
    step = 0
    # ...and as text on a panel (see "button" below) it must read at 3:1 there too.
    while (contrast(on_accent, button) < 4.5 or contrast(button, main) < 3) and step < 20:
        step += 1
        button = mix(c["accent"], border, step / 20)
        on_accent = best_ink(button, inks)
    # Hover: further from the ink, so it never reads worse than the fill.
    button_active = mix(button, "#ffffff", 0.18) if luminance(on_accent) < luminance(button) \
        else mix(button, border, 0.15)

    notification = mix(elevated, button, 0.22)
    error = "#c2305a"

    return {
        "text": text, "subtext": subtext,
        "main": main, "main-elevated": elevated, "main-transition": main,
        "highlight": highlight, "highlight-elevated": highlight_el,
        "sidebar": main, "player": main, "card": elevated,
        "shadow": shadow, "selected-row": text,
        # Spotify uses `button` both as a fill (play) and as text / an icon on a panel (the
        # playing track, a lit heart). The fill already reads against its ink at 4.5:1 and
        # sits far from the panel, so one colour serves both (checked by the tests).
        "button": button, "button-active": button_active,
        "button-secondary": text, "button-disabled": mix(subtext, main, 0.45),
        "tab-active": highlight, "notification": notification,
        "notification-error": error, "misc": subtext,
        # the block, for user.css
        "sekai-desk": desk, "sekai-line": line, "sekai-shadow": shadow, "sekai-ring": ring,
        "sekai-fill": button, "sekai-on-fill": on_accent, "sekai-fill2": c["accent2"],
        "sekai-on-fill2": best_ink(c["accent2"], inks),
    }


def color_ini(col):
    p = palette(col)
    out = ["; Written by sekaipop (scripts/theming/spotify-theme.py). Do not edit:",
           "; it is rewritten with the theme.", "[%s]" % SCHEME]
    width = max(len(k) for k in p)
    out += ["%s = %s" % (k.ljust(width), v.lstrip("#")) for k, v in p.items()]
    return "\n".join(out) + "\n"


# ===== where things are =====
def cfg_home():
    return os.environ.get("XDG_CONFIG_HOME") or os.path.join(os.path.expanduser("~"), ".config")


def state_file():
    base = os.environ.get("XDG_STATE_HOME") or os.path.join(os.path.expanduser("~"), ".local", "state")
    return os.path.join(base, "sekaipop", "spotify", "previous.json")


def spicetify_bin():
    own = os.environ.get("SEKAIPOP_SPICETIFY")
    if own:
        return own
    found = shutil.which("spicetify")
    if found:
        return found
    home = os.path.join(os.path.expanduser("~"), ".spicetify", "spicetify")
    return home if os.access(home, os.X_OK) else None


def spicetify_dir():
    return os.path.join(cfg_home(), "spicetify")


def theme_dir():
    return os.path.join(spicetify_dir(), "Themes", THEME)


def read_config():
    """Spicetify's config as {key: value}, from config-xpui.ini (empty if there is none)."""
    path = os.path.join(spicetify_dir(), "config-xpui.ini")
    cp = configparser.ConfigParser(interpolation=None, strict=False)
    cp.optionxform = str
    try:
        cp.read(path, encoding="utf-8")
    except (configparser.Error, OSError):
        return {}
    out = {}
    for sec in cp.sections():
        for k, v in cp.items(sec):
            out.setdefault(k, v.strip())
    return out


def spotify_writable(conf):
    """False when Spicetify can't patch Spotify's files (the Arch package's /opt/spotify)."""
    path = conf.get("spotify_path") or ""
    if not path:
        for p in ("/opt/spotify", "/usr/share/spotify", "/usr/share/spotify-launcher"):
            if os.path.isdir(p):
                path = p
                break
    if not path or not os.path.isdir(path):
        return True          # nothing to check; Spicetify says so itself if it can't find it
    apps = os.path.join(path, "Apps")
    return os.access(path, os.W_OK) and (not os.path.isdir(apps) or os.access(apps, os.W_OK))


def run(bin_, *args):
    try:
        r = subprocess.run([bin_, *args], stdin=subprocess.DEVNULL, capture_output=True,
                           text=True, timeout=180)
    except (OSError, subprocess.TimeoutExpired) as e:
        return 1, str(e)
    return r.returncode, (r.stdout + r.stderr).strip()


def write_if_changed(path, text):
    try:
        with open(path, encoding="utf-8") as f:
            if f.read() == text:
                return False
    except OSError:
        pass
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".sekaipop-tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(text)
    os.replace(tmp, path)
    return True


BLOCKED = ("Spotify's folder is read-only, so Spicetify can't put the theme on. Run once:\n"
           "    sudo chmod a+wr /opt/spotify && sudo chmod a+wr /opt/spotify/Apps -R\n"
           "(or the folder `spicetify config spotify_path` names), then switch Spotify on again.")


# ===== commands =====
def apply(col):
    bin_ = spicetify_bin()
    if not bin_:
        print("spotify: Spicetify is not installed (spicetify.app)", file=sys.stderr)
        return 3
    try:
        with open(CSS_SRC, encoding="utf-8") as f:
            css = f.read()
    except OSError:
        print("spotify: spotify-theme.user.css is missing next to spotify-theme.py", file=sys.stderr)
        return 1
    changed = write_if_changed(os.path.join(theme_dir(), "color.ini"), color_ini(col))
    changed = write_if_changed(os.path.join(theme_dir(), "user.css"), css) or changed

    conf = read_config()
    ours = conf.get("current_theme") == THEME and conf.get("color_scheme") == SCHEME
    if not ours:
        sf = state_file()
        if not os.path.exists(sf):        # keep what was there before the FIRST apply only
            os.makedirs(os.path.dirname(sf), exist_ok=True)
            with open(sf, "w", encoding="utf-8") as f:
                json.dump({k: conf.get(k, "") for k in KEYS}, f)
        code, out = run(bin_, "config", "current_theme", THEME, "color_scheme", SCHEME,
                        "inject_css", "1", "replace_colors", "1")
        if code != 0:
            print("spotify: spicetify config failed: " + out, file=sys.stderr)
            return 1
    if not changed and ours:
        return 0                            # same colours, already on: nothing to reload
    if not spotify_writable(conf):
        print("spotify: " + BLOCKED, file=sys.stderr)
        return 4

    if ours:
        code, out = run(bin_, "update")      # hot reload: Ctrl+Shift+R in Spotify shows it
        if code == 0:
            return 0
    code, out = run(bin_, "apply", "--no-restart")
    if code != 0:
        # Spicetify has never patched this Spotify (or Spotify updated): back up, then apply
        code, out = run(bin_, "backup", "apply", "--no-restart")
    if code != 0:
        print("spotify: spicetify failed: " + out, file=sys.stderr)
        return 1
    return 0


def revert():
    bin_ = spicetify_bin()
    sf = state_file()
    prev = None
    try:
        with open(sf, encoding="utf-8") as f:
            prev = json.load(f)
    except (OSError, ValueError):
        pass
    conf = read_config() if bin_ else {}
    if bin_ and conf.get("current_theme") == THEME:
        prev = prev or {"current_theme": "", "color_scheme": "", "inject_css": "1", "replace_colors": "1"}
        args = []
        for k in KEYS:
            args += [k, str(prev.get(k, ""))]
        code, out = run(bin_, "config", *args)
        if code != 0:
            print("spotify: spicetify config failed: " + out, file=sys.stderr)
            return 1
        if spotify_writable(conf):
            code, out = run(bin_, "apply", "--no-restart")
            if code != 0:
                print("spotify: spicetify apply failed (Spotify keeps our colours until it works): " + out,
                      file=sys.stderr)
        else:
            print("spotify: " + BLOCKED, file=sys.stderr)
    shutil.rmtree(theme_dir(), ignore_errors=True)
    try:
        os.remove(sf)
    except OSError:
        pass
    return 0


def status():
    bin_ = spicetify_bin()
    if not bin_:
        return "missing"
    conf = read_config()
    if conf.get("current_theme") == THEME and os.path.isdir(theme_dir()):
        return "on" if spotify_writable(conf) else "blocked"
    return "off"


def parse(args):
    col = {}
    for kv in args:
        k, sep, v = kv.partition("=")
        if sep:
            col[k] = v
    return col


def main(argv):
    if not argv:
        print(__doc__.strip().split("\n\n")[1], file=sys.stderr)
        return 2
    cmd, rest = argv[0], argv[1:]
    if cmd in ("apply", "sync"):
        return apply(parse(rest))
    if cmd == "revert":
        return revert()
    if cmd == "status":
        print(status())
        return 0
    if cmd == "print":
        sys.stdout.write(color_ini(parse(rest)))
        return 0
    print("unknown command: " + cmd, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
