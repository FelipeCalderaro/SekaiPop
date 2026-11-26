#!/usr/bin/env python3
"""python3 -B tests/sound-test/error_sound_test.py   (from the sekaipop folder)

scripts/theming/error-sound.sh in a throwaway home, with a stand-in gsettings: each choice writes
the XDG __custom theme (inheriting the theme you had, only the bell its own; off = bell.disabled),
GTK's sound theme goes to __custom and comes back on revert / default, your own file is copied, a
file of the wrong kind or a missing one is refused, and a __custom theme that isn't SekaiPop's is
never touched. Plus the wiring in Settings, the service and presets.
"""
import os
import subprocess
import tempfile
import unittest

TOP = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SCRIPT = os.path.join(TOP, "scripts", "theming", "error-sound.sh")


def read(p):
    with open(p, encoding="utf-8") as f:
        return f.read()


def write(p, text, mode=None):
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w", encoding="utf-8") as f:
        f.write(text)
    if mode:
        os.chmod(p, mode)


GSETTINGS = r'''#!/bin/sh
f="$FAKE_GS"
case "$1" in
  get) printf "'%s'\n" "$(cat "$f" 2>/dev/null || echo freedesktop)" ;;
  set) printf '%s' "$4" > "$f" ;;
esac
'''


class ErrorSound(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        t = self.t = self.tmp.name
        self.sounds = os.path.join(t, "sounds")
        self.sys = os.path.join(t, "sys")
        for n in ("message", "complete", "message-new-instant", "dialog-information", "bell"):
            write(os.path.join(self.sys, "freedesktop/stereo", n + ".oga"), "OGG " + n)
        self.bin = os.path.join(t, "bin")
        write(os.path.join(self.bin, "gsettings"), GSETTINGS, 0o755)
        self.gs = os.path.join(t, "gs")
        write(self.gs, "ocean")
        self.env = dict(os.environ, HOME=t, SEKAIPOP_SOUNDS=self.sounds, SEKAIPOP_SYSTEM_SOUNDS=self.sys,
                        SEKAIPOP_STATE=os.path.join(t, "state"), FAKE_GS=self.gs, PATH=self.bin + ":/usr/bin:/bin")
        self.theme = os.path.join(self.sounds, "__custom")

    def tearDown(self):
        self.tmp.cleanup()

    def sh(self, *a):
        return subprocess.run(["sh", SCRIPT, *a], env=self.env, capture_output=True, text=True, timeout=30)

    def test_choices_and_back(self):
        self.assertEqual(self.sh("status").stdout.strip(), "default")
        r = self.sh("set", "chime")
        self.assertEqual(r.returncode, 0, r.stderr)
        idx = read(os.path.join(self.theme, "index.theme"))
        self.assertIn("Inherits=ocean", idx, "every other sound stays the theme you had")
        self.assertIn("X-SekaiPop=true", idx)
        self.assertEqual(read(os.path.join(self.theme, "stereo/bell.oga")), "OGG complete")
        self.assertEqual(read(self.gs), "__custom", "GTK apps play from it too")
        self.assertEqual(self.sh("status").stdout.strip(), "chime")

        self.sh("set", "off")
        self.assertTrue(os.path.exists(os.path.join(self.theme, "stereo/bell.disabled")), "the spec's own off")
        self.assertFalse(os.path.exists(os.path.join(self.theme, "stereo/bell.oga")))
        self.assertIn("Inherits=ocean", read(os.path.join(self.theme, "index.theme")),
                      "the theme from before is remembered, not __custom")

        r = self.sh("set", "default")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertFalse(os.path.exists(self.theme))
        self.assertEqual(read(self.gs), "ocean", "GTK gets its theme back")
        self.assertEqual(self.sh("status").stdout.strip(), "default")

    def test_your_file(self):
        mine = os.path.join(self.t, "blip.wav")
        write(mine, "RIFF")
        r = self.sh("set", "file", mine)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(read(os.path.join(self.theme, "stereo/bell.wav")), "RIFF")
        self.assertEqual(self.sh("set", "file", os.path.join(self.t, "nope.oga")).returncode, 2)
        write(os.path.join(self.t, "song.mp3"), "ID3")
        r = self.sh("set", "file", os.path.join(self.t, "song.mp3"))
        self.assertEqual(r.returncode, 2)
        self.assertIn(".oga, .ogg or .wav", r.stderr)

    def test_a_custom_theme_of_yours_is_left_alone(self):
        write(os.path.join(self.theme, "index.theme"), "[Sound Theme]\nName=Mine\nInherits=freedesktop\n")
        self.assertEqual(self.sh("status").stdout.strip(), "conflict")
        r = self.sh("set", "pop")
        self.assertEqual(r.returncode, 4)
        self.assertIn("of your own", r.stderr)
        self.assertEqual(self.sh("revert").returncode, 0)
        self.assertIn("Name=Mine", read(os.path.join(self.theme, "index.theme")), "never touched")
        self.assertEqual(read(self.gs), "ocean")

    def test_unknown_choice(self):
        self.assertEqual(self.sh("set", "kazoo").returncode, 2)

    def test_wiring(self):
        page = read(os.path.join(TOP, "modules/sekai/settings/SettingsPageGeneral.qml"))
        self.assertIn('title: "Sounds"', page)
        self.assertIn('SettingsService.set("sound.error", id)', page)
        settings = read(os.path.join(TOP, "services/SettingsService.qml"))
        self.assertIn('"sound.error": "default"', settings, "a default, or SettingsService drops the key")
        self.assertIn('"sound.errorFile": ""', settings)
        self.assertIn('"sound."', read(os.path.join(TOP, "services/DesktopPresetService.qml")), "presets leave it alone")
        self.assertIn("SoundService.choice", read(os.path.join(TOP, "shell.qml")), "started with the shell")
        quick = read(os.path.join(TOP, "modules/sekai/settings/SettingsPageQuick.qml"))
        self.assertIn('title: "Idle & sleep"', quick, "idle on the Quick page too")


if __name__ == "__main__":
    unittest.main(verbosity=1)
