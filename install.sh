#!/usr/bin/env bash
# install.sh: one command to turn a minimal Hyprland system into the SekaiPop desktop.
#
# What it does:
#   1. dependencies   packages, fonts, services, groups     (runs install-deps.sh)
#   2. the rice       copied to ~/.config/quickshell/sekaipop
#      and plugins    every plugin in ./plugins copied (or linked) into ~/.config/sekaipop/plugins
#   3. Hyprland       a ready configuration in ~/.config/hypr (keybinds, rules, autostart),
#                     so after a re-login the shell simply starts. monitors.lua is not shipped:
#                     your own is kept, otherwise one is made for the screens connected now.
# Your old Hyprland config is never deleted: it is moved to ~/.config/hypr.sekaipop-backup-<time>
# and  ./install.sh --restore  puts it back. Reinstalling keeps your own edits: changes you made to
# the shipped files are merged into the new ones (or, if they clash, your file is kept and the new
# one is put beside it as <file>.sekaipop-new), and files you added are kept. A plugin folder that is replaced is moved to
# ~/.config/sekaipop/plugins.sekaipop-backup-<time>/<id> first; other plugins are never touched.
#
# Usage:  ./install.sh [options] [-- options for install-deps.sh]
#   --dry-run           show what would happen, change nothing
#   --yes               no questions
#   --rice DIR          the sekaipop folder (default: ./sekaipop next to this script)
#   --hypr MODE         full   = install the preconfigured Hyprland config (default for a new setup)
#                       merge  = keep YOUR config, only add a small sekaipop_session file to it
#                       skip   = do not touch Hyprland at all
#   --kitty MODE        keep   = keep the current Kitty theme choice
#                       enable = opt in to SekaiPop's Kitty colours after validation
#   --restore-kitty     remove only SekaiPop's Kitty colour integration and exit
#   --terminal MODE     auto | yes | no: SekaiPop's terminal look (docs/TERMINAL.md): the Kitty font,
#                       padding and cursor, neofetch with your banner, and the sticker-plate prompt
#                       for bash and fish. auto (default) = on for a first install; a reinstall
#                       only refreshes the parts that are already on
#   --plugins MODE      copy  = copy the bundled plugins (./plugins) into the plugins folder (default)
#                       link  = link them to this checkout instead (for a checkout you keep and edit)
#                       skip  = leave the plugins folder alone
#   --spotify MODE      ask | yes | no: the Spotify theme (Spicetify from the AUR, Spotify's folder
#                       made writable, the shell's switch turned on). Default ask; --yes alone = no
#   --discord MODE      ask | yes | no: the Discord theme (DOWNLOADS the official Vencord installer,
#                       patches Discord, ticks the theme). Default ask; --yes alone = no
#   --sddm MODE         ask | yes | no: SekaiPop's SDDM login screen (the theme, with sudo, selected
#                       as the login screen; the previous one is written down). Default ask; --yes alone = no
#   --restore-sddm      take SekaiPop's login screen out (SDDM's previous theme back) and exit
#   --reload MODE       ask | yes | no: at the end, inside a running Hyprland, reload it and restart
#                       the shell on the new files. ask (default) asks after a full or merge install;
#                       yes does it in every mode, --hypr skip too; no never does
#   --no-deps           do not install packages / services (only copy files)
#   --with-tests        also copy the developer tests folder
#   --restore           put back the Hyprland config that was backed up by the last run
#   -h, --help
#
# Run as your normal user (it uses sudo where needed). Needs Arch / CachyOS / EndeavourOS for the packages.

set -u
HERE=$(cd "$(dirname "$0")" && pwd)

REPLACED=0; DRY=0; YES=0; RICE=""; HYPR=auto; PLUGINS=copy; KITTY=auto; NODEPS=0; WITH_TESTS=0; RESTORE=0; RESTORE_KITTY=0; DEPS_ARGS=(); SPOTIFY=ask; DISCORD=ask; SDDM=ask; RESTORE_SDDM=0; TERMINAL=auto; RELOAD=ask
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY=1 ;;
        --yes|-y) YES=1 ;;
        --rice) shift; RICE=${1:-} ;;
        --hypr) shift; HYPR=${1:-}; case "$HYPR" in full|merge|skip) ;; *) echo "--hypr needs full|merge|skip" >&2; exit 2 ;; esac ;;
        --plugins) shift; PLUGINS=${1:-}; case "$PLUGINS" in copy|link|skip) ;; *) echo "--plugins needs copy|link|skip" >&2; exit 2 ;; esac ;;
        --kitty) shift; KITTY=${1:-}; case "$KITTY" in keep|enable) ;; *) echo "--kitty needs keep|enable" >&2; exit 2 ;; esac ;;
        --restore-kitty) RESTORE_KITTY=1 ;;
        --terminal) shift; TERMINAL=${1:-}; case "$TERMINAL" in auto|yes|no) ;; *) echo "--terminal needs auto|yes|no" >&2; exit 2 ;; esac ;;
        --spotify) shift; SPOTIFY=${1:-}; case "$SPOTIFY" in ask|yes|no) ;; *) echo "--spotify needs ask|yes|no" >&2; exit 2 ;; esac ;;
        --discord) shift; DISCORD=${1:-}; case "$DISCORD" in ask|yes|no) ;; *) echo "--discord needs ask|yes|no" >&2; exit 2 ;; esac ;;
        --sddm) shift; SDDM=${1:-}; case "$SDDM" in ask|yes|no) ;; *) echo "--sddm needs ask|yes|no" >&2; exit 2 ;; esac ;;
        --restore-sddm) RESTORE_SDDM=1 ;;
        --reload) shift; RELOAD=${1:-}; case "$RELOAD" in ask|yes|no) ;; *) echo "--reload needs ask|yes|no" >&2; exit 2 ;; esac ;;
        --no-deps) NODEPS=1 ;;
        --with-tests) WITH_TESTS=1 ;;
        --restore) RESTORE=1 ;;
        -h|--help) sed -n '2,49p' "$0"; exit 0 ;;
        --) shift; DEPS_ARGS=("$@"); break ;;
        *) echo "unknown option: $1 (try --help)" >&2; exit 2 ;;
    esac
    shift
done

# ---- look: the same style in install.sh, install-deps.sh, check-deps.sh and get.sh -------------
# Colours only on a terminal (NO_COLOR turns them off). On the bare Linux console (TERM=linux) or a
# non-UTF-8 locale the symbols fall back to plain ASCII, because a TTY font often can't draw them.
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    B=$'\e[1m'; D=$'\e[2m'; Z=$'\e[0m'
    C=$'\e[38;5;80m'; PK=$'\e[38;5;211m'; Y=$'\e[38;5;221m'; R=$'\e[38;5;203m'; GR=$'\e[38;5;114m'
