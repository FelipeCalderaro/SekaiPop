#!/usr/bin/env python3
"""python3 -B tests/spotify-theme-test/app_setup_test.py   (run from the sekaipop folder)

scripts/theming/app-setup.sh (what install.sh / install-deps.sh do for the Spotify and Discord
themes), in a throwaway home with stand-ins for sudo, yay, curl, qs, pgrep and the Vencord installer,
so nothing reaches the real system, the running shell or an open Discord:
  - state: none / todo / ready for both apps, both Discord layouts (system and self-updating);
  - spotify-deps: Spicetify from the AUR only when missing, sudo chmod only when the folder isn't writable;
  - spotify-on: the switch saved in settings.json, other settings kept;
  - vencord-patch: downloads the installer and runs it on the right folder, sudo only for a system
    install, nothing when Vencord is already in;
  - vencord-theme: the theme file and the tick, other Vencord settings kept, no second tick, and
    nothing written while Discord is open;
  - dry run changes nothing;
  - the installers: --spotify / --discord options, and no yes from --yes alone.
"""
import json
import os
import subprocess
import tempfile
import unittest

TOP = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
REPO = os.path.dirname(TOP)
SCRIPT = os.path.join(TOP, "scripts", "theming", "app-setup.sh")


def read(p):
    with open(p, encoding="utf-8") as f:
        return f.read()


def write(p, text, mode=None):
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w", encoding="utf-8") as f:
        f.write(text)
    if mode:
        os.chmod(p, mode)


LOGGER = '#!/bin/sh\necho "$(basename "$0") $*" >> "$FAKE_LOG"\n'


