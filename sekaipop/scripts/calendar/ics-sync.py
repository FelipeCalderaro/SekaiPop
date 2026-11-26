#!/usr/bin/env python3
"""Calendars you subscribe to (Google Calendar's "secret address in iCal format", or any
.ics link) for the desktop calendar card (CalendarCardService.qml). Read-only: nothing is
ever sent back. No API key, no OAuth client: the link itself is the key.

    ics-sync.py list               the calendars, as JSON (names, colours, never the links)
    ics-sync.py add <name> [color] read ONE link from stdin (not argv: it would show in `ps`)
    ics-sync.py remove <index>     forget one calendar
    ics-sync.py fetch              download them all, print {"events": [...], "errors": [...]}
                                   and keep it as the cache
    ics-sync.py cached             print the last fetch (what the card shows at startup)

Where: the links in ${XDG_CONFIG_HOME:-~/.config}/sekaipop/calendars.json, the events in
${XDG_CACHE_HOME:-~/.cache}/sekaipop/calendar/events.json, both readable by you only.
A link is a password to that calendar: it is never printed, logged or put in an error.

Events come out as the card's own shape (EventMath.js clean()): title, date YYYY-MM-DD,
time HH:MM ("" = all day), note, color 0..4, plus `src` (the calendar's name). Only
the window from WINDOW_PAST days ago to WINDOW_AHEAD days ahead is kept. Repeating
events are expanded here: FREQ DAILY / WEEKLY / MONTHLY / YEARLY with INTERVAL, COUNT,
UNTIL, BYDAY (also "2TU", "-1FR"), BYMONTHDAY and BYMONTH, minus EXDATE, with moved or
cancelled single instances (RECURRENCE-ID) honoured. A rule beyond that shows its first
occurrence only.
"""

import datetime as dt
import json
import os
import re
import sys
import tempfile
import urllib.error
import urllib.request
from zoneinfo import ZoneInfo

WINDOW_PAST = 31
WINDOW_AHEAD = 200
MAX_EVENTS = 3000
MAX_CALENDARS = 12
MAX_BYTES = 20 * 1024 * 1024
TIMEOUT = 25