else B=; D=; Z=; C=; PK=; Y=; R=; GR=; fi
case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in *[Uu][Tt][Ff]-8*|*[Uu][Tt][Ff]8*) UI_UTF=1 ;; *) UI_UTF=0 ;; esac
[ "${TERM:-}" = linux ] && UI_UTF=0
if [ "$UI_UTF" = 1 ]; then
    G_OK='✔'; G_BAD='✘'; G_DOT='•'; G_ARR='›'; G_HR='─'; G_TL='╭'; G_TR='╮'; G_BL='╰'; G_BR='╯'; G_V='│'; G_NOTE='♪'
else
    G_OK='+'; G_BAD='x'; G_DOT='-'; G_ARR='>'; G_HR='-'; G_TL='+'; G_TR='+'; G_BL='+'; G_BR='+'; G_V='|'; G_NOTE='*'
fi
UI_W=$(tput cols 2>/dev/null || echo 72); case "$UI_W" in ''|*[!0-9]*) UI_W=72 ;; esac
[ "$UI_W" -gt 76 ] && UI_W=76; [ "$UI_W" -lt 56 ] && UI_W=56
UI_BW=50
rep() { local i s=""; for ((i = 0; i < $2; i++)); do s+=$1; done; printf '%s' "$s"; }
step() { local n=$((UI_W - ${#1} - 5)); [ "$n" -lt 3 ] && n=3
    printf '\n%s%s%s %s%s%s %s%s%s\n' "$C" "$G_HR$G_HR" "$Z" "$B" "$1" "$Z" "$D" "$(rep "$G_HR" "$n")" "$Z"; }
info() { printf '  %s%s%s %s\n' "$D" "$G_DOT" "$Z" "$1"; }
ok()   { printf '  %s%s%s %s\n' "$GR" "$G_OK" "$Z" "$1"; }
warn() { printf '  %s!%s %s%s%s\n' "$Y" "$Z" "$Y" "$1" "$Z"; }
FAILED=()
fail() { printf '  %s%s%s %s%s%s\n' "$R" "$G_BAD" "$Z" "$R" "$1" "$Z"; FAILED+=("$1"); }
boxrow() { local t=$1 col=${2:-} plain=${1//"$G_NOTE"/x} pad; pad=$((UI_BW - ${#plain})); [ "$pad" -lt 0 ] && pad=0
    printf '  %s%s%s%s%s%s%*s%s%s%s\n' "$PK" "$G_V" "$Z" "$col" "$t" "$Z" "$pad" "" "$PK" "$G_V" "$Z"; }
banner() { # banner <title> <subtitle>
    printf '\n  %s%s%s%s\n' "$PK" "$G_TL" "$(rep "$G_HR" "$UI_BW")" "$G_TR$Z"
    boxrow "  $G_NOTE  $1" "$B"
    boxrow "     $2" "$D"
    printf '  %s%s%s%s\n' "$PK" "$G_BL" "$(rep "$G_HR" "$UI_BW")" "$G_BR$Z"
}
result() { # result ok|bad <text>
    local col=$GR sym=$G_OK; [ "$1" = bad ] && { col=$R; sym=$G_BAD; }
    printf '\n  %s%s %s%s\n' "$col$B" "$sym" "$2" "$Z"
}
nx() { printf '  %s%s%s %s\n' "$PK" "$G_ARR" "$Z" "$1"; }
have() { command -v "$1" >/dev/null 2>&1; }
run() {
    if [ "$DRY" = 1 ]; then printf '  %s%s%s %swould run%s' "$PK" "$G_ARR" "$Z" "$D" "$Z"; printf ' %q' "$@"; printf '\n'; return 0; fi
    "$@"
}
ask() { # ask <question>: yes by default; always yes with --yes / --dry-run
    { [ "$YES" = 1 ] || [ "$DRY" = 1 ]; } && return 0
    local a; read -r -p "  ${PK}?${Z} $1 ${D}[Y/n]${Z} " a; case "$a" in n|N|no|No) return 1 ;; *) return 0 ;; esac
}
# ask_no <question>: NO by default. Used for changes to other apps (patching Spotify / Discord): only a
# yes typed here, or --spotify yes / --discord yes, allows them. --yes alone never does.
ask_no() {
    [ "$DRY" = 1 ] && return 0
    { [ "$YES" = 1 ] || [ ! -t 0 ]; } && return 1
    local a; read -r -p "  ${PK}?${Z} $1 ${D}[y/N]${Z} " a; case "$a" in y|Y|yes|Yes|YES) return 0 ;; *) return 1 ;; esac
}
ver_ge() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" = "$2" ]; }   # ver_ge A B: A >= B

