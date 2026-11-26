#!/bin/sh
# error-sound.sh: the desktop's "error" sound, the bell (a Backspace in an empty terminal, a
# refused key). Settings > General > Sounds. docs/SOUNDS.md.
#
#   error-sound.sh set default|soft|chime|pop|ding|off|file [path]
#   error-sound.sh revert      take SekaiPop's sound theme out, give GTK its theme name back
#   error-sound.sh status      default | soft | chime | pop | ding | off | file | conflict
#   error-sound.sh play        play the bell as apps will
#
# How: the XDG sound theme spec's own "__custom" theme, ~/.local/share/sounds/__custom/. kitty plays
# its bell from it by default (linux_bell_theme), and GTK apps do once their sound theme is
# "__custom" (gsettings org.gnome.desktop.sound theme-name; what it was is kept and given back).
# The theme inherits the one you had, so only the bell changes; "off" is the spec's bell.disabled.
# A __custom theme that isn't SekaiPop's (no X-SekaiPop line) is never touched: status says
# "conflict" and set refuses (exit 4).
#
# The compositor's bell: a Wayland app (kitty, foot...) rings it through the xdg-system-bell
# protocol, and Hyprland plays it itself, with libcanberra, as the event "bell-window-system" of
# the default "freedesktop" theme: it never reads __custom. libcanberra merges a theme found in
# ~/.local/share/sounds ahead of the system's, so a user-level "freedesktop" holding ONLY
# stereo/bell-window-system (the choice, or .disabled for off) changes that bell and nothing
# else: every other freedesktop sound still comes from /usr/share/sounds. Marked like __custom
# (X-SekaiPop line); a freedesktop folder of your own is left alone.
#
# For the tests: SEKAIPOP_SOUNDS (the sounds folder), SEKAIPOP_SYSTEM_SOUNDS (where the built-in
# ones are), SEKAIPOP_STATE (where the previous theme name is kept).

DATA=${XDG_DATA_HOME:-$HOME/.local/share}
SOUNDS=${SEKAIPOP_SOUNDS:-$DATA/sounds}
SYS=${SEKAIPOP_SYSTEM_SOUNDS:-/usr/share/sounds}
STATE=${SEKAIPOP_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/sekaipop}
THEME="$SOUNDS/__custom"
FD="$SOUNDS/freedesktop"
MARK="X-SekaiPop=true"
have() { command -v "$1" >/dev/null 2>&1; }

# the built-in choices: files of the freedesktop theme (sound-theme-freedesktop, a dependency)
builtin_file() {
    case "$1" in
        soft) n=message ;;
        chime) n=complete ;;
        pop) n=message-new-instant ;;
        ding) n=dialog-information ;;
        *) return 1 ;;
    esac
    for d in "$SYS/freedesktop/stereo" "$SYS/ocean/stereo"; do
        [ -f "$d/$n.oga" ] && { echo "$d/$n.oga"; return 0; }
    done
    return 1
}

ours() { [ -f "$THEME/index.theme" ] && grep -qF "$MARK" "$THEME/index.theme"; }
foreign() { [ -e "$THEME" ] && ! ours; }

fd_ours() { [ -f "$FD/index.theme" ] && grep -qF "$MARK" "$FD/index.theme"; }

# fd_write <choice> <file>: the compositor's bell (see the top).
fd_write() {
    if [ -e "$FD" ] && ! fd_ours; then
        echo "error-sound: $FD is a sound theme of your own: the compositor's bell (kitty's, through Hyprland) keeps its sound" >&2
        return 0
    fi
    mkdir -p "$FD/stereo" || return 1
    {
        echo "[Sound Theme]"
        echo "Name=freedesktop"
        echo "Comment=Written by SekaiPop (Settings > General > Sounds): only the window-system bell; every other sound comes from the system's freedesktop theme"
        echo "Directories=stereo"
        echo "$MARK"
        echo
        echo "[stereo]"
        echo "OutputProfile=stereo"
    } > "$FD/index.theme.tmp" && mv "$FD/index.theme.tmp" "$FD/index.theme" || return 1
    rm -f "$FD/stereo/bell-window-system".*
    if [ "$1" = off ]; then
        : > "$FD/stereo/bell-window-system.disabled"
    else
        ext=$(printf '%s' "${2##*.}" | tr 'A-Z' 'a-z')
        [ "$ext" = ogg ] && ext=oga
        cp "$2" "$FD/stereo/bell-window-system.$ext.tmp" \
            && mv "$FD/stereo/bell-window-system.$ext.tmp" "$FD/stereo/bell-window-system.$ext" || return 1
    fi
}

fd_remove() { fd_ours && rm -rf "$FD"; return 0; }

gtk_theme() { have gsettings && gsettings get org.gnome.desktop.sound theme-name 2>/dev/null | tr -d "'"; }

