# The error sound (the bell)

The sound a terminal plays when Backspace has nothing to delete, or an app refuses a key, is the
desktop's **bell**. Hyprland itself makes no sound; kitty and GTK apps play it through libcanberra
from your XDG sound theme.

## Choosing it

**Settings > General > Sounds > Error sound**:

| Choice | The bell |
| --- | --- |
| Default | your sound theme's own (nothing of SekaiPop's in the way) |
| Soft, Chime, Pop, Ding | sounds of the freedesktop theme (`sound-theme-freedesktop`, installed with SekaiPop): message, complete, message-new-instant, dialog-information |
| My file | a short `.oga`, `.ogg` or `.wav` of yours (**Sound file**) |
| Off | no bell at all |

**Try it** plays the bell the way apps will. `qs -c sekaipop ipc call options set sound.error chime`,
`ipc call sound play`. A desktop preset leaves the choice as it is.

## How it works

`scripts/theming/error-sound.sh` (run by `services/SoundService.qml` when the setting changes)
writes the sound theme the XDG spec reserves for this, `~/.local/share/sounds/__custom/`:

- `index.theme` inherits the theme you had (freedesktop, ocean...), so only the bell is its own;
- `stereo/bell.oga` (or `.wav`) is the chosen sound; for Off, `stereo/bell.disabled`, the spec's own
  way to silence one sound;
- kitty plays its bell from `__custom` by default (`linux_bell_theme`); for GTK apps the GTK sound
  theme (`gsettings org.gnome.desktop.sound theme-name`) is set to `__custom`, and the name it had is
  kept in `~/.local/state/sekaipop/sound-theme-before`.

**Default** takes it all out again: the `__custom` folder goes and GTK gets its theme name back.

A `__custom` theme you made yourself is never touched: the card says so, and nothing is written
until you remove it.

## Files and checks

- `sekaipop/scripts/theming/error-sound.sh` (set / revert / status / play)
- `sekaipop/services/SoundService.qml`, the card in `modules/sekai/settings/SettingsPageGeneral.qml`
- `python3 -B sekaipop/tests/sound-test/error_sound_test.py`: every choice in a throwaway home with a
  stand-in gsettings, the way back, your own file, and a theme of yours left alone.


## Kitty and other Wayland apps: the compositor's bell

Kitty (and foot, and other Wayland apps) don't play their bell themselves when the compositor
offers the Wayland system-bell protocol: they hand it to Hyprland, which plays it with libcanberra
as `bell-window-system` from the default `freedesktop` theme, never reading `__custom`. So the
setting also writes a user-level `~/.local/share/sounds/freedesktop/` holding only
`stereo/bell-window-system.*` (the choice, or `.disabled` for Off). libcanberra merges it ahead of
`/usr/share/sounds/freedesktop`, so that bell changes and every other sound stays the system's.
*Default* removes it. A `freedesktop` folder of your own there is left alone. **Try it** plays the
bell the way Hyprland does.
