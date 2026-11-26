#!/usr/bin/env bash
# app-setup.sh: what install.sh and install-deps.sh do for the Spotify and Discord themes
# (docs/SPOTIFY-DISCORD-THEME.md). The installers ask first; this only does what it is told.
#
#   app-setup.sh explain spotify|discord   what setting it up means (printed before the question)
#   app-setup.sh state spotify|discord     none | todo | ready   (none = the app isn't installed)
#   app-setup.sh spotify-deps              Spicetify (AUR spicetify-cli) + Spotify's folder writable (sudo)
#   app-setup.sh spotify-on                turn on Settings > Desktop > App colours > Spotify
#   app-setup.sh prompt-on                 turn on Settings > Desktop > App colours > Terminal prompt
#   app-setup.sh vencord-patch             download the official Vencord installer, patch Discord (sudo)
#   app-setup.sh vencord-theme             put sekaipop.theme.css in Vencord's themes and tick it
#
# SEKAIPOP_DRY=1 prints what would change and changes nothing; SEKAIPOP_YES=1 passes --noconfirm
# to the AUR helper. Exit: 0 done (or nothing to do), 1 failed, 3 the app isn't installed.
# For the tests: SEKAIPOP_SPOTIFY_DIR, SEKAIPOP_DISCORD_DIR and SEKAIPOP_VENCORD_URL replace the
# detected folders and the download address.

set -u
DRY=${SEKAIPOP_DRY:-0}; YES=${SEKAIPOP_YES:-0}
CFG=${XDG_CONFIG_HOME:-$HOME/.config}
CACHE=${XDG_CACHE_HOME:-$HOME/.cache}
HERE=$(cd "$(dirname "$0")" && pwd)
VENCORD_URL=${SEKAIPOP_VENCORD_URL:-https://github.com/Vencord/Installer/releases/latest/download/VencordInstallerCli-linux}
THEME_FILE=sekaipop.theme.css

# the installers' look (same symbols and colours)
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    B=$'\e[1m'; D=$'\e[2m'; Z=$'\e[0m'; PK=$'\e[38;5;211m'; Y=$'\e[38;5;221m'; R=$'\e[38;5;203m'; GR=$'\e[38;5;114m'
else B=; D=; Z=; PK=; Y=; R=; GR=; fi
case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in *[Uu][Tt][Ff]-8*|*[Uu][Tt][Ff]8*) U=1 ;; *) U=0 ;; esac
[ "${TERM:-}" = linux ] && U=0
if [ "$U" = 1 ]; then G_OK='✔'; G_BAD='✘'; G_DOT='•'; G_ARR='›'; else G_OK='+'; G_BAD='x'; G_DOT='-'; G_ARR='>'; fi
info() { printf '  %s%s%s %s\n' "$D" "$G_DOT" "$Z" "$1"; }
ok()   { printf '  %s%s%s %s\n' "$GR" "$G_OK" "$Z" "$1"; }
warn() { printf '  %s!%s %s%s%s\n' "$Y" "$Z" "$Y" "$1" "$Z"; }
bad()  { printf '  %s%s%s %s%s%s\n' "$R" "$G_BAD" "$Z" "$R" "$1" "$Z"; }
have() { command -v "$1" >/dev/null 2>&1; }
run() {
    if [ "$DRY" = 1 ]; then printf '  %s%s%s %swould run%s' "$PK" "$G_ARR" "$Z" "$D" "$Z"; printf ' %q' "$@"; printf '\n'; return 0; fi
    "$@"
}

