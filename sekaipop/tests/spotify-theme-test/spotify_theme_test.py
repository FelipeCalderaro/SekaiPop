#!/usr/bin/env python3
"""python3 -B tests/spotify-theme-test/spotify_theme_test.py   (run from the sekaipop folder)

scripts/theming/spotify-theme.py (the "spotify" App colours target) and the Discord theme's block look:
  - the colours it derives read in every theme and mode (the shell's own palettes, run through a
    port of AppThemeService.colours()), and its shadows are never black;
  - apply / revert / status against a stand-in `spicetify` in a throwaway home: what is written,
    that the earlier theme settings come back, that Spotify is never restarted, the read-only
    Spotify folder ("blocked") and no Spicetify ("missing");
  - user.css and the Discord CSS draw no soft (blurred) or black shadows, and Discord's default
    look is the block one;
  - the wiring in app-theme.sh, AppThemeService.qml and the Settings page.
Nothing outside a temporary folder is read or written.
"""
import colorsys
import configparser
import importlib.util
import json
import os
import re
import stat
import subprocess
import sys
import tempfile
import unittest

def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


TOP = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
THEMING = os.path.join(TOP, "scripts", "theming")
SCRIPT = os.path.join(THEMING, "spotify-theme.py")

spec = importlib.util.spec_from_file_location("spotify_theme", SCRIPT)
st = importlib.util.module_from_spec(spec)
spec.loader.exec_module(st)


# ===== the shell's palettes (ThemeService.qml) and a port of AppThemeService.colours() =====
def palettes():
    src = read(os.path.join(TOP, "services", "ThemeService.qml"))
    out = {}
    for m in re.finditer(r'\{ id: "(\w+)", name: "[^"]*", c: \{([^}]*)\} \}', src):
        out[m.group(1)] = dict(re.findall(r'(\w+): "(#[0-9a-fA-F]{6})"', m.group(2)))
    return out


def qt_lighter(h, f):
    r, g, b = st.rgb(h)
    hh, s, v = colorsys.rgb_to_hsv(r, g, b)
    v *= f
    if v > 1:
        s = max(0.0, s - (v - 1))
        v = 1.0
    return st.hexc(colorsys.hsv_to_rgb(hh, s, v))


def qt_darker(h, f):
    r, g, b = st.rgb(h)
    hh, s, v = colorsys.rgb_to_hsv(r, g, b)
    return st.hexc(colorsys.hsv_to_rgb(hh, s, v / f))


def shell_colours(p, mode):
    dark, darker = mode != "light", mode == "darker"
    if dark:
        bg = qt_darker(p["deep"], 1.4) if darker else p["deep"]
        fg, accent, accent2 = p["divider"], p["A"], p["B"]
        surface = qt_lighter(bg, 1.25)
        shadow = st.mix(bg, p["border"], 0.55)
    else:
        bg, fg = p["boardBg"], p["border"]
        accent, accent2 = p.get("wallMid", p["border"]), qt_darker(p["B"], 1.9)
        surface = qt_darker(bg, 1.05)
        shadow = st.mix(bg, p["border"], 0.40)
    return {"bg": bg, "fg": fg, "accent": accent, "accent2": accent2, "surface": surface,
            "border": p["border"], "shadow": shadow, "muted": st.mix(fg, bg, 0.45)}


MODES = ("light", "dark", "darker")


