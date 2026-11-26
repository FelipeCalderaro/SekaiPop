#!/bin/sh

# SekaiPop's Kitty look: a font with some character, room around the text, a beam
# cursor with a short trail, rounded tabs. Colours stay with Settings -> Desktop ->
# App colours -> Kitty (sekaipop-colors.conf); this is everything else.
#
#   terminal-look.sh enable [family]   write ~/.config/kitty/sekaipop-look.conf and
#                                      include it at the TOP of kitty.conf (so your own
#                                      settings below still win), then reload Kitty
#   terminal-look.sh revert            remove the include and the file, reload Kitty
#   terminal-look.sh status            on | off | missing (Kitty not installed)
#   terminal-look.sh fonts             the font it would pick, and the ones it knows
#
# The font: [family] if given, else the first one installed from this list, best first.
#   Maple Mono NF        rounded and friendly, cursive italics, Nerd Font icons built in
#                        (archlinuxcn ttf-maplemono-nf, or AUR maplemono-nf)
#   VictorMono Nerd Font narrow, cursive italics          (extra/ttf-victor-mono-nerd)
#   Lilex Nerd Font      soft, wide ligature set          (extra/ttf-lilex-nerd)
#   GeistMono Nerd Font  clean and modern                 (extra/otf-geist-mono-nerd)
#   JetBrainsMono Nerd Font  SekaiPop's own dependency, always there
# Every one is a Nerd Font, which the prompt's plates and neofetch's icons need.

cfg="${XDG_CONFIG_HOME:-$HOME/.config}/kitty"
conf="$cfg/kitty.conf"
look="$cfg/sekaipop-look.conf"
MARK="# sekaipop: kitty look, removed by terminal-look.sh revert"
FONTS="Maple Mono NF
VictorMono Nerd Font
Lilex Nerd Font
GeistMono Nerd Font
JetBrainsMono Nerd Font"

installed() { [ -n "$(fc-list ":family=$1" family 2>/dev/null)" ]; }

pick_font() {
    printf '%s\n' "$FONTS" | while IFS= read -r f; do
        installed "$f" && { printf '%s' "$f"; break; }
    done
}

reload() { pkill -USR1 -x kitty 2>/dev/null; return 0; }

block_remove() {
    [ -f "$conf" ] && grep -qF "$MARK" "$conf" || return 0
    awk -v m="$MARK" 'skip > 0 { skip--; next } index($0, m) > 0 { skip = 1; next } { print }' \
        "$conf" > "$conf.sekaipop-tmp" && cat "$conf.sekaipop-tmp" > "$conf"
    rm -f "$conf.sekaipop-tmp"
}

case "$1" in
    enable)
        font="${2:-$(pick_font)}"
        [ -n "$font" ] || font="monospace"
        installed "$font" || echo "terminal-look: '$font' is not installed, Kitty will fall back" >&2
        mkdir -p "$cfg" || exit 1
        cat > "$look" <<EOF
# Written by sekaipop (terminal-look.sh). Rewritten on enable; put your own changes in kitty.conf.
font_family      $font
bold_font        auto
italic_font      auto
bold_italic_font auto
font_size        12.0
modify_font      cell_height 115%
disable_ligatures cursor

window_padding_width 12 16
hide_window_decorations yes
confirm_os_window_close 0
background_opacity 0.94

cursor_shape     beam
cursor_beam_thickness 2
cursor_trail     3
cursor_trail_decay 0.1 0.35
cursor_blink_interval 0.6 ease-in-out

url_style        curly
tab_bar_edge     top
tab_bar_style    powerline
tab_powerline_style round
tab_title_template " {index} {title} "
EOF
        block_remove
        if [ -f "$conf" ]; then
            { printf '%s\ninclude sekaipop-look.conf\n' "$MARK"; cat "$conf"; } > "$conf.sekaipop-tmp" \
                && cat "$conf.sekaipop-tmp" > "$conf"
            rm -f "$conf.sekaipop-tmp"
        else
            printf '%s\ninclude sekaipop-look.conf\n' "$MARK" > "$conf"
        fi
        reload
        echo "terminal-look: on ($font)"
        ;;
    revert)
        block_remove
        rm -f "$look"
        reload
        echo "terminal-look: off"
        ;;
    status)
        if [ -f "$conf" ] && grep -qF "$MARK" "$conf"; then echo on
        elif command -v kitty >/dev/null 2>&1; then echo off
        else echo missing; fi
        ;;
    fonts)
        echo "picks: $(pick_font)"
        printf '%s\n' "$FONTS" | while IFS= read -r f; do
            if installed "$f"; then echo "  [x] $f"; else echo "  [ ] $f"; fi
        done
        ;;
    *)
        echo "usage: $0 enable [family]|revert|status|fonts" >&2
        exit 2
        ;;
esac
