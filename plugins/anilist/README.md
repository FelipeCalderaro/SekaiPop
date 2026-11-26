# AniList for SekaiPop

A SekaiPop bar plugin: what you are watching and reading on [AniList](https://anilist.co),
in the bar.

- **The bar entry** shows the next episode to air (`Ep 8 · 2d 4h`), or your last progress, how
  many you are on, or your notifications. An amber `+2` says episodes are out that you haven't
  watched. Middle-click opens your profile, right-click refreshes.
- **The popup** opens under it: a header plate in your profile colour (with your banner), your
  stats, then your current list with cover, progress bar, next-episode countdown, and a **+1** key
  to move your progress on (signed in).

It is built from the shell's own design language (docs/DESIGN-SYSTEM.md): blocks with hard
shadows, keys that sink and spring back, a printed plate, a stagger as the card opens.

## Install

`install.sh` installs it with the rest of SekaiPop: it copies every plugin in `plugins/` into
`~/.config/sekaipop/plugins/` (`--plugins link` links them to your checkout instead), and moves a
plugin folder it replaces to `~/.config/sekaipop/plugins.sekaipop-backup-<time>/` first.

Then turn the entry on: **Settings > Bar > Modules > AniList** (or
`qs -c sekaipop ipc call plugins bar anilist on`), and place it in **Edit Desktop > BAR** if you like.

Needs `curl`; signing in also uses `python3` (a tiny listener on localhost) and *Copy* uses
`wl-copy`.

## Connect your account, from the popup

Click the entry. Until it is connected, the card opens on its **account page**; later, the
person / sign-in key at the bottom brings it back.

**Public profile (read only).** Type your username (or paste your profile link) and press
**Use**. Your list must be public on AniList.

**Sign in (private lists, notifications, +1).** The card walks you through it:

1. **Once:** make an API client on AniList (every app needs one; it takes a minute). The card's
   **Open** key goes to [Settings > Developer](https://anilist.co/settings/developer); its copy
   key copies the Redirect URL to give the client: `http://localhost:47823/callback`.
2. Paste the client's **ID** into the card.
3. **Sign in with AniList**, approve it in the browser, and you're done: the token comes back to
   the plugin by itself and the card switches to your list.

How the token gets back: `auth-callback.py` listens on 127.0.0.1 / ::1 only, for five minutes at
most, serves one page at `/callback` that reads the token from the address and hands it back
(only from that page), and exits. The plugin keeps it in `~/.config/sekaipop/anilist-token`
(mode 600), its secret: never in SekaiPop's settings or presets, never on a command line. AniList
tokens last a year; **Sign out** on the account page deletes the file.

Port 47823 taken? Change *Sign-in callback port* in the plugin's settings and use the matching
Redirect URL. Already have a token (from a client whose redirect URL is AniList's pin page)? Copy
it and press *paste it here* on the account page. Setting `ANILIST_TOKEN` in the shell's
environment works too.

## Settings

All of them are on the popup's **Settings page** (the tune key at the bottom), saved as you
pick, and in Settings > Desktop > Plugins > AniList.

| Setting | Choices | Default |
| --- | --- | --- |
| AniList username | text | — |
| API client ID | number | — |
| Lists | Anime, Manga, Both (a Watching / Reading switch in the popup) | Anime |
| Order | Airing soon, Recent | Airing soon |
| Entries in the popup | 3–25 | 8 |
| Bar shows | Next episode, Last progress, Count, Notifications | Next episode |
| Hide when the list is empty | on / off | off |
| Titles in | My AniList choice, Romaji, English, Native | My AniList choice |
| Header colour | Profile colour, Theme, Latest cover | Profile colour |
| Profile banner in the header | on / off | on |
| Check every | 5–120 minutes | 15 |
| Sign-in callback port | a port | 47823 |

```sh
qs -c sekaipop ipc call plugins set anilist barShows progress
qs -c sekaipop ipc call plugins popup anilist        # open / close it (for a keybind)
```

## How it talks to AniList

One GraphQL request per refresh (`https://graphql.anilist.co`): your profile and your CURRENT +
REPEATING lists together. It asks only while the entry is on a bar, every *Check every* minutes,
and again when the popup opens on data older than a minute. AniList allows about 30 requests a
minute; a "slow down" answer is shown and the next refresh tries again.

## Files

| File | What |
| --- | --- |
| `plugin.json` | Manifest: settings, their form, the `token` secret |
| `AniList.js` | Queries, parsing, and every word and number shown (pure functions) |
| `Service.qml` | The one connection: refresh, +1, sign in / out, settings from the popup |
| `Bar.qml` | The bar entry |
| `Popup.qml` | The popup: list, account and settings pages |
| `EntryRow.qml`, `Plate.qml`, `Key.qml`, `Field.qml`, `ChoiceRow.qml` | Its pieces |
| `auth-callback.py` | Catches the sign-in on localhost and hands the token to `Service.qml` |
| `tests/anilist_unit.js` | `node plugins/anilist/tests/anilist_unit.js` |