class Colours(unittest.TestCase):
    def setUp(self):
        self.pals = palettes()

    def test_reads_every_palette(self):
        self.assertGreaterEqual(len(self.pals), 7, "the six units and Monochrome are found")

    def test_contrast_everywhere(self):
        for name, p in self.pals.items():
            for mode in MODES:
                with self.subTest(theme=name, mode=mode):
                    c = st.palette(shell_colours(p, mode))
                    for ground in ("main", "main-elevated", "highlight", "highlight-elevated"):
                        self.assertGreaterEqual(st.contrast(c["text"], c[ground]), 4.5, "text on " + ground)
                        self.assertGreaterEqual(st.contrast(c["subtext"], c[ground]), 4.5, "subtext on " + ground)
                    self.assertGreaterEqual(st.contrast(c["sekai-on-fill"], c["sekai-fill"]), 4.5, "ink on the accent fill")
                    self.assertGreaterEqual(st.contrast(c["sekai-on-fill"], c["button-active"]), 4.5, "ink on the hovered fill")
                    self.assertGreaterEqual(st.contrast(c["button"], c["main"]), 3.0, "accent as text / icon on a panel")
                    self.assertGreaterEqual(st.contrast(c["text"], c["notification"]), 4.5, "toast text")
                    self.assertGreaterEqual(st.contrast("#ffffff", c["notification-error"]), 4.5, "error toast text")
                    self.assertGreaterEqual(st.contrast(c["sekai-line"], c["sekai-desk"]), 1.3, "outline shows on the desk")

    def test_shadows_are_never_black(self):
        for name, p in self.pals.items():
            for mode in MODES:
                c = st.palette(shell_colours(p, mode))
                for k in ("shadow", "sekai-shadow"):
                    self.assertNotEqual(c[k], "#000000", f"{name} {mode} {k}")

    def test_light_and_dark_follow_the_mode(self):
        p = self.pals["vs"]
        self.assertLess(st.luminance(st.palette(shell_colours(p, "dark"))["main"]), 0.1)
        self.assertEqual(st.palette(shell_colours(p, "light"))["main"], "#ffffff")
        d, dd = (st.palette(shell_colours(p, m))["main"] for m in ("dark", "darker"))
        self.assertLess(st.luminance(dd), st.luminance(d), "Darker is darker")

    def test_follows_the_theme(self):
        a = st.color_ini(shell_colours(self.pals["vs"], "dark"))
        b = st.color_ini(shell_colours(self.pals["vbs"], "dark"))
        self.assertNotEqual(a, b)

    def test_ini_shape(self):
        ini = st.color_ini({})
        cp = configparser.ConfigParser(interpolation=None)
        cp.read_string(ini)
        self.assertEqual(cp.sections(), ["sekai"])
        for k in ("text", "subtext", "main", "sidebar", "player", "card", "shadow", "selected-row",
                  "button", "button-active", "button-disabled", "tab-active", "notification",
                  "notification-error", "misc", "main-elevated", "highlight", "highlight-elevated"):
            self.assertRegex(cp["sekai"][k], r"^[0-9a-f]{6}$", k)

    def test_bad_values_fall_back(self):
        self.assertEqual(st.palette({"bg": "nope", "fg": "#12"}), st.palette({}))


# ===== apply / revert / status against a stand-in spicetify =====
FAKE = r'''#!/usr/bin/env python3
import configparser, os, sys
home = os.environ["XDG_CONFIG_HOME"]
with open(os.environ["FAKE_LOG"], "a") as f: f.write(" ".join(sys.argv[1:]) + "\n")
path = os.path.join(home, "spicetify", "config-xpui.ini")
cp = configparser.ConfigParser(interpolation=None); cp.optionxform = str; cp.read(path)
a = sys.argv[1:]
if a and a[0] == "config":
    for k, v in zip(a[1::2], a[2::2]):
        cp.setdefault("AdditionalOptions", {}); cp["AdditionalOptions"][k] = v
    with open(path, "w") as f: cp.write(f)
    sys.exit(0)
marker = os.path.join(home, "spicetify", "backed-up")
if a[:1] == ["backup"]:
    open(marker, "w").close(); sys.exit(0)
if a[:1] == ["apply"]:
    sys.exit(0 if os.path.exists(marker) else 1)
if a[:1] == ["update"]:
    sys.exit(0 if os.path.exists(marker) else 1)
sys.exit(2)
'''