CFG = os.path.join(os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config"), "sekaipop")
CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache"), "sekaipop", "calendar")
LIST_FILE = os.path.join(CFG, "calendars.json")
CACHE_FILE = os.path.join(CACHE, "events.json")


# ===== files (private: 0600) =====
def write_private(path, data):
    os.makedirs(os.path.dirname(path), mode=0o700, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".tmp-")
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            json.dump(data, fh, ensure_ascii=False)
        os.replace(tmp, path)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def load_list():
    try:
        with open(LIST_FILE, encoding="utf-8") as fh:
            data = json.load(fh)
    except (OSError, ValueError):
        return []
    out = []
    for c in data if isinstance(data, list) else []:
        if isinstance(c, dict) and isinstance(c.get("url"), str) and isinstance(c.get("name"), str):
            out.append({"name": c["name"][:40], "url": c["url"], "color": clamp_color(c.get("color"))})
    return out[:MAX_CALENDARS]


def clamp_color(c):
    try:
        n = int(c)
    except (TypeError, ValueError):
        return 0
    return n if 0 <= n < 5 else 0


def normalize_url(text):
    u = text.strip()
    if u.lower().startswith("webcal://"):
        u = "https://" + u[9:]
    if not re.match(r"^https://[^\s/]+/\S+$", u):
        return ""
    return u


# ===== iCalendar =====
def unfold(text):
    lines = []
    for raw in text.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
        if raw[:1] in (" ", "\t") and lines:
            lines[-1] += raw[1:]
        else:
            lines.append(raw)
    return lines


def parse_line(line):
    # NAME;PARAM=VALUE;PARAM="V":value   (a ":" inside a quoted parameter is not the split)
    i, quoted = 0, False
    while i < len(line):
        ch = line[i]
        if ch == '"':
            quoted = not quoted
        elif ch == ":" and not quoted:
            break
        i += 1
    head, value = line[:i], line[i + 1:]
    parts = head.split(";")
    params = {}
    for p in parts[1:]:
        if "=" in p:
            k, v = p.split("=", 1)
            params[k.upper()] = v.strip('"')
    return parts[0].upper(), params, value


def unescape(v):
    return re.sub(r"\\([\\;,nN])", lambda m: "\n" if m.group(1) in "nN" else m.group(1), v)


LOCAL = dt.datetime.now().astimezone().tzinfo


def zone(tzid):
    if not tzid:
        return None
    try:
        return ZoneInfo(tzid)
    except Exception:
        return None


def parse_when(value, params):
    """(datetime in local time, all_day) or None."""
    v = value.strip()
    if params.get("VALUE") == "DATE" or re.fullmatch(r"\d{8}", v):
        try:
            d = dt.datetime.strptime(v[:8], "%Y%m%d")
        except ValueError:
            return None
        return d, True
    m = re.fullmatch(r"(\d{8}T\d{6})(Z?)", v)
    if not m:
        return None
    try:
        naive = dt.datetime.strptime(m.group(1), "%Y%m%dT%H%M%S")
    except ValueError:
        return None
    if m.group(2) == "Z":
        aware = naive.replace(tzinfo=dt.timezone.utc)
    else:
        tz = zone(params.get("TZID"))
        aware = naive.replace(tzinfo=tz) if tz else naive.replace(tzinfo=LOCAL)
    return aware.astimezone(LOCAL).replace(tzinfo=None), False


def parse_events(text):
    events, cur, depth = [], None, 0
    for line in unfold(text):
        if not line:
            continue
        name, params, value = parse_line(line)
        if name == "BEGIN":
            depth += 1
            if value.upper() == "VEVENT":
                cur = {"exdate": [], "params": {}}
            continue
        if name == "END":
            depth -= 1
            if value.upper() == "VEVENT" and cur is not None:
                events.append(cur)
                cur = None
            continue
        if cur is None:
            continue
        if name in ("DTSTART", "DTEND", "RECURRENCE-ID"):
            w = parse_when(value, params)
            if w:
                cur[name] = w
        elif name == "EXDATE":
            for part in value.split(","):
                w = parse_when(part, params)
                if w:
                    cur["exdate"].append(w[0])
        elif name in ("SUMMARY", "LOCATION", "UID", "RRULE", "STATUS"):
            cur[name] = unescape(value) if name in ("SUMMARY", "LOCATION") else value.strip()
    return events


# ===== repeating events =====
WEEKDAYS = {"MO": 0, "TU": 1, "WE": 2, "TH": 3, "FR": 4, "SA": 5, "SU": 6}


def nth_weekdays(year, month, spec):
    """Days of `month` matching a BYDAY entry: "TU" (every Tuesday), "2TU", "-1FR"."""
    m = re.fullmatch(r"([+-]?\d+)?(MO|TU|WE|TH|FR|SA|SU)", spec)
    if not m:
        return []
    wd = WEEKDAYS[m.group(2)]
    first = dt.date(year, month, 1)
    nxt = dt.date(year + (month == 12), month % 12 + 1, 1)
    days = [first + dt.timedelta(days=i) for i in range((nxt - first).days)]
    hits = [d for d in days if d.weekday() == wd]
    if m.group(1) is None:
        return hits
    n = int(m.group(1))
    if n > 0 and n <= len(hits):
        return [hits[n - 1]]
    if n < 0 and -n <= len(hits):
        return [hits[n]]
    return []


def add_months(d, n):
    y, m = divmod(d.month - 1 + n, 12)
    return d.year + y, m + 1


def expand(start, rule, until_window):
    """Start datetimes of a repeating event, from `start` up to `until_window` (inclusive).
    None when the rule asks for something this does not do (the caller keeps the first one)."""
    r = {}
    for part in rule.split(";"):
        if "=" in part:
            k, v = part.split("=", 1)
            r[k.upper()] = v
    known = {"FREQ", "INTERVAL", "COUNT", "UNTIL", "BYDAY", "BYMONTHDAY", "BYMONTH", "WKST"}
    if set(r) - known:
        return None
    freq = r.get("FREQ")
    try:
        interval = max(1, int(r.get("INTERVAL", "1")))
        count = int(r["COUNT"]) if "COUNT" in r else None
    except ValueError:
        return None
    until = until_window
    if "UNTIL" in r:
        w = parse_when(r["UNTIL"], {})
        if w:
            until = min(until, w[0] if not w[1] else w[0].replace(hour=23, minute=59, second=59))
    byday = [s for s in r.get("BYDAY", "").split(",") if s]
    try:
        bymonthday = [int(s) for s in r.get("BYMONTHDAY", "").split(",") if s]
        bymonth = [int(s) for s in r.get("BYMONTH", "").split(",") if s]
    except ValueError:
        return None
    t = start.time()
    out = []

    def push(d):
        when = dt.datetime.combine(d, t)
        if when < start or when > until:
            return when > until
        out.append(when)
        return count is not None and len(out) >= count

    if freq == "DAILY":
        d = start.date()
        while True:
            if (not byday or any(d.weekday() == WEEKDAYS.get(s[-2:]) for s in byday)) and \
               (not bymonth or d.month in bymonth):
                if push(d):
                    break
            d += dt.timedelta(days=interval)
            if dt.datetime.combine(d, t) > until:
                break
    elif freq == "WEEKLY":
        days = sorted(WEEKDAYS[s[-2:]] for s in byday if s[-2:] in WEEKDAYS) or [start.weekday()]
        week = start.date() - dt.timedelta(days=start.weekday())
        done = False
        while not done:
            for wd in days:
                d = week + dt.timedelta(days=wd)
                if push(d):
                    done = True
                    break
            week += dt.timedelta(weeks=interval)
            if dt.datetime.combine(week, t) > until:
                break
    elif freq in ("MONTHLY", "YEARLY"):
        months = bymonth or ([start.month] if freq == "YEARLY" else None)
        base = start.date().replace(day=1)
        k = 0
        while True:
            y, m = add_months(base, k)
            if dt.datetime(y, m, 1) > until:
                break
            if freq == "MONTHLY":
                take = k % interval == 0 and (months is None or m in months)
            else:
                take = (k // 12) % interval == 0 and m in months
            if take:
                last = (dt.date(y + (m == 12), m % 12 + 1, 1) - dt.timedelta(days=1)).day
                cands = []
                for spec in byday:
                    cands += nth_weekdays(y, m, spec)
                for md in bymonthday:
                    day = md if md > 0 else last + 1 + md
                    if 1 <= day <= last:
                        cands.append(dt.date(y, m, day))
                if not byday and not bymonthday and start.day <= last:
                    cands.append(dt.date(y, m, start.day))
                if any(push(d) for d in sorted(set(cands))):
                    break
            k += 1
    else:
        return None
    return out


# ===== one calendar =====
def events_of(text, color, src, lo, hi):
    raw = parse_events(text)
    moved = {}
    for e in raw:
        if "RECURRENCE-ID" in e and e.get("UID"):
            moved.setdefault(e["UID"], set()).add(e["RECURRENCE-ID"][0])
    out = []
    for e in raw:
        if "DTSTART" not in e or e.get("STATUS", "").upper() == "CANCELLED":
            continue
        start, all_day = e["DTSTART"]
        starts = [start]
        if e.get("RRULE") and "RECURRENCE-ID" not in e:
            got = expand(start, e["RRULE"], hi)
            if got is not None:
                skip = set(e["exdate"]) | moved.get(e.get("UID", ""), set())
                starts = [s for s in got if s not in skip]
        title = (e.get("SUMMARY") or "(no title)").replace("\n", " ").strip()
        note = (e.get("LOCATION") or "").replace("\n", " ").strip()
        for s in starts:
            if s < lo or s > hi:
                continue
            out.append({
                "title": title[:80],
                "date": s.strftime("%Y-%m-%d"),
                "time": "" if all_day else s.strftime("%H:%M"),
                "note": note[:240],
                "color": color,
                "src": src,
            })
    return out


def download(url):
    req = urllib.request.Request(url, headers={"User-Agent": "sekaipop-calendar/1.0", "Accept": "text/calendar"})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
        data = resp.read(MAX_BYTES + 1)
    if len(data) > MAX_BYTES:
        raise ValueError("the calendar is too big")
    text = data.decode("utf-8", errors="replace")
    if "BEGIN:VCALENDAR" not in text[:4096].upper():
        raise ValueError("that link is not a calendar (.ics)")
    return text


def why(exc):
    # Never the URL: urllib errors can carry it.
    if isinstance(exc, urllib.error.HTTPError):
        return {401: "the link was refused (reset in Google?)", 403: "the link was refused (reset in Google?)",
                404: "the link no longer works (reset in Google?)"}.get(exc.code, "the server answered %d" % exc.code)
    if isinstance(exc, urllib.error.URLError):
        return "couldn't reach the server"
    if isinstance(exc, ValueError):
        return str(exc)
    if isinstance(exc, TimeoutError):
        return "it took too long"
    return "couldn't read it"


def fetch():
    now = dt.datetime.now()
    lo = (now - dt.timedelta(days=WINDOW_PAST)).replace(hour=0, minute=0, second=0, microsecond=0)
    hi = (now + dt.timedelta(days=WINDOW_AHEAD)).replace(hour=23, minute=59, second=59, microsecond=0)
    events, errors = [], []
    for c in load_list():
        try:
            events += events_of(download(c["url"]), c["color"], c["name"], lo, hi)
        except Exception as exc:
            errors.append({"name": c["name"], "error": why(exc)})
    events.sort(key=lambda e: (e["date"], e["time"] != "", e["time"], e["title"].lower()))
    result = {"at": now.strftime("%Y-%m-%d %H:%M"), "events": events[:MAX_EVENTS], "errors": errors}
    write_private(CACHE_FILE, result)
    return result


def main(argv):
    cmd = argv[1] if len(argv) > 1 else ""
    if cmd == "list":
        print(json.dumps([{"name": c["name"], "color": c["color"],
                           "host": re.sub(r"^https://([^/]+)/.*$", r"\1", c["url"])} for c in load_list()]))
    elif cmd == "add":
        name = (argv[2] if len(argv) > 2 else "").strip()[:40] or "Calendar"
        url = normalize_url(sys.stdin.readline())
        if not url:
            print("not a link: paste the https:// (or webcal://) address", file=sys.stderr)
            return 2
        cals = load_list()
        if len(cals) >= MAX_CALENDARS:
            print("that's the most calendars it keeps (%d)" % MAX_CALENDARS, file=sys.stderr)
            return 2
        if any(c["url"] == url for c in cals):
            print("that calendar is already added", file=sys.stderr)
            return 2
        color = clamp_color(argv[3]) if len(argv) > 3 else len(cals) % 5
        cals.append({"name": name, "url": url, "color": color})
        write_private(LIST_FILE, cals)
    elif cmd == "remove":
        cals = load_list()
        try:
            i = int(argv[2])
        except (IndexError, ValueError):
            return 2
        if 0 <= i < len(cals):
            del cals[i]
            write_private(LIST_FILE, cals)
    elif cmd == "fetch":
        print(json.dumps(fetch(), ensure_ascii=False))
    elif cmd == "cached":
        try:
            with open(CACHE_FILE, encoding="utf-8") as fh:
                sys.stdout.write(fh.read())
        except OSError:
            print('{"events": [], "errors": []}')
    else:
        print(__doc__, file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