cmd_set() {
    choice=$1; path=${2:-}
    if foreign; then
        echo "error-sound: $THEME is a sound theme of your own; SekaiPop leaves it alone. Remove it (or set the bell in it yourself) to choose here." >&2
        return 4
    fi
    if [ "$choice" = default ]; then
        cmd_revert
        return $?
    fi
    case "$choice" in
        soft|chime|pop|ding)
            src=$(builtin_file "$choice") || { echo "error-sound: the freedesktop sound theme isn't installed (sound-theme-freedesktop)" >&2; return 3; } ;;
        file)
            src=$path
            [ -f "$src" ] && [ -r "$src" ] || { echo "error-sound: can't read $src" >&2; return 2; }
            case "$(printf '%s' "${src##*.}" | tr 'A-Z' 'a-z')" in
                oga|ogg|wav) ;;
                *) echo "error-sound: use an .oga, .ogg or .wav file (what libcanberra plays)" >&2; return 2 ;;
            esac ;;
        off) src="" ;;
        *) echo "error-sound: unknown choice: $choice" >&2; return 2 ;;
    esac

    # the theme you have now: inherited, so every other sound stays as it was, and given back later
    prev=$(gtk_theme)
    mkdir -p "$STATE" || return 1
    if [ ! -f "$STATE/sound-theme-before" ]; then
        printf '%s\n' "${prev:-freedesktop}" > "$STATE/sound-theme-before"
    fi
    inherit=$(cat "$STATE/sound-theme-before")
    [ "$inherit" = __custom ] && inherit=freedesktop

    mkdir -p "$THEME/stereo" || return 1
    {
        echo "[Sound Theme]"
        echo "Name=SekaiPop"
        echo "Comment=Written by SekaiPop (Settings > General > Sounds): only the bell is its own"
        echo "Inherits=$inherit"
        echo "Directories=stereo"
        echo "$MARK"
        echo "X-SekaiPop-Choice=$choice"
        echo
        echo "[stereo]"
        echo "OutputProfile=stereo"
    } > "$THEME/index.theme.tmp" && mv "$THEME/index.theme.tmp" "$THEME/index.theme" || return 1
    rm -f "$THEME/stereo/bell".*
    if [ "$choice" = off ]; then
        : > "$THEME/stereo/bell.disabled"
    else
        ext=$(printf '%s' "${src##*.}" | tr 'A-Z' 'a-z')
        [ "$ext" = ogg ] && ext=oga
        cp "$src" "$THEME/stereo/bell.$ext.tmp" && mv "$THEME/stereo/bell.$ext.tmp" "$THEME/stereo/bell.$ext" || return 1
    fi
    fd_write "$choice" "$src" || return 1
    if have gsettings && [ "$(gtk_theme)" != __custom ]; then
        gsettings set org.gnome.desktop.sound theme-name __custom 2>/dev/null \
            || echo "error-sound: GTK apps keep their own sound theme (gsettings refused); kitty uses the new bell" >&2
    fi
    return 0
}

cmd_revert() {
    if foreign; then
        echo "error-sound: $THEME isn't SekaiPop's; left as it is" >&2
        return 0
    fi
    rm -rf "$THEME"
    fd_remove
    before=$(cat "$STATE/sound-theme-before" 2>/dev/null)
    if have gsettings && [ "$(gtk_theme)" = __custom ]; then
        gsettings set org.gnome.desktop.sound theme-name "${before:-freedesktop}" 2>/dev/null
    fi
    rm -f "$STATE/sound-theme-before"
    return 0
}

cmd_status() {
    if foreign; then echo conflict
    elif ours; then sed -n 's/^X-SekaiPop-Choice=//p' "$THEME/index.theme" | head -n 1
    else echo default; fi
}

cmd_play() {
    if [ -f "$THEME/stereo/bell.disabled" ]; then echo "error-sound: the bell is off" >&2; return 0; fi
    # The way the compositor rings it (kitty and other Wayland apps go through Hyprland).
    if have canberra-gtk-play; then
        canberra-gtk-play -i bell-window-system -d "SekaiPop" \
            --property=canberra.xdg-theme.name=freedesktop 2>/dev/null && return 0
    fi
    f=$(ls "$THEME"/stereo/bell.* 2>/dev/null | head -n 1)
    [ -n "$f" ] || f=$(builtin_file soft 2>/dev/null) || f="$SYS/freedesktop/stereo/bell.oga"
    if have pw-play; then pw-play "$f"; elif have paplay; then paplay "$f"; else echo "error-sound: nothing to play sounds with" >&2; return 3; fi
}

case "${1:-}" in
    set) shift; cmd_set "$@" ;;
    revert) cmd_revert ;;
    status) cmd_status ;;
    play) cmd_play ;;
    *) sed -n '2,10p' "$0" >&2; exit 2 ;;
esac