class Lifecycle(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        t = self.tmp.name
        self.cfg = os.path.join(t, "config")
        self.spotify = os.path.join(t, "opt-spotify")
        os.makedirs(os.path.join(self.spotify, "Apps"))
        os.makedirs(os.path.join(self.cfg, "spicetify"))
        with open(os.path.join(self.cfg, "spicetify", "config-xpui.ini"), "w") as f:
            f.write("[Setting]\nspotify_path = %s\n\n[AdditionalOptions]\ncurrent_theme = Sleek\n"
                    "color_scheme = Dracula\ninject_css = 1\nreplace_colors = 0\n" % self.spotify)
        self.fake = os.path.join(t, "spicetify")
        with open(self.fake, "w") as f:
            f.write(FAKE)
        os.chmod(self.fake, 0o755)
        self.log = os.path.join(t, "log")
        self.env = dict(os.environ, XDG_CONFIG_HOME=self.cfg, XDG_STATE_HOME=os.path.join(t, "state"),
                        HOME=t, SEKAIPOP_SPICETIFY=self.fake, FAKE_LOG=self.log)

    def tearDown(self):
        for root, dirs, _ in os.walk(self.spotify):
            for d in dirs + ["."]:
                os.chmod(os.path.join(root, d), 0o755)
        self.tmp.cleanup()

    def run_(self, *args, env=None):
        return subprocess.run([sys.executable, "-B", SCRIPT, *args], env=env or self.env,
                              capture_output=True, text=True, timeout=60)

    def calls(self):
        try:
            return read(self.log).splitlines()
        except OSError:
            return []

    def conf(self):
        return st_read(self.cfg)

    def test_full_cycle(self):
        theme = os.path.join(self.cfg, "spicetify", "Themes", "SekaiPop")
        self.assertEqual(self.run_("status").stdout.strip(), "off")

        r = self.run_("apply", "bg=#232235", "fg=#e4e4ec", "accent=#04feee", "border=#555473")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue(os.path.isfile(os.path.join(theme, "color.ini")))
        self.assertEqual(read(os.path.join(theme, "user.css")),
                         read(os.path.join(THEMING, "spotify-theme.user.css")))
        c = self.conf()
        self.assertEqual((c["current_theme"], c["color_scheme"], c["replace_colors"]), ("SekaiPop", "sekai", "1"))
        # never patched before: apply fails, so it backs up and applies, without restarting
        self.assertEqual(self.calls()[-2:], ["apply --no-restart", "backup apply --no-restart"])
        self.assertEqual(self.run_("status").stdout.strip(), "on")

        n = len(self.calls())
        self.assertEqual(self.run_("apply", "bg=#232235", "fg=#e4e4ec", "accent=#04feee", "border=#555473").returncode, 0)
        self.assertEqual(len(self.calls()), n, "same colours: Spicetify is not run again")

        self.assertEqual(self.run_("apply", "bg=#43142c", "fg=#f5dbe8", "accent=#ff5c9a", "border=#561938").returncode, 0)
        self.assertEqual(self.calls()[-1], "update", "a colour change is a hot reload")

        r = self.run_("revert")
        self.assertEqual(r.returncode, 0, r.stderr)
        c = self.conf()
        self.assertEqual((c["current_theme"], c["color_scheme"], c["replace_colors"]), ("Sleek", "Dracula", "0"),
                         "the theme from before comes back")
        self.assertEqual(self.calls()[-1], "apply --no-restart")
        self.assertFalse(os.path.exists(theme))
        self.assertFalse(os.path.exists(os.path.join(self.tmp.name, "state", "sekaipop", "spotify", "previous.json")))
        self.assertEqual(self.run_("status").stdout.strip(), "off")

        for line in self.calls():
            self.assertNotIn("restart", line.replace("--no-restart", ""), "Spotify is never restarted")
            if line.startswith("apply") or line.startswith("backup"):
                self.assertIn("--no-restart", line)

    def test_previous_settings_kept_from_the_first_apply_only(self):
        self.run_("apply")
        self.run_("apply", "accent=#ff5c9a")
        prev = json.loads(read(os.path.join(self.tmp.name, "state", "sekaipop", "spotify", "previous.json")))
        self.assertEqual(prev["current_theme"], "Sleek")

    def test_revert_when_never_applied_touches_nothing(self):
        r = self.run_("revert")
        self.assertEqual(r.returncode, 0)
        self.assertEqual(self.calls(), [])
        self.assertEqual(self.conf()["current_theme"], "Sleek")

    def test_read_only_spotify_is_blocked(self):
        if os.geteuid() == 0:
            self.skipTest("root can write anywhere")
        os.chmod(os.path.join(self.spotify, "Apps"), 0o555)
        os.chmod(self.spotify, 0o555)
        r = self.run_("apply")
        self.assertEqual(r.returncode, 4)
        self.assertIn("sudo chmod a+wr", r.stderr)
        self.assertFalse(any(l.startswith(("apply", "backup", "update")) for l in self.calls()),
                         "nothing is patched")
        self.assertEqual(self.run_("status").stdout.strip(), "blocked")

    def test_no_spicetify(self):
        env = dict(self.env, SEKAIPOP_SPICETIFY="", PATH=self.tmp.name + "/nowhere")
        r = self.run_("apply", env=env)
        self.assertEqual(r.returncode, 3)
        self.assertEqual(self.run_("status", env=env).stdout.strip(), "missing")
        self.assertEqual(self.run_("revert", env=env).returncode, 0)


def st_read(cfg):
    old = os.environ.get("XDG_CONFIG_HOME")
    os.environ["XDG_CONFIG_HOME"] = cfg
    try:
        return st.read_config()
    finally:
        if old is None:
            del os.environ["XDG_CONFIG_HOME"]
        else:
            os.environ["XDG_CONFIG_HOME"] = old


# ===== the look: hard shadows only =====
def soft_shadows(css):
    """box-shadow values with a blur radius, or black."""
    bad = []
    for m in re.finditer(r"box-shadow\s*:\s*([^;]+);", css):
        for part in re.split(r",(?![^(]*\))", m.group(1)):
            part = part.strip()
            if part in ("none", "none !important"):
                continue
            nums = re.findall(r"(?<![\w-])(-?\d*\.?\d+)(px)?(?![\w%])", re.sub(r"(rgba?|color-mix|calc)\([^)]*\)", "", part))
            lens = [n for n, _ in nums]
            if len(lens) >= 3 and "inset" not in part and float(lens[2]) != 0:
                bad.append(part)
            if re.search(r"rgba?\(\s*0[ ,]+0[ ,]+0|#000\b|#000000\b|\bblack\b", part):
                bad.append(part)
    return bad


class Look(unittest.TestCase):
    def test_spotify_css_hard_shadows_only(self):
        css = read(os.path.join(THEMING, "spotify-theme.user.css"))
        self.assertEqual(soft_shadows(css), [])
        self.assertNotIn("blur(", css)
        self.assertIn("prefers-reduced-motion", css)
        self.assertIn(":focus-visible", css, "keyboard focus stays visible")

    def test_discord_block_look(self):
        body = read(os.path.join(THEMING, "discord-theme.body.css"))
        self.assertEqual(soft_shadows(body), [])
        sh = read(os.path.join(THEMING, "discord-theme.sh"))
        self.assertIn("o_look=simple;", sh, "the block look is Discord's default")
        out = subprocess.run(["sh", os.path.join(THEMING, "discord-theme.sh"), "print"],
                             capture_output=True, text=True, timeout=60).stdout
        self.assertIn("@name sekaipop\n", out)
        self.assertIn("box-shadow: 0 var(--pj-sh) 0 var(--pj-shadow)", out, "cards drop a hard shadow")
        mat = subprocess.run(["sh", os.path.join(THEMING, "discord-theme.sh"), "print", "look=material"],
                             capture_output=True, text=True, timeout=60).stdout
        self.assertIn("Material Discord", mat, "material is still there on request")


# ===== wiring =====
class Wiring(unittest.TestCase):
    def test_app_theme_sh(self):
        sh = read(os.path.join(THEMING, "app-theme.sh"))
        self.assertRegex(sh, r'if \[ "\$\{2-\}" = spotify \]; then')
        self.assertIn('python3 -B "$here/spotify-theme.py" "$cmd" "$@"', sh)
        self.assertRegex(sh, r"for t in [^;]*\bspotify\b; do")
        out = subprocess.run(["sh", os.path.join(THEMING, "app-theme.sh"), "status"], capture_output=True,
                             text=True, timeout=60, env=dict(os.environ, SEKAIPOP_SPICETIFY="",
                                                             PATH="/usr/bin:/bin")).stdout
        self.assertRegex(out, r"(?m)^spotify=(missing|off|on|blocked)$")

    def test_service_and_settings(self):
        svc = read(os.path.join(TOP, "services", "AppThemeService.qml"))
        self.assertRegex(svc, r'\{ id: "spotify", label: "Spotify", icon: "music_note", scripts: \["spotify"\]')
        page = read(os.path.join(TOP, "modules", "sekai", "settings", "SettingsPageDesktop.qml"))
        self.assertIn('appRow.modelData.id === "spotify"', page)


if __name__ == "__main__":
    unittest.main(verbosity=1)
