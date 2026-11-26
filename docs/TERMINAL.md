# Terminal: neofetch, Kitty look, prompt

Three pieces. Each one writes a file of ours and hooks it into your config with a
marked line, and each one comes off again with `revert`.

`install.sh` sets them up: `--terminal auto` (the default) turns all three on for a first
install, and a reinstall refreshes only the ones already on; `--terminal yes` turns them all
on, `--terminal no` leaves the terminal alone. neofetch comes from the AUR (install-deps.sh).

## neofetch

`sh sekaipop/scripts/theming/neofetch-setup.sh enable | revert | status`

Your Quick Panel banner (or profile picture) beside the system info, drawn as a sticker card:
the picture cropped to fit (banner 16:10, avatar square), rounded, a thick outline in the
theme's accent and a hard offset shadow in its second accent. Nerd Font icons, theme colours.

- Which picture: Settings > General > Quick Panel > **Neofetch picture** (`terminal.fetchImage`,
  `banner` | `avatar`). `SEKAIPOP_FETCH_IMAGE=avatar neofetch` overrides it for one run. The chosen
  one not picked, the other one is used; neither (or not in Kitty), the distro logo.
- Colours come from Kitty's `sekaipop-colors.conf` (App colours > Kitty).
- `enable` makes `~/.config/neofetch/config.conf` source `scripts/theming/neofetch.conf` (the
  installed copy first, else the checkout). Your config is kept as `config.conf.sekaipop-bak`.
- Cards are rendered with ImageMagick into `~/.cache/sekaipop/neofetch/`, sized from the window.

## Kitty look

`sh sekaipop/scripts/theming/terminal-look.sh enable [family] | revert | status | fonts`

Writes `~/.config/kitty/sekaipop-look.conf` and includes it at the TOP of kitty.conf, so
anything you set yourself below still wins: font, 115% line height, padding, beam cursor with a
trail, powerline tabs with round caps, 94% background opacity. Kitty reloads (SIGUSR1).

The font is the first one installed, best first (all Nerd Fonts, which the prompt and neofetch need):

| Font | Why | Package |
|---|---|---|
| Maple Mono NF | rounded and friendly, cursive italics, icons built in; fits the shell best | archlinuxcn `ttf-maplemono-nf`, AUR `maplemono-nf` |
| VictorMono Nerd Font | narrow, cursive italics | `ttf-victor-mono-nerd` |
| Lilex Nerd Font | soft, many ligatures | `ttf-lilex-nerd` |
| GeistMono Nerd Font | clean, modern | `otf-geist-mono-nerd` |
| JetBrainsMono Nerd Font | already a SekaiPop dependency | `ttf-jetbrains-mono-nerd` |

`terminal-look.sh fonts` shows which are installed. Install one and run `enable` again.

## Prompt

Settings > Desktop > App colours > **Terminal prompt**: outlined sticker plates (folder, git
branch, command time, a red one with the exit code after a failure). fish gets a conf.d file;
bash gets `~/.local/state/sekaipop/terminal/prompt.bash`, sourced by one managed block at the end
of `~/.bashrc` (the plates go into PS1 with every escape wrapped in `\[ \]`, folder and branch
names escaped so nothing in them runs; PS0 times the command).

The git plate shows the branch (the short commit when detached), a dot when there are
uncommitted changes, and how far it is ahead of / behind its upstream: `main ● ↑2 ↓1`.

**History as you type (bash):** when [ble.sh](https://github.com/akinomyoga/ble.sh) is installed
(AUR `blesh-git`, which install-deps.sh adds, or a per-user install in `~/.local/share/blesh`),
the prompt loads it: fish-style grey suggestions from your history while you type (Right arrow or
End takes them) and syntax colours. fish does this by itself.
