#!/bin/sh
# sddm-theme.sh: SekaiPop's SDDM login theme (sekaipop/sddm/sekaipop), the lockscreen's look for
# logging in, in the colours and wallpaper of the shell's theme. docs/SDDM.md.
#
#   sddm-theme.sh install [--select] [--dry-run]   copy the theme in (sudo) and, with --select,
#                                                  make it the login screen
#   sddm-theme.sh sync key=value ...               write the theme's colours, wallpaper, avatar
#                                                  (no sudo; what the shell runs on every change)
#   sddm-theme.sh status                           missing | off | installed | on
#   sddm-theme.sh restore [--dry-run]              take it all out and give SDDM back its theme
#   sddm-theme.sh preview                          SDDM's test mode, in a window
#   sddm-theme.sh explain                          what installing it does (the installers' question)
#
# Where things go (all but the last can be moved for the tests with the variables in brackets):
#   /usr/share/sddm/themes/sekaipop   the theme, and fonts/GoogleSansFlex.ttf  [SEKAIPOP_SDDM_THEMES]
#   /var/lib/sekaipop-sddm            yours (mode 755): theme.conf.user, background, avatar  [SEKAIPOP_SDDM_STATE]
#                                     The theme's theme.conf.user is a link to this one, so the
#                                     shell updates the login screen without sudo; the greeter
#                                     (user sddm) can read it, your home folder it couldn't.
#   /etc/sddm.conf.d/zz-sekaipop.conf [Theme] Current=sekaipop, only with --select  [SEKAIPOP_SDDM_CONF]
#                                     What was chosen before is kept in previous-theme beside the
#                                     state; restore deletes this file, which is all it takes.
# sync keys: border A B deep rimHi glint wallMid lockMint lockPink (#rrggbb), mono (true|false),
#   use24h (true|false), animations (true|false), background (a picture file), avatar (a picture
#   file), user (whose avatar it is). A sync with nothing installed does nothing (exit 0).

THEMES=${SEKAIPOP_SDDM_THEMES:-/usr/share/sddm/themes}
STATE=${SEKAIPOP_SDDM_STATE:-/var/lib/sekaipop-sddm}
CONF=${SEKAIPOP_SDDM_CONF:-/etc/sddm.conf.d}
SUDO=${SEKAIPOP_SUDO-sudo}
here=$(cd "$(dirname "$0")" && pwd)
SRC=${SEKAIPOP_SDDM_SRC:-$(cd "$here/../../sddm/sekaipop" 2>/dev/null && pwd)}
DEST="$THEMES/sekaipop"
DRY=0
have() { command -v "$1" >/dev/null 2>&1; }
run() { if [ "$DRY" = 1 ]; then echo "would run: $*"; else "$@"; fi; }
asroot() { if [ "$DRY" = 1 ]; then echo "would run: $SUDO $*"; elif [ -n "$SUDO" ]; then $SUDO "$@"; else "$@"; fi; }

# The font the theme is drawn in: the copy install-deps.sh put in your fonts, else whatever
# fontconfig has. Copied into the theme, because the greeter can't read your home folder.
font_file() {
    for f in "$HOME"/.local/share/fonts/sekaipop-google-sans-flex/*.ttf; do [ -f "$f" ] && { echo "$f"; return; }; done
    have fc-match && f=$(fc-match -f '%{file}' "Google Sans Flex" 2>/dev/null) && case "$f" in *[Gg]oogle*[Ss]ans*[Ff]lex*) echo "$f" ;; esac
}

current_theme() {   # what SDDM uses now, from its config (the last Current= wins, like SDDM)
    cat /etc/sddm.conf "$CONF"/*.conf 2>/dev/null | sed -n 's/^[[:space:]]*Current[[:space:]]*=[[:space:]]*//p' | tail -n 1
}

cmd_install() {
    select=0
    for a in "$@"; do case "$a" in --select) select=1 ;; --dry-run) DRY=1 ;; esac; done
    [ -n "$SRC" ] && [ -f "$SRC/Main.qml" ] || { echo "sddm-theme: the theme's files are missing (sekaipop/sddm/sekaipop)" >&2; return 1; }
    have sddm || [ -n "${SEKAIPOP_SDDM_THEMES:-}" ] || { echo "sddm-theme: SDDM is not installed" >&2; return 3; }
    me=$(id -un)

    asroot mkdir -p "$THEMES" || return 1
    asroot rm -rf "$DEST.sekaipop-new" || return 1
    asroot cp -r "$SRC" "$DEST.sekaipop-new" || return 1
    f=$(font_file)
    if [ -n "$f" ]; then
        asroot mkdir -p "$DEST.sekaipop-new/fonts" && asroot cp "$f" "$DEST.sekaipop-new/fonts/GoogleSansFlex.ttf" || return 1
    else
        echo "sddm-theme: Google Sans Flex isn't installed; the login screen uses another font (install-deps.sh installs it)" >&2
    fi
    asroot ln -sfn "$STATE/theme.conf.user" "$DEST.sekaipop-new/theme.conf.user" || return 1
    # swap in one step, so SDDM never sees half a theme
    asroot rm -rf "$DEST" || return 1
    asroot mv "$DEST.sekaipop-new" "$DEST" || return 1

    asroot mkdir -p "$STATE" || return 1
    asroot chown "$me" "$STATE" || return 1
    asroot chmod 755 "$STATE" || return 1
    if [ "$DRY" = 0 ] && [ ! -f "$STATE/theme.conf.user" ]; then
        printf '[General]\n' > "$STATE/theme.conf.user" && chmod 644 "$STATE/theme.conf.user"
    fi

    if [ "$select" = 1 ]; then
        prev=$(current_theme)
        if [ "$prev" != sekaipop ] && [ "$DRY" = 0 ]; then
            printf '%s\n' "${prev:-}" > "$STATE/previous-theme"
        fi
        if [ "$DRY" = 1 ]; then
            echo "would write: $CONF/zz-sekaipop.conf ([Theme] Current=sekaipop; before it was: ${prev:-SDDM's default})"
        else
            asroot mkdir -p "$CONF" || return 1
            printf '# Written by SekaiPop (sddm-theme.sh). Delete this file (or sddm-theme.sh restore) to\n# go back to the theme you had%s.\n[Theme]\nCurrent=sekaipop\n' \
                "${prev:+ ($prev)}" | asroot tee "$CONF/zz-sekaipop.conf.tmp" >/dev/null || return 1
            asroot mv "$CONF/zz-sekaipop.conf.tmp" "$CONF/zz-sekaipop.conf" || return 1
        fi
    fi
    return 0
}