# ===== where things are =====
spotify_dir() {
    if [ -n "${SEKAIPOP_SPOTIFY_DIR:-}" ]; then [ -d "$SEKAIPOP_SPOTIFY_DIR" ] && echo "$SEKAIPOP_SPOTIFY_DIR"; return; fi
    local d
    for d in /opt/spotify "$HOME/.local/share/spotify-launcher/install/usr/share/spotify" /usr/share/spotify \
             /var/lib/flatpak/app/com.spotify.Client/x86_64/stable/active/files/extra/share/spotify \
             "$HOME/.local/share/flatpak/app/com.spotify.Client/x86_64/stable/active/files/extra/share/spotify"; do
        [ -d "$d" ] && { echo "$d"; return; }
    done
}
spicetify_bin() {
    if have spicetify; then command -v spicetify
    elif [ -x "$HOME/.spicetify/spicetify" ]; then echo "$HOME/.spicetify/spicetify"; fi
}
# Spicetify rewrites files in Spotify's folder and in Apps/ (it does not need root once these are yours)
spotify_writable() {
    local d=$1
    [ -w "$d" ] || return 1
    [ -d "$d/Apps" ] || return 0
    [ -z "$(find "$d/Apps" ! -writable -print -quit 2>/dev/null)" ]
}
# Discord's resources folder (the one with app.asar) in a Discord install folder. Two layouts, the
# same two the Vencord installer knows (find_discord_linux.go):
#   system:  /opt/discord/resources  (older packages, flatpak)
#   updater: ~/.config/discord/app-<version>/resources  (Discord's own self-updating client; the
#            newest app-* is the live one). This one is yours, so patching it needs no sudo.
resources_of() {
    local d=$1 r
    [ -e "$d/resources/app.asar" ] && { echo "$d/resources"; return; }
    r=$(find "$d" -mindepth 2 -maxdepth 2 -path "$d/app-*/resources" -type d 2>/dev/null | sort -V | tail -n 1)
    [ -n "$r" ] && [ -e "$r/app.asar" ] && echo "$r"
}
discord_dir() {
    local d
    if [ -n "${SEKAIPOP_DISCORD_DIR:-}" ]; then
        [ -n "$(resources_of "$SEKAIPOP_DISCORD_DIR")" ] && echo "$SEKAIPOP_DISCORD_DIR"; return
    fi
    for d in "$CFG/discord" "$CFG/discordptb" "$CFG/discordcanary" /opt/discord /opt/discord-ptb /opt/discord-canary \
             /usr/lib/discord /usr/share/discord /usr/lib64/discord "$HOME/.local/share/discord"; do
        [ -d "$d" ] && [ -n "$(resources_of "$d")" ] && { echo "$d"; return; }
    done
}
has_vesktop() { have vesktop || [ -d "$CFG/vesktop" ]; }
# The Vencord installer keeps Discord's own app.asar as _app.asar next to its loader. A Discord update
# (a new app-<version> folder, or the package rewriting it) brings an unpatched one back.
vencord_patched() { local r; r=$(resources_of "$1"); [ -n "$r" ] && [ -e "$r/_app.asar" ]; }
# Vencord's data folders that get the theme: Vencord itself (patched Discord), Vesktop, Equicord.
vencord_dirs() {
    local dd; dd=$(discord_dir)
    # Vencord makes ~/.config/Vencord at Discord's first start with it and then reads its settings
    # from there, so the theme and the tick can be put in place before that.
    { [ -n "$dd" ] || [ -d "$CFG/Vencord" ]; } && echo "$CFG/Vencord"
    has_vesktop && echo "$CFG/vesktop"
    [ -d "$CFG/Equicord" ] && echo "$CFG/Equicord"
}
theme_enabled() { grep -qs "\"$THEME_FILE\"" "$1/settings/settings.json"; }
discord_running() { pgrep -x -i 'discord|discordptb|discordcanary|vesktop' >/dev/null 2>&1; }

