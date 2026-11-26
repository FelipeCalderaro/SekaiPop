# Spotify and Discord in the shell's theme

Spotify and Discord wear the same colours and the same blocks as the shell (outline, hard shadow
straight down, keycap buttons that drop and spring back; `docs/DESIGN-SYSTEM.md`), and follow it:
change the theme, Light / Dark / Darker or the wallpaper (matugen) and both get the new colours.

Neither app can be themed on its own: Spotify needs **Spicetify** and Discord needs **Vencord**
(or Vesktop / Equicord). SekaiPop writes the themes; installing those two is a one-time step.

## With the installer

`./install.sh` (and `./install-deps.sh` on its own) asks about each app that is installed, after
saying what it will download and change. Both questions default to **no**; `--yes` alone never says
yes for them. Answer them in advance with `--spotify yes|no` and `--discord yes|no`.

| | Spotify | Discord |
| --- | --- | --- |
| Downloads | `spicetify-cli` from the AUR (yay / paru) | the official Vencord installer, `VencordInstallerCli-linux` from github.com/Vencord/Installer, which downloads Vencord |
| Changes | `sudo chmod a+wr` on Spotify's folder (and `Apps/`), if it isn't yours yet | patches Discord's `resources` (no sudo for Discord's self-updating client in `~/.config/discord`, sudo for a system install such as `/opt/discord`) |
| Then | turns on Settings > Desktop > App colours > Spotify | puts `sekaipop.theme.css` in `~/.config/Vencord/themes` and ticks it (`enabledThemes` in Vencord's `settings.json`; your other settings are kept, a `.sekaipop.bak` copy is made) |
| Not touched | Spotify is never restarted | an open Discord that already runs Vencord: tick the theme yourself, or quit Discord and run again |

Vesktop has Vencord built in: nothing is downloaded, the theme is only placed and ticked. A
setup that is already complete is left alone; a Discord update that removed Vencord makes the
installer ask again. `./check-deps.sh` lists both under the optional extras.

The work is `sekaipop/scripts/theming/app-setup.sh` (`explain`, `state`, `spotify-deps`,
`spotify-on`, `vencord-patch`, `vencord-theme`; `SEKAIPOP_DRY=1` for a dry run).

Client mods such as Vencord are against Discord's terms of service; accounts are rarely acted on,
but it is your call, which is why it is never done without asking.

## Spotify (Spicetify), by hand

1. Install Spicetify (`spicetify-cli` from the AUR, or the installer on spicetify.app).
2. Let Spicetify patch Spotify. For the Arch package, Spotify's folder is read-only, so once:

   ```sh
   sudo chmod a+wr /opt/spotify
   sudo chmod a+wr /opt/spotify/Apps -R
   ```

   (A new Spotify install: log in and wait a minute before the first Spicetify run.)
3. Turn on **Settings → Desktop → App colours → Spotify**, or
   `qs -c sekaipop ipc call apptheme apply spotify`.

What it does (`sekaipop/scripts/theming/spotify-theme.py`):

- writes a Spicetify theme, `~/.config/spicetify/Themes/SekaiPop/`: `color.ini` (one scheme,
  `sekai`, from the shell's colours) and `user.css` (the block look,
  `spotify-theme.user.css`);
- selects it with `spicetify config` (`current_theme`, `color_scheme`, `inject_css`,
  `replace_colors`); what those were before is kept in
  `~/.local/state/sekaipop/spotify/previous.json`;
- **never restarts Spotify**, so the music never stops. The first time it runs
  `spicetify apply --no-restart` (`backup apply --no-restart` if Spicetify never patched this
  Spotify); after that a theme change is `spicetify update`. A running Spotify shows the new
  colours after **Ctrl+Shift+R**, or the next time it starts.

Colours: the panels are the theme's dark tone (white in Light) standing on a darker desk, each with
the theme's outline and its hard shadow; text and secondary text read at 4.5:1 or better on every
panel; the accent marks play, primary buttons and progress, with the theme's dark ink on it (or
white, with the accent deepened until it reads, in Light mode). Spotify's layout, sizes and
keyboard focus are not changed.

**Revert** (Settings, or `ipc call apptheme revert spotify`) puts back the Spicetify theme you had,
runs `spicetify apply --no-restart` and deletes the SekaiPop theme folder. To take Spicetify off
Spotify entirely, `spicetify restore`.

States in Settings: *Not installed* (no Spicetify), *Spotify's folder needs write access* (step 2),
otherwise the switch.

## Discord (Vencord), by hand

The shell already writes its Discord theme on every theme change
(`sekaipop/scripts/theming/discord-theme.sh`, called by `ThemeService`). It is the block look
by default now (`look=simple`): system24's floating cards with the theme's outline and a hard
shadow, keycap buttons, menus and popouts as blocks.

1. Patch Discord with the standalone Vencord installer (vencord.dev), or use Vesktop.
2. Start Discord once, so `~/.config/Vencord/themes/` exists, then change the theme once (or
   restart the shell): `sekaipop.theme.css` is written there.
3. In Discord: **User Settings → Vencord → Themes**, tick **sekaipop.theme.css**. Vencord reloads
   it by itself from then on, so Discord recolours live.

Options (`~/.config/sekaipop/discord-options`, one `key=value` per line): `look=material` for
CapnKitten's Material Discord instead, `look=scrapbook` for washi labels, `mode=dark|light|auto`,
`gap=12px` and the layout keys listed at the top of `discord-theme.sh`.

## Checking it

- `python3 -B tests/spotify-theme-test/spotify_theme_test.py` (from `sekaipop/`): contrast for
  every theme in every mode, the Spicetify lifecycle against a stand-in `spicetify`
  (never restarts, previous theme comes back, read-only Spotify, no Spicetify), no soft or black
  shadows in either theme, and the wiring.
- `python3 -B tests/spotify-theme-test/app_setup_test.py`: the installer part, with stand-ins for
  sudo, yay, curl, the Vencord installer, qs and pgrep (both Discord layouts, Vesktop, an open
  Discord, other settings kept, dry run changes nothing, no yes from `--yes` alone).
- Live: turn the switch on with Spotify open, press Ctrl+Shift+R in Spotify, then change the theme
  (Ctrl+Super+Shift+T) and press it again. In Discord the colours follow without a reload.
