import QtQuick
import Quickshell.Io
import "PingBoard.js" as PB

// The ping board's one poller (docs/PLUGINS.md, "A service"): pings every host at once, every
// `seconds`, only while the widget is on screen; and runs the speed test when asked.
//
// Hosts reach ping as arguments ("$@"), never as text inside the script, and are checked first
// (PingBoard.parseHosts). The speed test is curl against Cloudflare's public speed endpoints:
// 25 MB down, 10 MB up, nothing else sent.
QtObject {
    id: svc
    required property var host

    readonly property var hosts: PB.parseHosts(svc.host.settings.hosts)
    readonly property int keep: 30

    // { address: [ms|null, ...] }
    property var samples: ({})
    property var lastRound: 0
    property bool ever: false

    // speed test: state idle | running | done | error
    property string speedState: "idle"
    property string speedDown: ""
    property string speedUp: ""
    property string speedError: ""
    property var speedAt: 0

    function historyOf(address) {
        return svc.samples[address] || []
    }

    property Timer timer: Timer {
        interval: Math.max(2, svc.host.settings.seconds) * 1000
        repeat: true
        running: svc.host.working && svc.hosts.length > 0
        triggeredOnStart: true
        onTriggered: if (!pinger.running) pinger.running = true
    }

    property Process pinger: Process {
        command: ["sh", "-c",
            'for h in "$@"; do ( r=$(ping -n -c 1 -W 2 -- "$h" 2>/dev/null | sed -n "s/.*time[=<]\\([0-9.]*\\).*/\\1/p" | head -n 1); echo "$h ${r:--}" ) & done; wait',
            "sh"].concat(svc.hosts.map(h => h.address))
        stdout: StdioCollector {
            onStreamFinished: {
                const next = Object.assign({}, svc.samples)
                const seen = {}
                for (const line of text.split("\n")) {
                    const r = PB.parseResult(line)
                    if (!r)
                        continue
                    seen[r.address] = true
                    next[r.address] = PB.push(next[r.address], r.ms, svc.keep)
                }
                // a host whose ping didn't even print (no ping installed) counts as no answer
                for (const h of svc.hosts)
                    if (!seen[h.address])
                        next[h.address] = PB.push(next[h.address], null, svc.keep)
                svc.samples = next
                svc.lastRound = Date.now()
                svc.ever = true
            }
        }
    }

    function runSpeedTest() {
        if (speed.running)
            return
        svc.speedState = "running"
        svc.speedError = ""
        speed.running = true
    }

    property Process speed: Process {
        command: ["sh", "-c",
            'set -e; command -v curl >/dev/null || { echo "error curl is not installed"; exit 0; }; ' +
            'd=$(curl -s -o /dev/null --max-time 30 -w "%{speed_download}" "https://speed.cloudflare.com/__down?bytes=25000000") || { echo "error no connection"; exit 0; }; ' +
            'u=$(head -c 10000000 /dev/zero | curl -s -o /dev/null --max-time 30 -w "%{speed_upload}" --data-binary @- "https://speed.cloudflare.com/__up") || u=0; ' +
            'echo "ok $d $u"']
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(/\s+/)
                if (p[0] === "ok") {
                    svc.speedDown = PB.mbps(p[1])
                    svc.speedUp = parseFloat(p[2]) > 0 ? PB.mbps(p[2]) : ""
                    svc.speedState = "done"
                    svc.speedAt = Date.now()
                } else {
                    svc.speedError = p.slice(1).join(" ") || "the test didn't finish"
                    svc.speedState = "error"
                }
            }
        }
    }
}