# ===== explain / state =====
explain() {
    case "$1" in
        spotify)
            printf '\n  %sSpotify theme%s %s(optional)%s\n' "$B" "$Z" "$D" "$Z"
            info "Spotify gets the shell's colours and blocks, and follows every theme change."
            info "Spotify can't load themes by itself, so this installs Spicetify (spicetify-cli,"
            info "from the AUR), which patches Spotify's own files."
            info "To let it, Spotify's folder ($(spotify_dir || echo /opt/spotify)) is made writable for"
            info "your user (sudo chmod a+wr). Spotify is never restarted: new colours show after"
            info "Ctrl+Shift+R in Spotify. A Spotify update undoes the patch until the next theme"
            info "change (or: spicetify backup apply). Undo: Settings > App colours > Spotify > Revert."
            ;;
        discord)
            printf '\n  %sDiscord theme%s %s(optional)%s\n' "$B" "$Z" "$D" "$Z"
            info "Discord gets the shell's colours and blocks, and recolours live with the theme."
            if [ -z "$(discord_dir)" ] && has_vesktop; then
                info "You use Vesktop, which has Vencord built in: nothing is downloaded, the theme is"
                info "only put in its themes folder and ticked."
            else
                info "Discord can't load themes by itself. This needs ${B}Vencord${Z}, a client mod, so it"
                info "DOWNLOADS the official Vencord installer (VencordInstallerCli-linux, from"
                info "github.com/Vencord/Installer), which downloads Vencord and patches Discord in"
                info "$(discord_dir || echo /opt/discord)$(r=$(resources_of "$(discord_dir)" 2>/dev/null); [ -n "$r" ] && [ -w "$r" ] || echo ' (with sudo)'). Then the theme is ticked in Vencord > Themes."
                info "Client mods are against Discord's terms of service (accounts are rarely acted on)."
                info "A Discord update can remove Vencord: run ./install.sh again. Undo: the Vencord"
                info "installer's Uninstall (vencord.dev/download)."
            fi
            ;;
        *) echo "explain spotify|discord" >&2; return 2 ;;
    esac
}

state() {
    case "$1" in
        spotify)
            local d; d=$(spotify_dir)
            [ -n "$d" ] || { echo none; return; }
            if [ -n "$(spicetify_bin)" ] && spotify_writable "$d" \
                && grep -qs '"appTheme.spotify": *true' "$CFG/sekaipop/settings.json"; then echo ready; else echo todo; fi
            ;;
        discord)
            local dd v all=1 any=0; dd=$(discord_dir)
            [ -n "$dd" ] || has_vesktop || { echo none; return; }
            [ -z "$dd" ] || vencord_patched "$dd" || all=0
            while IFS= read -r v; do [ -n "$v" ] || continue; any=1; theme_enabled "$v" || all=0; done < <(vencord_dirs)
            [ "$any" = 1 ] && [ "$all" = 1 ] && echo ready || echo todo
            ;;
        *) echo "state spotify|discord" >&2; return 2 ;;
    esac
}

# ===== Spotify =====
spotify_deps() {
    local d; d=$(spotify_dir)
    [ -n "$d" ] || { warn "Spotify is not installed (spotify from the AUR, or spotify-launcher): skipped"; return 3; }
    local rc=0
    if [ -n "$(spicetify_bin)" ]; then
        ok "Spicetify is installed"
    else
        local helper=""
        have yay && helper=yay
        [ -z "$helper" ] && have paru && helper=paru
        if [ -n "$helper" ]; then
            local f=(-S --needed); [ "$YES" = 1 ] && f+=(--noconfirm)
            # spicetify-cli's build runs `node scripts/build-wrapper.mjs`, but its PKGBUILD only
            # lists go and pnpm, and Arch's pnpm is a standalone binary that doesn't bring
            # nodejs: without node the build stops there. Install nodejs first (as a dependency,
            # so `pacman -Qdtq` can clean it up later). If the build still fails, the prebuilt
            # spicetify-bin (same tool, provides spicetify-cli) needs no build at all.
            if ! have node; then
                info "spicetify-cli's build needs nodejs, which its package doesn't pull in"
                run "$helper" "${f[@]}" --asdeps nodejs || warn "could not install nodejs; trying the build anyway"
            fi
            if run "$helper" "${f[@]}" spicetify-cli; then
                ok "installed Spicetify"
            elif warn "spicetify-cli didn't build; trying the prebuilt spicetify-bin" \
                && run "$helper" "${f[@]}" spicetify-bin; then
                ok "installed Spicetify (spicetify-bin)"
            else
                bad "could not install Spicetify from the AUR (spicetify-cli or spicetify-bin)"; rc=1
            fi
        else
            bad "no AUR helper (yay or paru): install spicetify-cli yourself, then run this again"; rc=1
        fi
    fi
    if spotify_writable "$d"; then
        ok "Spotify's folder is writable ($d)"
    else
        info "making $d writable for Spicetify"
        run sudo chmod a+wr "$d" && { [ ! -d "$d/Apps" ] || run sudo chmod a+wr "$d/Apps" -R; } \
            && ok "Spotify's folder is writable" || { bad "could not make $d writable"; rc=1; }
    fi
    # Spicetify reads Spotify's prefs file, which exists only after the first login.
    [ -f "$CFG/spotify/prefs" ] || warn "open Spotify and log in once (wait a minute): Spicetify needs its prefs file. The theme goes on at the next theme change."
    return $rc
}

