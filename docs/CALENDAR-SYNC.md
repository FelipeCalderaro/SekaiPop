# Google calendars on the calendar card

Your Google Calendar events show on the desktop calendar card next to your own, read-only, from
as many calendars and accounts as you like. **No API key, no OAuth client, no sign-in.**

## Adding one

1. Open [Google Calendar](https://calendar.google.com) in a browser (the account the calendar is in).
2. Hover the calendar under *My calendars* > the three dots > **Settings and sharing**.
3. Scroll to **Integrate calendar** and copy **Secret address in iCal format**.
4. In SekaiPop: **Settings > Desktop > Google calendars**, type a name (optional), paste the link
   into *Secret iCal link* and press Enter.

Repeat for each calendar (work, personal, a shared family one, another account...). Any other
`.ics` / `webcal://` link works the same way (Outlook, iCloud, Proton, a sports schedule...).

The link **is** the access: anyone with it can read that calendar. If it leaks, press *Reset*
under the secret address in Google, then remove the old one here and add the new link.

## What you get

- Events from 31 days back to 200 days ahead, in your time zone, fetched at start and every
  15 minutes (**Sync now** in Settings, or `qs -c sekaipop ipc call calendarcard sync`).
- Each calendar in its own colour. Opening one shows which calendar it is from; it has no
  Edit / Delete (change it in Google: it shows here at the next sync).
- Repeating events are expanded (daily, weekly on given days, "2nd Tuesday", "last Friday",
  yearly, with exceptions and moved instances).
- Read-only: nothing is ever written back to Google.

## Where things are

| What | Where |
|---|---|
| The links (yours only, mode 600) | `~/.config/sekaipop/calendars.json` |
| The last fetch (shown at start) | `~/.cache/sekaipop/calendar/events.json` |
| The fetcher | `sekaipop/scripts/calendar/ics-sync.py` (Python stdlib only) |

The links are never in `settings.json`, a desktop preset, a log or an error message, and the
shell hands a new one to the fetcher on stdin, so it never shows in the process list.