class AppSetup(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        t = self.home = self.tmp.name
        self.cfg = os.path.join(t, ".config")
        self.bin = os.path.join(t, "bin")
        self.log = os.path.join(t, "log")
        os.makedirs(self.cfg)
        # stand-ins: every outside program the helper may call
        write(os.path.join(self.bin, "sudo"), LOGGER + '"$@"\n', 0o755)          # runs the command, as you
        write(os.path.join(self.bin, "yay"), LOGGER + 'printf "#!/bin/sh\\n" > "$FAKE_BIN/spicetify"; chmod +x "$FAKE_BIN/spicetify"\n', 0o755)
        write(os.path.join(self.bin, "qs"), LOGGER + "exit 1\n", 0o755)         # no shell running
        write(os.path.join(self.bin, "pgrep"), LOGGER + 'exit "${FAKE_DISCORD_OPEN:-1}"\n', 0o755)
        write(os.path.join(self.bin, "curl"), LOGGER +
              'while [ $# -gt 0 ]; do [ "$1" = -o ] && { shift; out=$1; }; shift; done\n'
              'printf \'#!/bin/sh\\necho "vencord-installer $*" >> "$FAKE_LOG"\\n'
              'loc=""; while [ $# -gt 0 ]; do [ "$1" = -location ] && { shift; loc=$1; }; shift; done\\n'
              'r=$(find "$loc" -name app.asar -path "*resources*" | sort -V | tail -n 1); [ -n "$r" ] && touch "$(dirname "$r")/_app.asar"\\n\' > "$out"\n',
              0o755)
        self.env = {
            "HOME": t, "XDG_CONFIG_HOME": self.cfg, "XDG_CACHE_HOME": os.path.join(t, ".cache"),
            "PATH": self.bin + ":/usr/bin:/bin", "FAKE_LOG": self.log, "FAKE_BIN": self.bin,
            "SEKAIPOP_SPOTIFY_DIR": os.path.join(t, "none"), "SEKAIPOP_DISCORD_DIR": os.path.join(t, "none"),
            "SEKAIPOP_VENCORD_URL": "https://example.invalid/VencordInstallerCli-linux", "TMPDIR": t,
            "LANG": "C.UTF-8",
        }

    def tearDown(self):
        for root, dirs, _ in os.walk(self.home):
            for d in dirs:
                try:
                    os.chmod(os.path.join(root, d), 0o755)
                except OSError:
                    pass
        self.tmp.cleanup()

    def sh(self, *args, **env):
        e = dict(self.env, **env)
        return subprocess.run(["bash", SCRIPT, *args], env=e, capture_output=True, text=True, timeout=60)

    def calls(self):
        try:
            return read(self.log).splitlines()
        except OSError:
            return []

    # ----- layouts
    def spotify(self, writable=True):
        d = os.path.join(self.home, "opt-spotify")
        write(os.path.join(d, "Apps", "xpui.spa"), "x")
        if not writable:
            os.chmod(os.path.join(d, "Apps"), 0o555)
            os.chmod(d, 0o555)
        self.env["SEKAIPOP_SPOTIFY_DIR"] = d
        return d

    def discord_updater(self):
        d = os.path.join(self.cfg, "discord")
        for v in ("app-1.0.9", "app-1.0.10"):
            write(os.path.join(d, v, "resources", "app.asar"), "asar")
        self.env["SEKAIPOP_DISCORD_DIR"] = d
        return d

    def discord_system(self):
        d = os.path.join(self.home, "opt-discord")
        write(os.path.join(d, "resources", "app.asar"), "asar")
        os.chmod(os.path.join(d, "resources"), 0o555)
        self.env["SEKAIPOP_DISCORD_DIR"] = d
        return d

    # ----- state
    def test_state_none(self):
        self.assertEqual(self.sh("state", "spotify").stdout.strip(), "none")
        self.assertEqual(self.sh("state", "discord").stdout.strip(), "none")

    def test_explain_says_vencord_is_downloaded(self):
        self.discord_updater()
        out = self.sh("explain", "discord").stdout
        self.assertIn("DOWNLOADS the official Vencord installer", out)
        self.assertIn("terms of service", out)
        self.assertNotIn("(with sudo)", out, "the self-updating client is yours: no sudo")
        self.spotify()
        self.assertIn("Spicetify", self.sh("explain", "spotify").stdout)

    # ----- Spotify
    def test_spotify_deps_installs_and_unlocks(self):
        if os.geteuid() == 0:
            self.skipTest("root can write anywhere")
        d = self.spotify(writable=False)
        self.assertEqual(self.sh("state", "spotify").stdout.strip(), "todo")
        r = self.sh("spotify-deps")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        c = self.calls()
        self.assertIn("yay -S --needed spicetify-cli", c)
        self.assertIn(f"sudo chmod a+wr {d}", c)
        self.assertIn(f"sudo chmod a+wr {d}/Apps -R", c)
        self.assertIn("log in once", r.stdout, "no Spotify prefs yet")

    def test_spotify_deps_touches_nothing_when_ready(self):
        self.spotify()
        write(os.path.join(self.bin, "spicetify"), "#!/bin/sh\n", 0o755)
        r = self.sh("spotify-deps")
        self.assertEqual(r.returncode, 0)
        self.assertFalse([c for c in self.calls() if c.startswith(("yay", "sudo"))])

    def test_spotify_on_keeps_other_settings(self):
        self.spotify()
        f = os.path.join(self.cfg, "sekaipop", "settings.json")
        write(f, json.dumps({"dock.style": "capsule"}))
        r = self.sh("spotify-on")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(json.loads(read(f)), {"dock.style": "capsule", "appTheme.spotify": True})
        write(os.path.join(self.bin, "spicetify"), "#!/bin/sh\n", 0o755)
        self.assertEqual(self.sh("state", "spotify").stdout.strip(), "ready")

    def test_spotify_absent(self):
        self.assertEqual(self.sh("spotify-deps").returncode, 3)

    # ----- Discord
    def test_vencord_patch_updater_layout_needs_no_sudo(self):
        d = self.discord_updater()
        self.assertEqual(self.sh("state", "discord").stdout.strip(), "todo")
        r = self.sh("vencord-patch")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        c = self.calls()
        self.assertTrue(any(l.startswith("curl ") and "https://example.invalid/VencordInstallerCli-linux" in l and "--proto =https" in l for l in c), c)
        self.assertIn(f"vencord-installer -install -location {d}", c)
        self.assertFalse([l for l in c if l.startswith("sudo")], "no sudo for a folder you own")
        self.assertTrue(os.path.exists(os.path.join(d, "app-1.0.10", "resources", "_app.asar")), "the newest app-* is patched")
        self.assertFalse([p for p in os.listdir(self.home) if p.startswith("sekaipop-vencord.")], "the download is cleaned up")
        n = len(self.calls())
        self.assertEqual(self.sh("vencord-patch").returncode, 0)
        self.assertFalse([l for l in self.calls()[n:] if l.startswith(("curl", "vencord"))], "already patched: nothing downloaded")

    def test_vencord_patch_system_layout_uses_sudo(self):
        if os.geteuid() == 0:
            self.skipTest("root can write anywhere")
        d = self.discord_system()
        r = self.sh("vencord-patch")
        self.assertIn(f"sudo {self.home}", "\n".join(self.calls()))
        self.assertTrue(any(l.startswith("sudo ") and l.endswith(f"-install -location {d}") for l in self.calls()), self.calls())

    def test_vencord_theme_ticks_and_keeps_settings(self):
        self.discord_updater()
        write(os.path.join(self.home, ".cache", "sekaipop", "discord", "sekaipop.theme.css"), "/* theme */")
        sfile = os.path.join(self.cfg, "Vencord", "settings", "settings.json")
        write(sfile, json.dumps({"plugins": {"x": {"enabled": True}}, "enabledThemes": ["mine.css"]}))
        r = self.sh("vencord-theme")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(read(os.path.join(self.cfg, "Vencord", "themes", "sekaipop.theme.css")), "/* theme */")
        s = json.loads(read(sfile))
        self.assertEqual(s["enabledThemes"], ["mine.css", "sekaipop.theme.css"])
        self.assertEqual(s["plugins"], {"x": {"enabled": True}})
        self.assertTrue(os.path.exists(sfile + ".sekaipop.bak"))
        self.sh("vencord-theme")
        self.assertEqual(json.loads(read(sfile))["enabledThemes"].count("sekaipop.theme.css"), 1)

    def test_vencord_theme_before_first_start(self):
        self.discord_updater()
        r = self.sh("vencord-theme")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        s = json.loads(read(os.path.join(self.cfg, "Vencord", "settings", "settings.json")))
        self.assertEqual(s, {"enabledThemes": ["sekaipop.theme.css"]})
        self.assertTrue(os.path.isfile(os.path.join(self.cfg, "Vencord", "themes", "sekaipop.theme.css")))

    def test_vencord_theme_waits_while_discord_is_open(self):
        self.discord_updater()
        sfile = os.path.join(self.cfg, "Vencord", "settings", "settings.json")
        write(sfile, json.dumps({"enabledThemes": []}))
        r = self.sh("vencord-theme", FAKE_DISCORD_OPEN="0")
        self.assertEqual(r.returncode, 0)
        self.assertIn("Vencord > Themes", r.stdout)
        self.assertEqual(json.loads(read(sfile)), {"enabledThemes": []}, "a running Vencord's settings are left alone")

    def test_open_discord_without_vencord_yet_is_ticked(self):
        self.discord_updater()
        r = self.sh("vencord-theme", FAKE_DISCORD_OPEN="0")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        s = json.loads(read(os.path.join(self.cfg, "Vencord", "settings", "settings.json")))
        self.assertEqual(s["enabledThemes"], ["sekaipop.theme.css"], "Vencord has never run: safe to write")

    def test_vesktop_needs_no_download(self):
        os.makedirs(os.path.join(self.cfg, "vesktop"))
        self.assertEqual(self.sh("state", "discord").stdout.strip(), "todo")
        r = self.sh("vencord-patch")
        self.assertEqual(r.returncode, 0)
        self.assertFalse([l for l in self.calls() if l.startswith("curl")])
        self.sh("vencord-theme")
        self.assertIn("sekaipop.theme.css", read(os.path.join(self.cfg, "vesktop", "settings", "settings.json")))
        self.assertEqual(self.sh("state", "discord").stdout.strip(), "ready")

    def test_dry_run_changes_nothing(self):
        self.spotify()
        self.discord_updater()
        before = sorted(os.path.join(r, f) for r, _, fs in os.walk(self.home) for f in fs if f != "log")
        for cmd in ("spotify-deps", "spotify-on", "vencord-patch", "vencord-theme"):
            self.sh(cmd, SEKAIPOP_DRY="1")
        after = sorted(os.path.join(r, f) for r, _, fs in os.walk(self.home) for f in fs if f != "log")
        self.assertEqual(before, after)
        self.assertFalse([l for l in self.calls() if l.startswith(("yay", "sudo", "curl", "vencord"))])


class Installers(unittest.TestCase):
    def test_options_and_consent(self):
        for name in ("install.sh", "install-deps.sh"):
            src = read(os.path.join(REPO, name))
            with self.subTest(name):
                self.assertIn("--spotify) shift; SPOTIFY=", src)
                self.assertIn("--discord) shift; DISCORD=", src)
                self.assertRegex(src, r'ask_no\(\) \{\n    \[ "\$DRY" = 1 \] && return 0\n    \{ \[ "\$YES" = 1 \] \|\| \[ ! -t 0 \]; \} && return 1')
                self.assertIn('ask_no "Set up the $name theme?"', src)
                self.assertIn("explain", src)
                out = subprocess.run(["bash", os.path.join(REPO, name), "--help"], capture_output=True, text=True).stdout
                self.assertIn("--spotify", out)
                self.assertIn("--discord", out)
                self.assertTrue(out.rstrip().endswith(("packages.", "afterwards.")), "the help is printed whole")
        inst = read(os.path.join(REPO, "install.sh"))
        self.assertIn('FLAGS+=(--spotify "$SPOTIFY" --discord "$DISCORD" --sddm "$SDDM")', inst, "answers go to install-deps.sh")
        self.assertIn('bash "$APPSETUP" spotify-on', inst)
        self.assertIn('bash "$APPSETUP" vencord-theme', inst)

    def test_settings_default_exists(self):
        svc = read(os.path.join(TOP, "services", "AppThemeService.qml"))
        settings = read(os.path.join(TOP, "services", "SettingsService.qml"))
        import re
        block = re.search(r"readonly property var targets: \[([\s\S]*?)\n    \]", svc).group(1)
        for m in re.finditer(r'\{ id: "(\w+)"([^}]*)\}', block):
            if "statusDriven: true" in m.group(2):
                continue
            with self.subTest(m.group(1)):
                self.assertRegex(settings, r'"appTheme\.%s": (true|false),' % m.group(1),
                                 "SettingsService drops a key it has no default for, so the switch could never turn on")


if __name__ == "__main__":
    unittest.main(verbosity=1)
