# The login screen (SDDM)

SekaiPop's SDDM theme gives the login screen the lockscreen's look (the default **Gacha** style,
`sekaipop/modules/sekai/lock/LockSurface.qml`), so logging in and unlocking are the same screen:

- your **lock wallpaper** as the art, under the same slate scrim, with the drifting sparkles;
- the **side panel**: the user who logs in on the mint tab (name, "Welcome back", your avatar),
  the other users as rows under it (click one), the machine's name;
- the **date** on its band and the **time** as big outlined type (AM / PM tag in 12-hour mode);
- **bottom left**: the session as a capsule (click for the next one: Hyprland, Plasma...);
- **top right**: Sleep, Restart, Shut down (words on hover);
- **bottom right**: the white **Password** pill with the typed dots in the five card colours and
  the keyboard layout tag (click for the next layout), and the mint **Log in** pill with its
  Enter tag; a wrong password shakes the pill and says so in the pink bubble ("Caps Lock is on"
  too, when it is).

It follows the shell: the lockscreen's colours (every theme, a matugen lockscreen, Monochrome),
the lock wallpaper of the main monitor (a still for a video wallpaper), your avatar, 12/24 h and
**Lockscreen animations** (Settings). A change shows at the next login.

## Installing it

`./install.sh` asks (only where SDDM is installed; default no, and `--yes` alone never says yes),
or answer in advance with `--sddm yes|no`. On its own:

```sh
sh sekaipop/scripts/theming/sddm-theme.sh install --select   # sudo: the theme, and make it the login screen
sh sekaipop/scripts/theming/sddm-theme.sh preview            # see it in a window, without logging out
```

What it changes:

| Where | What |
| --- | --- |
| `/usr/share/sddm/themes/sekaipop` | the theme, and a copy of Google Sans Flex (`fonts/`): the login screen can't read your home folder, where install-deps.sh put the font |
| `/var/lib/sekaipop-sddm` | yours (mode 755): `theme.conf.user`, `background.*`, `avatar.*`. The theme's `theme.conf.user` is a link here, so the shell updates the login screen without sudo |
| `/etc/sddm.conf.d/zz-sekaipop.conf` | `[Theme] Current=sekaipop` (with `--select`). The theme you had is written to `/var/lib/sekaipop-sddm/previous-theme` first |

Nothing else of SDDM's configuration is touched, and no display manager is installed or switched.

## Undo

```sh
./install.sh --restore-sddm      # or: sh sekaipop/scripts/theming/sddm-theme.sh restore
```

It deletes `zz-sekaipop.conf` (so SDDM uses the theme you had again), the theme and
`/var/lib/sekaipop-sddm`, and says which theme SDDM uses now. Tested by
`sddm/tests/sddm_theme_test.py` (install, select, restore, the earlier theme back).

## How it stays in step

`services/SddmThemeService.qml` (started with the shell) watches the lock palette, the lock
wallpaper, the avatar and the two settings, and a moment after a change runs
`sddm-theme.sh sync`, which writes them to `/var/lib/sekaipop-sddm` (only what changed; nothing at
all when the theme isn't installed). `ipc call sddmtheme sync` runs it by hand.

## Files and checks

- `sekaipop/sddm/sekaipop/`: `Main.qml` (the screen), `Palette.js` (the lockscreen's colour
  formulas, from the raw palette), `theme.conf` (defaults: Virtual Singer), `metadata.desktop`
  (Qt 6).
- `sekaipop/scripts/theming/sddm-theme.sh`: install / sync / status / restore / preview / explain.
- `sh sekaipop/sddm/tests/run.sh`: the palette tests, the script against throwaway folders, and the
  theme drawn with stand-ins for SDDM in four states (PNGs kept to look at). SDDM's own
  `sddm-greeter-qt6 --test-mode --theme sekaipop/sddm/sekaipop` loads it as well.
