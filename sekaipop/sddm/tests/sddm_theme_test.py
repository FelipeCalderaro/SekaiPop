#!/usr/bin/env python3
"""python3 -B sddm/tests/sddm_theme_test.py   (from the sekaipop folder)

scripts/theming/sddm-theme.sh against throwaway folders (no sudo, nothing of the real system):
install (the theme, the font, the link to the state, the state yours), --select (the previous
theme kept, the conf file), sync (what it writes, what it refuses, no rewrite when unchanged,
nothing when not installed), status, restore (everything gone, SDDM's earlier choice back),
and --dry-run changing nothing. Plus the wiring: the shell's service and the installers.
"""
import os
import stat
import subprocess
import tempfile
import time
import unittest

TOP = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
REPO = os.path.dirname(TOP)
SCRIPT = os.path.join(TOP, "scripts", "theming", "sddm-theme.sh")


def read(p):
    with open(p, encoding="utf-8") as f:
        return f.read()


class SddmTheme(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        t = self.t = self.tmp.name
        self.themes = os.path.join(t, "themes")
        self.state = os.path.join(t, "state")
        self.conf = os.path.join(t, "sddm.conf.d")
        os.makedirs(self.conf)
        self.home = os.path.join(t, "home")
        fontdir = os.path.join(self.home, ".local/share/fonts/sekaipop-google-sans-flex")
        os.makedirs(fontdir)
        with open(os.path.join(fontdir, "GoogleSansFlex-VariableFont.ttf"), "wb") as f:
            f.write(b"font")
        with open(os.path.join(self.conf, "10-theme.conf"), "w") as f:
            f.write("[Theme]\nCurrent=maya\n")
        self.env = dict(os.environ, HOME=self.home, SEKAIPOP_SDDM_THEMES=self.themes, SEKAIPOP_SDDM_STATE=self.state,
                        SEKAIPOP_SDDM_CONF=self.conf, SEKAIPOP_SUDO="", PATH="/usr/bin:/bin")
        self.wall = os.path.join(t, "wall.jpg")
        with open(self.wall, "wb") as f:
            f.write(b"\xff\xd8 picture")

    def tearDown(self):
        self.tmp.cleanup()

    def sh(self, *args):
        return subprocess.run(["sh", SCRIPT, *args], env=self.env, capture_output=True, text=True, timeout=60)

    def test_install_select_sync_restore(self):
        self.assertEqual(self.sh("status").stdout.strip(), "off")
        r = self.sh("install", "--select")
        self.assertEqual(r.returncode, 0, r.stderr)
        dest = os.path.join(self.themes, "sekaipop")
        for f in ("Main.qml", "Palette.js", "metadata.desktop", "theme.conf"):
            self.assertTrue(os.path.isfile(os.path.join(dest, f)), f)
        self.assertEqual(read(os.path.join(dest, "fonts/GoogleSansFlex.ttf")), "font", "the font travels with the theme")
        link = os.path.join(dest, "theme.conf.user")
        self.assertTrue(os.path.islink(link))
        self.assertEqual(os.readlink(link), os.path.join(self.state, "theme.conf.user"))
        self.assertEqual(stat.S_IMODE(os.stat(self.state).st_mode), 0o755, "the greeter (user sddm) can read it")
        self.assertIn("QtVersion=6", read(os.path.join(dest, "metadata.desktop")))
        self.assertIn("Current=sekaipop", read(os.path.join(self.conf, "zz-sekaipop.conf")))
        self.assertEqual(read(os.path.join(self.state, "previous-theme")).strip(), "maya", "what SDDM had is kept")
        self.assertEqual(self.sh("status").stdout.strip(), "on")

        r = self.sh("sync", "border=#561938", "A=#ff5c9a", "lockMint=#ff9ecb", "mono=false", "use24h=false",
                    "border2=#000000", "deep=red", "background=" + self.wall, "avatar=/nonexistent.png", "user=vlk", "user=$(id)")
        self.assertEqual(r.returncode, 0, r.stderr)
        conf = read(os.path.join(self.state, "theme.conf.user"))
        self.assertIn("border=#561938", conf)
        self.assertIn("lockMint=#ff9ecb", conf)
        self.assertIn("use24h=false", conf)
        self.assertIn("avatarUser=vlk", conf)
        self.assertNotIn("border2", conf, "only keys it knows")
        self.assertNotIn("deep=", conf, "only #rrggbb colours")
        self.assertNotIn("$(id)", conf)
        self.assertNotIn("avatar=", conf, "a missing picture isn't named")
        bg = os.path.join(self.state, "background.jpg")
        self.assertIn("background=" + bg, conf)
        with open(bg, "rb") as a, open(self.wall, "rb") as b:
            self.assertEqual(a.read(), b.read(), "a copy the greeter can read")
        self.assertEqual(read(link), conf, "the theme reads it through the link")

        before = os.stat(os.path.join(self.state, "theme.conf.user")).st_mtime_ns
        time.sleep(0.05)
        self.sh("sync", "border=#561938", "A=#ff5c9a", "lockMint=#ff9ecb", "mono=false", "use24h=false",
                "background=" + self.wall, "user=vlk")
        self.assertEqual(os.stat(os.path.join(self.state, "theme.conf.user")).st_mtime_ns, before, "nothing changed: not rewritten")

        r = self.sh("restore")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertFalse(os.path.exists(dest))
        self.assertFalse(os.path.exists(self.state))
        self.assertFalse(os.path.exists(os.path.join(self.conf, "zz-sekaipop.conf")))
        self.assertIn("SDDM uses maya again", r.stdout, "the theme from before is back")
        self.assertEqual(self.sh("status").stdout.strip(), "off")

    def test_install_without_select_keeps_the_login_theme(self):
        self.assertEqual(self.sh("install").returncode, 0)
        self.assertFalse(os.path.exists(os.path.join(self.conf, "zz-sekaipop.conf")))
        self.assertEqual(self.sh("status").stdout.strip(), "installed")

    def test_reinstall_keeps_your_synced_state(self):
        self.sh("install", "--select")
        self.sh("sync", "border=#2d3775")
        self.sh("install", "--select")
        self.assertIn("border=#2d3775", read(os.path.join(self.state, "theme.conf.user")))
        self.assertEqual(read(os.path.join(self.state, "previous-theme")).strip(), "maya",
                         "a second install doesn't overwrite what you had with sekaipop")

    def test_sync_without_install_does_nothing(self):
        r = self.sh("sync", "border=#555473")
        self.assertEqual(r.returncode, 0)
        self.assertFalse(os.path.exists(self.state))

    def test_dry_run_changes_nothing(self):
        r = self.sh("install", "--select", "--dry-run")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("would run", r.stdout)
        self.assertFalse(os.path.exists(self.themes))
        self.assertFalse(os.path.exists(self.state))
        self.assertFalse(os.path.exists(os.path.join(self.conf, "zz-sekaipop.conf")))

    def test_no_font_still_installs(self):
        os.remove(os.path.join(self.home, ".local/share/fonts/sekaipop-google-sans-flex/GoogleSansFlex-VariableFont.ttf"))
        env = dict(self.env, PATH=self.t)       # no fc-match either
        r = subprocess.run(["/bin/sh", SCRIPT, "install"], env=dict(env, PATH="/usr/bin:/bin".replace("/usr/bin", self.t) + ":/bin"),
                           capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("Google Sans Flex isn't installed", r.stderr)


class Wiring(unittest.TestCase):
    def test_service_and_shell(self):
        svc = read(os.path.join(TOP, "services", "SddmThemeService.qml"))
        self.assertIn('Directories.script("theming/sddm-theme.sh")', svc)
        self.assertIn("LockPalette.mint", svc)
        self.assertIn("WallpaperService.lockImagePathFor", svc)
        self.assertIn("SddmThemeService.ready", read(os.path.join(TOP, "shell.qml")))

    def test_installers_ask(self):
        for name in ("install.sh", "install-deps.sh"):
            src = read(os.path.join(REPO, name))
            with self.subTest(name):
                self.assertIn("--sddm) shift; SDDM=", src)
        inst = read(os.path.join(REPO, "install.sh"))
        self.assertIn("sddm-theme.sh", inst)
        self.assertIn("--restore-sddm", inst)


if __name__ == "__main__":
    unittest.main(verbosity=1)
