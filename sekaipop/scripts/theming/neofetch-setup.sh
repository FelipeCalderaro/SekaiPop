#!/bin/sh

# Turns SekaiPop's neofetch look (neofetch.conf, next to this script) on or off.
#
#   neofetch-setup.sh enable    ~/.config/neofetch/config.conf becomes a two-line file that
#                               sources neofetch.conf; your own config is kept as
#                               config.conf.sekaipop-bak (only the first time)
#   neofetch-setup.sh revert    puts config.conf.sekaipop-bak back (or removes ours)
#   neofetch-setup.sh status    on | off | missing (neofetch not installed)
#
# The picture is chosen in Settings -> General -> Quick Panel -> Neofetch picture.

here=$(cd "$(dirname "$0")" && pwd)
dir="${XDG_CONFIG_HOME:-$HOME/.config}/neofetch"
conf="$dir/config.conf"
bak="$conf.sekaipop-bak"
MARK="# sekaipop: managed file, removed by neofetch-setup.sh revert"

ours() { [ -f "$conf" ] && head -n 1 "$conf" | grep -qF "$MARK"; }

case "$1" in
    enable)
        [ -f "$here/neofetch.conf" ] || { echo "neofetch.conf is missing next to this script" >&2; exit 1; }
        mkdir -p "$dir" || exit 1
        if [ -f "$conf" ] && ! ours && [ ! -f "$bak" ]; then
            cp "$conf" "$bak" || exit 1
        fi
        # The installed copy first (it follows updates), else this checkout.
        {
            echo "$MARK"
            echo "for __sp_f in \"\${XDG_CONFIG_HOME:-\$HOME/.config}/quickshell/sekaipop/scripts/theming/neofetch.conf\" '$here/neofetch.conf'; do"
            echo "    [ -f \"\$__sp_f\" ] && { . \"\$__sp_f\"; break; }"
            echo "done"
        } > "$conf" || exit 1
        echo "neofetch: on (your old config is in $bak)"
        ;;
    revert)
        ours || { echo "neofetch: not ours, left alone"; exit 0; }
        if [ -f "$bak" ]; then mv "$bak" "$conf"; else rm -f "$conf"; fi
        echo "neofetch: off"
        ;;
    status)
        if ours; then echo on
        elif command -v neofetch >/dev/null 2>&1; then echo off
        else echo missing; fi
        ;;
    *)
        echo "usage: $0 enable|revert|status" >&2
        exit 2
        ;;
esac