shell_running() { have qs && qs -c sekaipop ipc call options get appTheme.spotify >/dev/null 2>&1; }

# switch_on <id> <label>: turn on Settings > Desktop > App colours > <label> (appTheme.<id>):
# through the running shell (which applies it at once), else in settings.json for the next start.
switch_on() {
    local id="$1" label="$2" f="$CFG/sekaipop/settings.json"
    if shell_running; then
        run qs -c sekaipop ipc call apptheme apply "$id" >/dev/null
        if [ "$DRY" = 1 ] || qs -c sekaipop ipc call options get "appTheme.$id" 2>/dev/null | grep -q true; then
            ok "$label switch is on (Settings > Desktop > App colours)"; return 0
        fi
        # an older shell that doesn't know the switch yet: write it for the next start
        warn "the running shell is older than this switch: it is saved and applies after the shell restarts"
    fi
    if [ "$DRY" = 1 ]; then printf '  %s%s%s %swould set%s appTheme.%s = true in %s\n' "$PK" "$G_ARR" "$Z" "$D" "$Z" "$id" "$f"; return 0; fi
    python3 -I - "$f" "appTheme.$id" <<'PY' || { bad "could not write $f"; return 1; }
import json, os, sys
p, key = sys.argv[1], sys.argv[2]
try:
    with open(p, encoding="utf-8") as fh:
        d = json.load(fh)
except FileNotFoundError:
    d = {}
except ValueError:
    sys.exit("unreadable settings.json")
if not isinstance(d, dict):
    sys.exit("unexpected settings.json")
d[key] = True
os.makedirs(os.path.dirname(p), exist_ok=True)
tmp = p + ".sekaipop-tmp"
with open(tmp, "w", encoding="utf-8") as fh:
    json.dump(d, fh, indent=2)
os.replace(tmp, p)
PY
    ok "$label switch is on (Settings > Desktop > App colours)"
}

spotify_on() { switch_on spotify Spotify; }