CFG=${XDG_CONFIG_HOME:-$HOME/.config}
HYPR_DEST="$CFG/hypr"
QS_DEST="$CFG/quickshell/sekaipop"
TS=$(date +%Y%m%d-%H%M%S)
hypr_running() { [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && have hyprctl && hyprctl version >/dev/null 2>&1; }

banner "SekaiPop installer" "Quickshell + Hyprland desktop"

if [ "$RESTORE_KITTY" = 1 ]; then
    step "Restoring Kitty colours"
    KITTY_THEME="$HERE/sekaipop/scripts/theming/app-theme.sh"
    if [ ! -f "$KITTY_THEME" ] || [ ! -f "$HERE/sekaipop/scripts/theming/kitty-theme.py" ]; then
        echo "The bundled Kitty helper is missing. Run --restore-kitty from a complete current SekaiPop checkout." >&2
        exit 1
    fi
    KITTY_FLAGS=()
    [ "$DRY" = 1 ] && KITTY_FLAGS+=(--dry-run)
    sh "$KITTY_THEME" revert kitty "${KITTY_FLAGS[@]}" || exit $?
    exit 0
fi

if [ "$RESTORE_SDDM" = 1 ]; then
    step "Restoring the login screen"
    SDDMSH="$HERE/sekaipop/scripts/theming/sddm-theme.sh"
    [ -f "$SDDMSH" ] || { echo "The bundled SDDM helper is missing (sekaipop/scripts/theming/sddm-theme.sh)." >&2; exit 1; }
    SDDMF=(); [ "$DRY" = 1 ] && SDDMF+=(--dry-run)
    sh "$SDDMSH" restore "${SDDMF[@]}" || exit $?
    exit 0
fi

if [ "$RESTORE" = 1 ] && [ "$HYPR" = skip ]; then
    echo "--restore cannot be combined with --hypr skip." >&2
    exit 2
fi

# Anything left from when SekaiPop was called pjsekai (settings, presets, app-colour blocks, the
# Hyprland overrides file and backups) is moved to the new name first, respecting --hypr skip.
if [ -f "$HERE/sekaipop/scripts/system/migrate-from-pjsekai.sh" ]; then
    MIGRATE_FLAGS=()
    [ "$DRY" = 1 ] && MIGRATE_FLAGS+=(--dry-run)
    [ "$HYPR" = skip ] && MIGRATE_FLAGS+=(--skip-hypr)
    sh "$HERE/sekaipop/scripts/system/migrate-from-pjsekai.sh" "${MIGRATE_FLAGS[@]}"
fi

# ------------------------------------------------------------------ --restore
if [ "$RESTORE" = 1 ]; then
    step "Restoring your previous Hyprland config"
    last=$(ls -d "$CFG"/hypr.sekaipop-backup-* 2>/dev/null | sort | tail -1)
    [ -n "$last" ] || { echo "No backup of your own config found (looked for $CFG/hypr.sekaipop-backup-*)." >&2
        [ -d "$CFG/hypr.sekaipop-previous" ] && echo "There is $CFG/hypr.sekaipop-previous: the sekaipop config from before the last update." >&2
        exit 1; }
    info "backup: $last"
    ask "Put it back as $HYPR_DEST (the current one is kept as hypr.sekaipop-replaced-$TS)?" || exit 0
    [ -e "$HYPR_DEST" ] && run mv "$HYPR_DEST" "$CFG/hypr.sekaipop-replaced-$TS"
    run cp -a "$last" "$HYPR_DEST"
    ok "done. Reload Hyprland (or log out and in) to use it."
    exit 0
fi

# ------------------------------------------------------------------ checks
step "Checking the system"
[ "$(id -u)" = 0 ] && { echo "Run this as your normal user, not root (it calls sudo itself)." >&2; exit 1; }
[ "$DRY" = 1 ] && info "DRY RUN: nothing will be changed."

# the rice
if [ -z "$RICE" ]; then
    for c in "$HERE/sekaipop" "$HERE/../sekaipop" "$HERE"; do
        [ -f "$c/shell.qml" ] && { RICE=$c; break; }
    done
fi
if [ -z "$RICE" ] || [ ! -f "$RICE/shell.qml" ]; then
    echo "Could not find the sekaipop folder (the one with shell.qml)." >&2
    echo "Put it next to install.sh, or pass:  --rice /path/to/sekaipop" >&2
    exit 1
fi
RICE=$(cd "$RICE" && pwd)
FIRST_INSTALL=0; [ -f "$QS_DEST/shell.qml" ] || FIRST_INSTALL=1
VERSION=$(cat "$RICE/VERSION" 2>/dev/null || echo unknown)
ok "rice: $RICE ${D}(version $VERSION)${Z}"

# Hyprland config: Lua needs Hyprland 0.55+
HV=""
if have hyprctl && hypr_running; then HV=$(hyprctl version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
elif have Hyprland; then HV=$(Hyprland --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1); fi
if [ -n "$HV" ]; then ok "Hyprland $HV"; else info "Hyprland: not found / version unknown"; fi
HAVE_CFG=0; [ -f "$HYPR_DEST/hyprland.lua" ] || [ -f "$HYPR_DEST/hyprland.conf" ] && HAVE_CFG=1
SRC_HYPR="$HERE/hypr"
[ -d "$SRC_HYPR" ] || { [ "$HYPR" = skip ] || [ "$HYPR" = merge ] || { echo "The preconfigured Hyprland files are missing ($SRC_HYPR)." >&2; exit 1; }; }

if [ "$HYPR" = auto ]; then
    HYPR=full
    if [ "$HAVE_CFG" = 1 ]; then
        if grep -qsE 'SekaiPop( \(pjsekai\))?: Hyprland configuration' "$HYPR_DEST/hyprland.lua" 2>/dev/null; then
            info "your Hyprland config is already the sekaipop one: it will be updated (your custom/ folder is kept)"
        else
            warn "you already have a Hyprland config in $HYPR_DEST."
            info "'full' replaces it with the sekaipop one (keybinds, rules, autostart). Yours is moved to"
            info "$CFG/hypr.sekaipop-backup-$TS and  ./install.sh --restore  puts it back."
            ask "Replace it? (n = keep yours and only add the small sekaipop_session file)" || HYPR=merge
        fi
    fi
fi
if [ "$HYPR" = full ] && [ -n "$HV" ] && ! ver_ge "$HV" 0.55; then
    warn "Hyprland $HV is older than 0.55, which is the first with the Lua config this installer writes."
    warn "Falling back to 'merge' (your hyprlang config stays; a small sekaipop_session.conf is added)."
    HYPR=merge
fi
info "Hyprland config mode: $HYPR"

# ------------------------------------------------------------------ Spotify / Discord: ask now
# Asked before the long package step, so the rest runs without waiting on you. Each says what it
# downloads and changes; nothing happens without a yes (docs/SPOTIFY-DISCORD-THEME.md).
APPSETUP="$RICE/scripts/theming/app-setup.sh"
SPOTIFY_STATE=none; DISCORD_STATE=none
if [ -f "$APPSETUP" ]; then
    SPOTIFY_STATE=$(bash "$APPSETUP" state spotify); DISCORD_STATE=$(bash "$APPSETUP" state discord)
    for app in spotify discord; do
        if [ "$app" = spotify ]; then ans=$SPOTIFY; st=$SPOTIFY_STATE; name=Spotify; else ans=$DISCORD; st=$DISCORD_STATE; name=Discord; fi
        if [ "$st" = none ]; then
            [ "$ans" = yes ] && warn "--$app yes: $name is not installed, so its theme is skipped"
            ans=no
        elif [ "$ans" = ask ]; then
            if [ "$st" = ready ]; then
                ok "$name theme is set up (kept as it is)"; ans=no
            else
                bash "$APPSETUP" explain "$app"
                if ask_no "Set up the $name theme?"; then ans=yes; else ans=no; info "$name theme: skipped (later: ./install.sh --$app yes)"; fi
            fi
        fi
        if [ "$app" = spotify ]; then SPOTIFY=$ans; else DISCORD=$ans; fi
    done
else
    SPOTIFY=no; DISCORD=no
fi

# The SDDM login screen: asked here too, so the long step runs on its own (docs/SDDM.md).
SDDMSH="$RICE/scripts/theming/sddm-theme.sh"
if [ -f "$SDDMSH" ] && have sddm; then
    if [ "$SDDM" = ask ]; then
        if [ "$(sh "$SDDMSH" status)" = on ]; then ok "SDDM login screen is SekaiPop's (kept as it is)"; SDDM=no
        else
            sh "$SDDMSH" explain
            if ask_no "Use SekaiPop's login screen (SDDM)?"; then SDDM=yes; else SDDM=no; info "SDDM login screen: skipped (later: ./install.sh --sddm yes)"; fi
        fi
    fi
else
    [ "$SDDM" = yes ] && warn "--sddm yes: SDDM is not installed, so its login theme is skipped"
    SDDM=no
fi

# ------------------------------------------------------------------ 1. dependencies
if [ "$NODEPS" = 0 ]; then
    step "1. Dependencies, fonts, services"
    FLAGS=()
    [ "$DRY" = 1 ] && FLAGS+=(--dry-run)
    [ "$YES" = 1 ] && FLAGS+=(--yes)
    [ "$HYPR" != merge ] && FLAGS+=(--no-session)    # full/skip handle the session themselves
    FLAGS+=(--spotify "$SPOTIFY" --discord "$DISCORD" --sddm "$SDDM")  # already answered above
    SEKAIPOP_FULL_INSTALL=1 bash "$HERE/install-deps.sh" "${FLAGS[@]}" "${DEPS_ARGS[@]}" || fail "install-deps.sh reported problems (see above)"

    if [ "$HYPR" = full ] && have pacman; then
        # used by the keybinds / autostart of the preconfigured config
        EXTRA=()
        for p in playerctl hypridle; do pacman -T "$p" >/dev/null 2>&1 || EXTRA+=("$p"); done
        if [ "${#EXTRA[@]}" -gt 0 ]; then
            info "for the keybinds and idle lock: ${EXTRA[*]}"
            PF=(--needed); [ "$YES" = 1 ] && PF+=(--noconfirm)
            run sudo pacman -S "${PF[@]}" "${EXTRA[@]}" || fail "could not install ${EXTRA[*]}"
        fi
    fi
else
    step "1. Dependencies"; info "skipped (--no-deps)"
fi

# The commit the installed copy came from (written by the last install), before it is replaced:
# step 3 asks git for the Hyprland files that commit shipped, to tell your edits from updates.
OLD_COMMIT=$(sed -n 's/^commit=//p' "$QS_DEST/.source" 2>/dev/null | head -1)

# ------------------------------------------------------------------ 2. the rice
step "2. The rice -> $QS_DEST"
if [ -d "$QS_DEST" ] && [ "$(realpath "$QS_DEST")" = "$RICE" ]; then
    ok "the rice is already in place (installing from the same folder)"
elif [ -d "$QS_DEST" ] && diff -rq --exclude=tests --exclude=.git --exclude=.source "$RICE" "$QS_DEST" >/dev/null 2>&1; then
    ok "the installed copy is already identical to this one"
else
    if [ -e "$QS_DEST" ]; then
        info "an existing copy is there: it is kept as $QS_DEST.bak-$TS"
        ask "Replace it with version $VERSION?" || { echo "Stopped by you."; exit 0; }
        run mv "$QS_DEST" "$QS_DEST.bak-$TS" || fail "could not back up the old rice"
    fi
    run mkdir -p "$(dirname "$QS_DEST")"
    run cp -a "$RICE" "$QS_DEST" && REPLACED=1 || fail "could not copy the rice"
    run rm -rf "$QS_DEST/.git"
    [ "$WITH_TESTS" = 1 ] || run rm -rf "$QS_DEST/tests"
    [ "$DRY" = 1 ] || ok "copied (tests folder $([ "$WITH_TESTS" = 1 ] && echo kept || echo left out))"
fi

# Remember which commit these files came from, so About / Update -> "Update now" can tell what is newer.
# (Only when installing from a git checkout, which is what get.sh does; a zip has no commit to record.)
if [ "$DRY" != 1 ] && [ -d "$HERE/.git" ] && have git && [ -d "$QS_DEST" ] && [ "$(realpath "$QS_DEST")" != "$RICE" ]; then
    {
        echo "commit=$(git -C "$HERE" rev-parse HEAD)"
        echo "repo=$(git -C "$HERE" config --get remote.origin.url)"
        echo "ref=$(git -C "$HERE" rev-parse --abbrev-ref HEAD)"
        echo "src=$HERE"
    } > "$QS_DEST/.source" 2>/dev/null || true
fi

# shaders: .qsb files are built with Qt 6.12 and older Qt cannot read them
QTV=$(pacman -Q qt6-base 2>/dev/null | awk '{print $2}' | grep -oE '^[0-9]+\.[0-9]+')
if [ -n "$QTV" ] && ! ver_ge "$QTV" 6.12; then
    info "Qt $QTV is older than 6.12: rebuilding the shaders once"
    if [ -f "$QS_DEST/shaders/compile-shaders.sh" ]; then
        run bash "$QS_DEST/shaders/compile-shaders.sh" || fail "shader build failed (needs qt6-shadertools)"
    fi
elif [ -n "$QTV" ]; then
    ok "Qt $QTV: the shipped shaders work as they are"
fi

# ------------------------------------------------------------------ 2b. bundled plugins
# Every folder with a plugin.json in ./plugins (next to the rice) goes into the plugins folder, as a
# copy or, with --plugins link, as a link to this checkout (get.sh downloads into a temporary folder,
# so a link is only right for a checkout you keep). Only those ids are touched: any other plugin, and
# one installed from Settings > Get plugins (a link into the shell's own repository store, which the
# shell updates itself), is left exactly as it is. A folder that is replaced is moved to
# plugins.sekaipop-backup-<time>/ first, never deleted. A plugin's bar entry stays off until turned on.
PLUG_SRC="$(dirname "$RICE")/plugins"
PLUG_DEST="${SEKAIPOP_PLUGINS_DIR:-$CFG/sekaipop/plugins}"
PLUG_STORE="${XDG_DATA_HOME:-$HOME/.local/share}/sekaipop/plugin-repos"
PLUG_BACKUP="$CFG/sekaipop/plugins.sekaipop-backup-$TS"
PLUG_CHANGED=0
step "2b. Plugins -> $PLUG_DEST"
if [ "$PLUGINS" = skip ]; then
    info "skipped (--plugins skip)"
elif [ ! -d "$PLUG_SRC" ]; then
    info "no bundled plugins next to the rice"
else
    for src in "$PLUG_SRC"/*/; do
        src=${src%/}
        [ -f "$src/plugin.json" ] || continue
        id=$(basename "$src")
        dest="$PLUG_DEST/$id"
        # The folder name is the plugin's id (lower case, digits, dashes): the shell skips anything else.
        case "$id" in ''|*[!a-z0-9-]*|-*) warn "$id: not a valid plugin id, left out"; continue ;; esac
        target=""; [ -L "$dest" ] && target=$(readlink -f "$dest")
        if [ -n "$target" ] && case "$target" in "$PLUG_STORE"/*) true ;; *) false ;; esac; then
            warn "$id: installed from Settings > Get plugins, left as it is (remove it there to use the bundled one)"
            continue
        fi
        if [ "$PLUGINS" = link ] && [ "$target" = "$(readlink -f "$src")" ]; then
            ok "$id: already linked"; continue
        fi
        if [ "$PLUGINS" = copy ] && [ -d "$dest" ] && [ ! -L "$dest" ] \
            && diff -rq --exclude=tests --exclude=.git "$src" "$dest" >/dev/null 2>&1; then
            ok "$id: already up to date"; continue
        fi
        if [ -e "$dest" ] || [ -L "$dest" ]; then
            run mkdir -p "$PLUG_BACKUP" && run mv "$dest" "$PLUG_BACKUP/$id" \
                || { fail "$id: could not back up $dest, left as it is"; continue; }
            info "$id: the one there is kept in $PLUG_BACKUP/$id"
        fi
        run mkdir -p "$PLUG_DEST" || { fail "could not make $PLUG_DEST"; break; }
        if [ "$PLUGINS" = link ]; then
            run ln -s "$src" "$dest" && ok "$id: linked to $src" || { fail "$id: could not link it"; continue; }
        else
            run cp -a "$src" "$dest" || { fail "$id: could not copy it"; continue; }
            run rm -rf "$dest/.git"
            [ "$WITH_TESTS" = 1 ] || run rm -rf "$dest/tests"
            ok "$id: copied"
        fi
        PLUG_CHANGED=1
    done
    [ "$PLUG_CHANGED" = 1 ] && info "a plugin's bar entry stays off until you turn it on: Settings > Bar > Modules"
fi

# ------------------------------------------------------------------ optional Kitty colours
step "Kitty colours"
KITTY_THEME="$RICE/scripts/theming/app-theme.sh"
if [ ! -f "$RICE/scripts/theming/kitty-theme.py" ]; then
    if [ "$KITTY" = enable ]; then
        fail "This rice does not include the Kitty configuration checker."
    else
        warn "This rice does not include the Kitty configuration checker."
    fi
else
    # Detect the choice before asking. Only enable requests the helper's audit;
    # unrelated errors must not prevent the prompt or a routine reinstall.
    kitty_status=$(sh "$KITTY_THEME" status kitty) || kitty_status=conflict
    if [ "$KITTY" = auto ] && [ "$FIRST_INSTALL" = 1 ] && [ "$kitty_status" = off ] &&
        [ "$YES" = 0 ] && [ "$DRY" = 0 ] && [ -t 0 ]; then
        read -r -p "  Enable SekaiPop's dynamic Kitty colours? [y/N] " answer
        case "$answer" in y|Y|yes|YES) KITTY=enable ;; esac
    fi
    if [ "$KITTY" = enable ]; then
        KITTY_FLAGS=()
        [ "$DRY" = 1 ] && KITTY_FLAGS+=(--dry-run)
        if sh "$KITTY_THEME" enable kitty "${KITTY_FLAGS[@]}"; then
            if [ "$DRY" = 0 ]; then
                ok "Kitty hook is ready; palette sync is not yet confirmed."
                info "Start or restart SekaiPop with the same KITTY_CONFIG_DIRECTORY to supply the palette."
            fi
        else
            fail "Kitty colour sync could not be enabled (see above)"
        fi
    else
        info "Keeping the current Kitty colour choice."
        case "$kitty_status" in
            off|missing|on) ;;
            pending) info "Kitty integration is waiting for the current palette; start or restart SekaiPop." ;;
            blocked|conflict)
                warn "Kitty integration needs review; no Kitty configuration was changed."
                info "Inspect it with: sh \"$KITTY_THEME\" check kitty"
                ;;
            *) warn "Could not determine Kitty integration status; no Kitty configuration was changed." ;;
        esac
    fi
fi

# ------------------------------------------------------------------ terminal look
# Kitty's font / padding / cursor (terminal-look.sh), neofetch with the Quick Panel banner
# (neofetch-setup.sh) and the App colours "Terminal prompt" switch (bash and fish). Each part
# keeps a backup or a marked line and has its own revert (docs/TERMINAL.md).
step "Terminal look"
TLOOK="$RICE/scripts/theming/terminal-look.sh"
TFETCH="$RICE/scripts/theming/neofetch-setup.sh"
if [ "$TERMINAL" = no ]; then
    info "skipped (--terminal no)"
elif [ ! -f "$TLOOK" ] || [ ! -f "$TFETCH" ]; then
    warn "this rice has no terminal-look scripts; skipped"
else
    T_ALL=0
    { [ "$TERMINAL" = yes ] || [ "$FIRST_INSTALL" = 1 ]; } && T_ALL=1
    if have kitty; then
        if [ "$T_ALL" = 1 ] || [ "$(sh "$TLOOK" status)" = on ]; then
            if [ "$DRY" = 1 ]; then info "would run: sh $TLOOK enable"
            else out=$(sh "$TLOOK" enable 2>&1) && ok "Kitty look: ${out#terminal-look: }" || warn "Kitty look: $out"; fi
        else info "Kitty look: off (turn it on with: sh \"$TLOOK\" enable)"; fi
    else
        info "Kitty isn't installed: no Kitty look"
    fi
    if have neofetch; then
        if [ "$T_ALL" = 1 ] || [ "$(sh "$TFETCH" status)" = on ]; then
            if [ "$DRY" = 1 ]; then info "would run: sh $TFETCH enable"
            else out=$(sh "$TFETCH" enable 2>&1) && ok "neofetch: banner card on (picture: Settings > General > Quick Panel)" || warn "neofetch: $out"; fi
        else info "neofetch: off (turn it on with: sh \"$TFETCH\" enable)"; fi
    else
        info "neofetch isn't installed (AUR: neofetch): no banner card"
    fi
    if [ "$T_ALL" = 1 ]; then
        SEKAIPOP_DRY=$DRY bash "$APPSETUP" prompt-on || warn "Terminal prompt: could not turn the switch on"
    fi
fi

# ------------------------------------------------------------------ SDDM login screen (with --no-deps)
if [ "$SDDM" = yes ] && [ "$NODEPS" = 1 ]; then
    step "SDDM login screen"
    SDDMF=(--select); [ "$DRY" = 1 ] && SDDMF+=(--dry-run)
    sh "$SDDMSH" install "${SDDMF[@]}" && { [ "$DRY" = 1 ] || ok "SDDM login screen: SekaiPop's"; } || fail "SDDM login screen: could not install the theme (see above)"
fi

# ------------------------------------------------------------------ Spotify and Discord themes
if [ "$SPOTIFY" = yes ] || [ "$DISCORD" = yes ]; then
    step "Spotify and Discord themes"
    export SEKAIPOP_DRY=$DRY SEKAIPOP_YES=$YES
    if [ "$SPOTIFY" = yes ]; then
        # with --no-deps step 1 didn't run: do its part (Spicetify, the folder) here
        [ "$NODEPS" = 1 ] && { bash "$APPSETUP" spotify-deps || fail "Spotify theme: could not finish (see above)"; }
        bash "$APPSETUP" spotify-on || fail "Spotify theme: could not turn the switch on"
    fi
    if [ "$DISCORD" = yes ]; then
        [ "$NODEPS" = 1 ] && { bash "$APPSETUP" vencord-patch || fail "Discord theme: Vencord could not be installed (see above)"; }
        bash "$APPSETUP" vencord-theme || fail "Discord theme: could not tick the theme"
    fi
fi

# monitors.lua is made for THIS machine, never shipped: a file written for someone else's screens
# (a disabled laptop panel, an output that does not exist here) is what gives a black screen.
# Reads the connected outputs from the kernel (works on a TTY and inside Hyprland), writes one rule
# per output in the same layout nwg-displays uses, so the shell's Settings > Displays can edit it.
# Resolution is the panel's preferred one. The kernel's mode list has no refresh rates, and a rule
# with only WIDTHxHEIGHT can leave a 144 Hz screen on 60 Hz, so when Hyprland is already running
# (best_mode below) the highest refresh rate it offers at that resolution is written too.
# Nothing is disabled and nothing is placed by hand (position = "auto").
best_mode() { # best_mode <output> <WxH>  ->  prints WxH@Hz (highest Hz offered at that size), or nothing
    command -v hyprctl >/dev/null 2>&1 || return 1
    hyprctl monitors all 2>/dev/null | awk -v out="$1" -v res="$2" '
        /^Monitor /   { cur = $2 }
        /availableModes:/ && cur == out {
            for (i = 2; i <= NF; i++) {
                split($i, a, "@")
                if (a[1] == res) { hz = a[2]; sub(/Hz$/, "", hz); if (hz + 0 > best) { best = hz + 0; bs = hz } }
            }
        }
        END { if (bs != "") printf "%s@%s", res, bs }'
}

gen_monitors_lua() { # gen_monitors_lua <file>
    local out=$1 dir=${SEKAIPOP_DRM_DIR:-/sys/class/drm} d n st m b names=()
    for d in "$dir"/card*-*; do
        [ -e "$d/status" ] || continue
        st=$(cat "$d/status" 2>/dev/null)
        [ "$st" = connected ] || continue
        n=${d##*/}; n=${n#card*-}
        names+=("$n")
    done
    {
        printf '%s\n' '-- Made by the sekaipop installer for the screens found at install time.'
        printf '%s\n' "-- Change it in the shell's Settings > Hyprland > Displays, or with nwg-displays."
        printf '%s\n' '-- Outputs that are not listed here are set up by Hyprland itself (preferred mode, auto position).'
        if [ "${#names[@]}" -eq 0 ]; then
            printf '%s\n' '-- No connected output was found while installing, so there are no rules: Hyprland uses its defaults.'
        else
            while IFS= read -r n; do
                [ -n "$n" ] || continue
                set -- "$dir"/card*-"$n"/modes
                m=$(head -n1 "$1" 2>/dev/null | sed 's/[^0-9x].*//')
                b=$(best_mode "$n" "$m") && [ -n "$b" ] && m=$b
                printf '\nhl.monitor({\n    output = "%s",\n    mode = "%s",\n    position = "auto",\n    scale = 1,\n    vrr = 0\n})\n' \
                    "$n" "${m:-preferred}"
            done < <(printf '%s\n' "${names[@]}" | sort -u)
        fi
    } > "$out"
}

# keep_your_edits <old config> <new config being built>
# The new config starts as the shipped files. For each one you had too, compared with what was
# shipped LAST time (the base: .sekaipop-shipped/ kept by the last install, else that commit's
# files from git):
#   you didn't change it                  the new one
#   you changed it, the update didn't     yours
#   both changed it                       merged (diff3); if the two clash: yours, and the new one
#                                         beside it as <file>.sekaipop-new
#   no base to compare with               the new one, yours beside it as <file>.sekaipop-yours
# Whitespace-only edits (an editor reformatting a file) count as not changed. A file you added (not
# shipped then or now) is kept; one the update removed is dropped unless you had changed it.
# monitors.lua, workspaces.lua, sekaipop_overrides.lua and custom/ are copied whole before this.
keep_your_edits() {
    local old=$1 new=$2 base f rel kept=() merged=() clashed=() unsure=() added=() dropped=()
    base=$(mktemp -d) || return 0
    if [ -d "$old/.sekaipop-shipped" ]; then
        cp -a "$old/.sekaipop-shipped/." "$base/"
    elif [ -n "${OLD_COMMIT:-}" ] && have git && git -C "$HERE" cat-file -e "$OLD_COMMIT:hypr" 2>/dev/null; then
        git -C "$HERE" archive "$OLD_COMMIT" hypr 2>/dev/null | tar -x -C "$base" --strip-components=1 2>/dev/null
    fi
    local have_base=0; [ -n "$(ls -A "$base" 2>/dev/null)" ] && have_base=1
    same() { [ -f "$1" ] && [ -f "$2" ] && diff -q -w -B "$1" "$2" >/dev/null 2>&1; }
    while IFS= read -r -d '' f; do
        rel=${f#"$old"/}
        case "$rel" in
            monitors.lua|workspaces.lua|sekaipop_overrides.lua|custom/*|.sekaipop-shipped/*|*.sekaipop-new|*.sekaipop-yours) continue ;;
        esac
        if [ -f "$new/$rel" ]; then
            same "$f" "$new/$rel" && continue                       # already the same
            if [ "$have_base" = 1 ] && [ -f "$base/$rel" ]; then
                same "$f" "$base/$rel" && continue                  # you didn't change it: the update
                if same "$base/$rel" "$new/$rel"; then              # only you changed it: yours
                    cp -a "$f" "$new/$rel"; kept+=("$rel")
                elif diff3 -m "$f" "$base/$rel" "$new/$rel" > "$new/$rel.merge" 2>/dev/null; then
                    mv "$new/$rel.merge" "$new/$rel"; merged+=("$rel")
                else
                    rm -f "$new/$rel.merge"
                    mv "$new/$rel" "$new/$rel.sekaipop-new"; cp -a "$f" "$new/$rel"; clashed+=("$rel")
                fi
            else
                cp -a "$f" "$new/$rel.sekaipop-yours"; unsure+=("$rel")
            fi
        elif [ "$have_base" = 1 ] && [ -f "$base/$rel" ]; then
            same "$f" "$base/$rel" || { mkdir -p "$(dirname "$new/$rel")"; cp -a "$f" "$new/$rel.sekaipop-yours"; dropped+=("$rel"); }
        else
            mkdir -p "$(dirname "$new/$rel")"; cp -a "$f" "$new/$rel"; added+=("$rel")
        fi
    done < <(find "$old" -type f -print0)
    rm -rf "$base"
    for rel in "${kept[@]}"; do ok "kept your edits to $rel"; done
    for rel in "${merged[@]}"; do ok "kept your edits to $rel (merged with the update)"; done
    for rel in "${added[@]}"; do ok "kept your file $rel"; done
    for rel in "${clashed[@]}"; do warn "kept YOUR $rel: the update changed the same lines, its version is $rel.sekaipop-new"; done
    for rel in "${unsure[@]}"; do warn "$rel: installed the new one; yours is beside it as $rel.sekaipop-yours"; done
    for rel in "${dropped[@]}"; do warn "$rel: the update removed it; your edited copy is kept as $rel.sekaipop-yours"; done
    [ "${#clashed[@]}" -gt 0 ] || [ "${#unsure[@]}" -gt 0 ] || [ "${#dropped[@]}" -gt 0 ] && info "tip: changes in $HYPR_DEST/custom/ never need merging"
    return 0
}

# ------------------------------------------------------------------ 3. Hyprland
step "3. Hyprland"
# Your own config is saved under a time-stamped name (and kept for good: --restore uses it).
# Re-running the installer on a config that is already ours only keeps one rolling "previous" copy,
# so it can never push your original out of reach.
OURS=0; grep -qsE 'SekaiPop( \(pjsekai\))?: Hyprland configuration' "$HYPR_DEST/hyprland.lua" 2>/dev/null && OURS=1
if [ "$OURS" = 1 ]; then BACKUP_TO="$CFG/hypr.sekaipop-previous"; else BACKUP_TO="$CFG/hypr.sekaipop-backup-$TS"; fi
case "$HYPR" in
  skip) info "left alone (--hypr skip). Start the shell yourself with:  qs -c sekaipop" ;;
  merge)
    if [ "$NODEPS" = 1 ]; then
        info "your config was kept. No session file was written because of --no-deps; add it with:"
        info "  ./install-deps.sh --no-update --core-only"
    else
        info "your config was kept; install-deps.sh added sekaipop_session.* to it (see above)"
    fi ;;
  full)
    if [ "$DRY" = 1 ]; then
        info "would build the new config from $SRC_HYPR"
        [ -e "$HYPR_DEST" ] && info "would move $HYPR_DEST to $BACKUP_TO"
        info "would keep your monitors.lua, workspaces.lua, sekaipop_overrides.lua and custom/ folder"
        info "would keep your own edits to the shipped files, and files you added"
        [ -f "$HYPR_DEST/monitors.lua" ] || info "would make a monitors.lua for the screens connected to this machine"
    else
        mkdir -p "$CFG"
        NEW=$(mktemp -d "$CFG/.hypr-sekaipop-new.XXXXXX") || { fail "could not create a temporary folder in $CFG"; NEW=""; }
        if [ -n "$NEW" ]; then
            cp -a "$SRC_HYPR/." "$NEW/"
            for f in monitors.lua workspaces.lua sekaipop_overrides.lua; do
                [ -f "$HYPR_DEST/$f" ] && cp -a "$HYPR_DEST/$f" "$NEW/$f"
            done
            if [ -d "$HYPR_DEST/custom" ]; then mkdir -p "$NEW/custom"; cp -a "$HYPR_DEST/custom/." "$NEW/custom/"; fi
            [ -d "$HYPR_DEST" ] && keep_your_edits "$HYPR_DEST" "$NEW"
            # What was shipped this time, so the next install can tell your edits from updates.
            rm -rf "$NEW/.sekaipop-shipped"; mkdir -p "$NEW/.sekaipop-shipped" && cp -a "$SRC_HYPR/." "$NEW/.sekaipop-shipped/"
            if [ ! -f "$NEW/monitors.lua" ]; then
                if gen_monitors_lua "$NEW/monitors.lua"; then
                    ok "monitors.lua made for the screens connected now: $(grep -o 'output = "[^"]*"' "$NEW/monitors.lua" | cut -d'"' -f2 | paste -sd' ' -)"
                else
                    rm -f "$NEW/monitors.lua"; warn "could not make monitors.lua: Hyprland will use its defaults"
                fi
            fi
            find "$NEW" -name '*.sh' -exec chmod +x {} +
            if [ -e "$HYPR_DEST" ]; then
                [ "$OURS" = 1 ] && rm -rf "$BACKUP_TO"      # only one rolling copy of a previous sekaipop config
                mv "$HYPR_DEST" "$BACKUP_TO" || fail "could not back up $HYPR_DEST"
                info "old config kept as $BACKUP_TO"
            fi
            if mv "$NEW" "$HYPR_DEST"; then
                ok "installed $HYPR_DEST ${D}(put your own changes in $HYPR_DEST/custom/)${Z}"
                # hypridle.conf takes its idle times from the shell's own file (Settings > General >
                # Idle & sleep). Make it with the out-of-the-box times if there is none yet, and
                # restart hypridle, which reads its config only when it starts.
                IDLE_SH="$HERE/sekaipop/scripts/system/idle-config.sh"
                if [ ! -f "$CFG/sekaipop/idle.conf" ]; then
                    XDG_CONFIG_HOME="$CFG" sh "$IDLE_SH" write 300 600 900 suspend >/dev/null || warn "could not write $CFG/sekaipop/idle.conf"
                else
                    XDG_CONFIG_HOME="$CFG" sh "$IDLE_SH" restart || warn "could not restart hypridle: log in again for the idle times"
                fi
            else
                fail "could not move the new config into place"
                [ -e "$BACKUP_TO" ] && [ ! -e "$HYPR_DEST" ] && mv "$BACKUP_TO" "$HYPR_DEST"
            fi
        fi
    fi
    ;;
esac

# login session
if [ -f /usr/share/wayland-sessions/hyprland.desktop ]; then
    ok "login session 'Hyprland' is installed (pick it, not the 'uwsm' one, in your login screen)"
else
    warn "no Hyprland session file found in /usr/share/wayland-sessions: is the hyprland package installed?"
fi

# ------------------------------------------------------------------ done
step "Done"
if [ "${#FAILED[@]}" -gt 0 ]; then
    printf '  %s%d problem(s):%s\n' "$R" "${#FAILED[@]}" "$Z"
    for m in "${FAILED[@]}"; do printf '    %s%s%s %s\n' "$R" "$G_BAD" "$Z" "$m"; done
fi
if [ "$DRY" = 0 ] && [ -f "$HERE/check-deps.sh" ]; then
    printf '\n'; SEKAIPOP_DIR="$QS_DEST" bash "$HERE/check-deps.sh" --core
fi

# A shell that is already running keeps the old files: the folder it watches was moved
# aside, and a reload inside the same process can fail on Qt state left from them
# ("FaceKey is not a type", issue #79). So it is restarted, as a new process.
# Skip mode leaves the restart to the user because startup can write Hyprland overrides,
# unless --reload yes asks for it.
shell_running() { have qs && ! qs list -p "$QS_DEST" 2>/dev/null | grep -q "No running instances"; }
restart_shell() {
    setsid -f sh "$QS_DEST/scripts/system/restart-shell.sh" "$QS_DEST" >/dev/null 2>&1 && ok "shell restarted on the new files"
}
# Reload Hyprland and say what came of it: a reload that fails, or a config Hyprland only
# partly accepted, used to look exactly like one that worked (the output went to /dev/null).
reload_hypr() {
    local out errs
    out=$(hyprctl reload 2>&1)
    if [ "$out" = ok ]; then
        ok "Hyprland reloaded"
    else
        warn "Hyprland did not confirm the reload: ${out:-no answer}"
    fi
    sleep 0.5
    errs=$(hyprctl configerrors 2>/dev/null | grep -v '^[[:space:]]*$')
    if [ -n "$errs" ]; then
        warn "Hyprland reported problems in the config (the rest loaded):"
        printf '%s\n' "$errs" | head -n 8 | sed 's/^/      /'
        info "all of them: hyprctl configerrors   (and ~/.cache/sekaipop/hypr-errors.log)"
    fi
}
start_or_restart_shell() {
    if shell_running; then
        restart_shell
    elif ! pgrep -x qs >/dev/null && ! pgrep -x quickshell >/dev/null; then
        setsid -f qs -c sekaipop >/dev/null 2>&1 && ok "shell started"
    fi
}
if [ "$DRY" = 0 ] && [ "$RELOAD" != no ] && hypr_running; then
    if [ "$RELOAD" = yes ]; then
        printf '\n'
        reload_hypr
        start_or_restart_shell
    elif [ "$HYPR" = full ] || [ "$HYPR" = merge ]; then
        printf '\n'
        if ask "You are inside Hyprland now. Reload it and start the shell on the new files?"; then
            reload_hypr
            if [ "$REPLACED" = 1 ] || ! shell_running; then start_or_restart_shell; fi
        else
            info "not reloaded: run  hyprctl reload  and restart the shell (Ctrl+Super+R) when ready"
        fi
    elif [ "$REPLACED" = 1 ]; then
        warn "Hyprland was left alone (--hypr skip). Restart SekaiPop to load the installed shell (Ctrl+Super+R),"
        info "or run this again with  --reload yes  to reload Hyprland and restart the shell for you."
    fi
elif [ "$DRY" = 0 ] && [ "$RELOAD" != no ] && [ "$REPLACED" = 1 ] && shell_running; then
    # Not inside Hyprland (a TTY, another compositor): only the shell can be restarted.
    printf '\n'
    { [ "$RELOAD" = yes ] || ask "The shell is running on the old files. Restart it now?"; } && restart_shell
fi
# The rice unchanged but plugins added or replaced: a running shell reads its plugins folder again.
if [ "$DRY" = 0 ] && [ "$PLUG_CHANGED" = 1 ] && [ "$REPLACED" = 0 ] && shell_running; then
    qs -c sekaipop ipc call plugins reload >/dev/null 2>&1 && ok "the running shell read its plugins again"
fi
if [ "${#FAILED[@]}" -eq 0 ]; then
    [ "$DRY" = 1 ] && result ok "Dry run finished, nothing was changed" || result ok "SekaiPop is installed"
else
    result bad "Finished with ${#FAILED[@]} problem(s), see above"
fi
printf '\n  %sNext%s\n' "$B" "$Z"
nx "If you did not reload above: log out and back in (pick the plain Hyprland session)."
printf '      %sThe shell starts by itself. By hand:%s  %sqs -c sekaipop%s\n' "$D" "$Z" "$B" "$Z"
nx "Keybinds: ${B}Super + /${Z} opens the cheat sheet.  ${B}Super${Z} (tap) = apps.  ${B}Super + I${Z} = settings."
nx "Config mistakes are written to ${B}~/.cache/sekaipop/hypr-errors.log${Z} (the rest still loads)."
nx "Undo the Hyprland part:  ${B}./install.sh --restore${Z}"
[ "$SPOTIFY" = yes ] && nx "Spotify: press ${B}Ctrl+Shift+R${Z} in Spotify (or start it) to see the theme; it follows every theme change."
[ "$SDDM" = yes ] && nx "Login screen: SekaiPop's from the next login. Preview it now: ${B}sh $QS_DEST/scripts/theming/sddm-theme.sh preview${Z}  Undo: ${B}./install.sh --restore-sddm${Z}"
[ "$DISCORD" = yes ] && nx "Discord: quit it completely (tray > Quit) and start it again. In User Settings > Vencord > Themes, ${B}sekaipop.theme.css${Z} should be ticked (tick it if not)."
printf '\n'
[ "${#FAILED[@]}" -eq 0 ]