# key=value pairs -> theme.conf.user, and copies of the wallpaper and avatar. Rewrites nothing that
# didn't change (the greeter reads these at the next login; there is nothing to reload).
cmd_sync() {
    [ -d "$STATE" ] && [ -w "$STATE" ] || return 0
    out="[General]"
    for kv in "$@"; do
        k=${kv%%=*}; v=${kv#*=}
        case "$k" in
            border|A|B|deep|rimHi|glint|wallMid|lockMint|lockPink)
                printf '%s' "$v" | grep -Eq '^#[0-9a-fA-F]{6}$' && out="$out
$k=$v" ;;
            mono|use24h|animations)
                case "$v" in true|false) out="$out
$k=$v" ;; esac ;;
            background|avatar)
                if [ -f "$v" ] && [ -r "$v" ]; then
                    ext=$(printf '%s' "${v##*.}" | tr 'A-Z' 'a-z')
                    case "$ext" in png|jpg|jpeg|webp|bmp|gif) ;; *) ext=img ;; esac
                    dst="$STATE/$k.$ext"
                    if ! cmp -s "$v" "$dst" 2>/dev/null; then
                        rm -f "$STATE/$k".*
                        cp "$v" "$dst.tmp" && chmod 644 "$dst.tmp" && mv "$dst.tmp" "$dst" || continue
                    fi
                    out="$out
$k=$dst"
                fi ;;
            user)
                printf '%s' "$v" | grep -Eq '^[a-z_][a-z0-9_.-]{0,31}$' && out="$out
avatarUser=$v" ;;
        esac
    done
    f="$STATE/theme.conf.user"
    if [ "$(cat "$f" 2>/dev/null)" != "$out" ]; then
        printf '%s\n' "$out" > "$f.tmp" && chmod 644 "$f.tmp" && mv "$f.tmp" "$f"
    fi
    return 0
}

cmd_status() {
    if [ ! -f "$DEST/Main.qml" ]; then
        if have sddm || [ -n "${SEKAIPOP_SDDM_THEMES:-}" ]; then echo off; else echo missing; fi
    elif [ "$(current_theme)" = sekaipop ]; then echo on
    else echo installed; fi
}

cmd_restore() {
    for a in "$@"; do [ "$a" = --dry-run ] && DRY=1; done
    asroot rm -f "$CONF/zz-sekaipop.conf" || return 1
    asroot rm -rf "$DEST" || return 1
    prev=$(cat "$STATE/previous-theme" 2>/dev/null)
    asroot rm -rf "$STATE" || return 1
    if [ "$DRY" = 0 ]; then
        now=$(current_theme)
        echo "SekaiPop's login theme is gone; SDDM uses ${now:-its default theme} again${prev:+ (you had: $prev)}."
    fi
    return 0
}

cmd_explain() {
    cat <<WORDS

  SDDM login screen (optional)
  - The login screen gets the lockscreen's look: your lock wallpaper, the slate panel with
    your user on the mint tab, the big clock, the Password and Log in pills. It follows the
    shell's theme, wallpaper and avatar from then on.
  - Installs the theme to $THEMES/sekaipop (with sudo), makes
    $STATE (yours, readable by the login screen) for its colours and
    wallpaper, and selects it in $CONF/zz-sekaipop.conf. The theme you use now is
    written down first.
  - Undo: ./install.sh --restore-sddm (gives SDDM its previous theme back). Try it without
    logging out: sh sekaipop/scripts/theming/sddm-theme.sh preview
WORDS
}

cmd_preview() {
    g=$(command -v sddm-greeter-qt6 || command -v sddm-greeter)
    [ -n "$g" ] || { echo "sddm-theme: sddm-greeter isn't installed" >&2; return 3; }
    [ -f "$DEST/Main.qml" ] && t="$DEST" || t="$SRC"
    exec "$g" --test-mode --theme "$t"
}

case "${1:-}" in
    install) shift; cmd_install "$@" ;;
    sync) shift; cmd_sync "$@" ;;
    status) cmd_status ;;
    restore) shift; cmd_restore "$@" ;;
    preview) cmd_preview ;;
    explain) cmd_explain ;;
    *) sed -n '2,12p' "$0" >&2; exit 2 ;;
esac