# ===== Discord =====
vencord_patch() {
    local dd; dd=$(discord_dir)
    if [ -z "$dd" ]; then
        has_vesktop && { ok "Vesktop has Vencord built in: nothing to download"; return 0; }
        warn "Discord is not installed: skipped"; return 3
    fi
    vencord_patched "$dd" && { ok "Discord already has Vencord ($dd)"; return 0; }
    have curl || { bad "curl is needed to download the Vencord installer"; return 1; }
    local tmp bin
    tmp=$(mktemp -d "${TMPDIR:-/tmp}/sekaipop-vencord.XXXXXX") || return 1
    bin="$tmp/VencordInstallerCli-linux"
    info "downloading the Vencord installer: $VENCORD_URL"
    if ! run curl -fL --proto '=https' --tlsv1.2 -o "$bin" "$VENCORD_URL"; then
        rm -rf "$tmp"; bad "could not download the Vencord installer"; return 1
    fi
    run chmod +x "$bin"
    # Discord's self-updating client lives in your home: no sudo. A system install needs it.
    local res asroot=(); res=$(resources_of "$dd")
    [ -w "$res" ] || asroot=(sudo)
    info "patching Discord in $dd (the installer downloads Vencord itself$([ "${#asroot[@]}" -gt 0 ] && echo '; asks for your password'))"
    if run "${asroot[@]}" "$bin" -install -location "$dd" </dev/null; then
        rm -rf "$tmp"
        ok "Vencord is in Discord"
        discord_running && warn "Discord is open: quit it completely (tray icon > Quit) and start it again"
        return 0
    fi
    rm -rf "$tmp"
    bad "the Vencord installer failed (see above)"
    return 1
}

vencord_theme() {
    local dirs; dirs=$(vencord_dirs)
    [ -n "$dirs" ] || { warn "no Vencord, Vesktop or Equicord found: run vencord-patch first"; return 3; }
    local rc=0 v src="$CACHE/sekaipop/discord/$THEME_FILE"
    while IFS= read -r v; do
        [ -n "$v" ] || continue
        run mkdir -p "$v/themes"
        # the shell keeps its latest theme here (and rewrites every themes folder on each change)
        if [ -f "$src" ]; then run cp "$src" "$v/themes/$THEME_FILE"
        else run env SEKAIPOP_DISCORD_DIRS="$v/themes" sh "$HERE/discord-theme.sh" write >/dev/null; fi
        if theme_enabled "$v"; then ok "$THEME_FILE is on in $(basename "$v")"; continue; fi
        # A Discord running Vencord could save its own settings over ours. With no settings file
        # Vencord has never run (it is being installed now), so an open Discord can't overwrite it.
        if discord_running && [ -f "$v/settings/settings.json" ]; then
            warn "Discord is open, so its settings can't be changed now: tick $THEME_FILE in"
            warn "User Settings > Vencord > Themes (or quit Discord and run ./install.sh again)"
            continue
        fi
        if [ "$DRY" = 1 ]; then printf '  %s%s%s %swould add%s %s to enabledThemes in %s\n' "$PK" "$G_ARR" "$Z" "$D" "$Z" "$THEME_FILE" "$v/settings/settings.json"; continue; fi
        if python3 -I - "$v/settings/settings.json" "$THEME_FILE" <<'PY'
import json, os, shutil, sys
p, name = sys.argv[1], sys.argv[2]
try:
    with open(p, encoding="utf-8") as fh:
        d = json.load(fh)
    shutil.copy2(p, p + ".sekaipop.bak")
except FileNotFoundError:
    d = {}
except ValueError:
    sys.exit("unreadable " + p)
if not isinstance(d, dict):
    sys.exit("unexpected " + p)
t = d.get("enabledThemes")
if not isinstance(t, list):
    t = []
if name not in t:
    t.append(name)
d["enabledThemes"] = t
os.makedirs(os.path.dirname(p), exist_ok=True)
tmp = p + ".sekaipop-tmp"
with open(tmp, "w", encoding="utf-8") as fh:
    json.dump(d, fh, indent=4)
os.replace(tmp, p)
PY
        then ok "$THEME_FILE is on in $(basename "$v") (Vencord > Themes)"
        else bad "could not tick the theme in $v/settings/settings.json: tick it in Vencord > Themes"; rc=1; fi
    done <<<"$dirs"
    return $rc
}

case "${1:-}" in
    explain) explain "${2:-}" ;;
    state) state "${2:-}" ;;
    spotify-deps) spotify_deps ;;
    spotify-on) spotify_on ;;
    prompt-on) switch_on prompt "Terminal prompt" ;;
    vencord-patch) vencord_patch ;;
    vencord-theme) vencord_theme ;;
    *) sed -n '2,17p' "$0" >&2; exit 2 ;;
esac
