import QtQuick
import Quickshell
import Quickshell.Io
import "AniList.js" as AL

// The AniList plugin's one connection (docs/PLUGINS.md, "A service"): made once, shared by the
// bar entry on every monitor and by the popup, so they all read one copy of your lists.
//
// Two ways in:
//   - a public username (Settings: username): your CURRENT / REPEATING lists, read-only
//   - signed in (the `token` secret, ~/.config/sekaipop/anilist-token): private lists too,
//     your notification count, and +1 on an entry from the popup
//
// It asks only while something shows it (host.working), every `refreshMinutes`, and again
// when the popup opens on data older than a minute. AniList allows about 30 requests a
// minute; this sends one per refresh.
//
// The token never goes on a command line (other users can read those in /proc): it is
// written to the helper's stdin and handed to curl as a header from there (`-H @-`).
QtObject {
    id: root

    required property var host

    // ===== what the surfaces read =====
    readonly property string token: root.host.secrets && root.host.secrets.token ? String(root.host.secrets.token).trim() : ""
    readonly property bool signedIn: root.token !== ""
    readonly property string username: String(root.host.settings.username || "").trim()
    readonly property bool configured: root.signedIn || root.username !== ""
    readonly property string listType: root.host.settings.listType || "ANIME"

    property var user: null
    property var entries: []
    property int unread: 0
    property bool loading: false
    property string error: ""
    property real updatedAt: 0          // ms, 0 = never
    property real now: Date.now()       // ms, ticks while shown (the countdowns)
    readonly property real nowSec: Math.floor(root.now / 1000)

    // The entry ids a +1 is on its way for (their key shows busy).
    property var bumping: ({})

    // What the bar entry draws (AniList.js barFace).
    readonly property var face: AL.barFace(root.host.settings.barShows, {
        configured: root.configured, signedIn: root.signedIn, loading: root.loading,
        error: root.error, entries: root.entries, unread: root.unread
    }, root.nowSec, root.host.settings.titleLanguage)

    // The signed-in user's id, learnt from the first answer (see AniList.js listQuery).
    property int viewerId: 0

    readonly property bool popupUp: root.host.wanted.indexOf("popup") >= 0

    // ===== asking =====
    function refresh() {
        if (!root.configured || root.loading)
            return
        root.loading = true
        const auth = root.signedIn
        const vars = auth ? { uid: root.viewerId > 0 ? root.viewerId : null } : { name: root.username }
        root.request(AL.body(AL.listQuery(auth, root.listType), vars), out => {
            const res = AL.splitResponse(out)
            const firstSignedIn = auth && root.viewerId === 0
            const err = AL.errorText(res, firstSignedIn)
            root.loading = false
            if (err !== "") {
                root.error = err
                return
            }
            const got = AL.normalize(res.json, root.listType)
            if (auth && got.user && root.viewerId === 0) {
                // The id is known now: the lists come with the next call, made at once.
                root.viewerId = got.user.id
                root.user = got.user
                root.unread = got.unread
                Qt.callLater(root.refresh)
                return
            }
            root.error = ""
            root.user = got.user
            root.unread = got.unread
            root.entries = got.entries
            root.updatedAt = Date.now()
            root.now = Date.now()
        })
    }

    // +1 episode / chapter on a list entry (signed in only). The entry moves on at once and is
    // put back if AniList says no.
    function bump(entry) {
        if (!root.signedIn || !entry || root.bumping[entry.id])
            return
        const ask = AL.bump(entry)
        const before = root.entries
        root.entries = before.map(e => e.id === entry.id ? Object.assign({}, e, { progress: ask.progress }) : e)
        root.setBumping(entry.id, true)
        root.request(AL.body(AL.PROGRESS_MUTATION, ask), out => {
            root.setBumping(entry.id, false)
            const res = AL.splitResponse(out)
            const err = AL.errorText(res, false)
            if (err !== "") {
                root.entries = before
                root.error = err
                return
            }
            // A finished entry leaves the CURRENT list: ask again rather than guess.
            if (ask.status === "COMPLETED")
                Qt.callLater(root.refresh)
        })
    }

    function setBumping(id, on) {
        const b = Object.assign({}, root.bumping)
        if (on)
            b[id] = true
        else
            delete b[id]
        root.bumping = b
    }

    // ===== account and settings, from the popup =====
    // Everything the popup's Account and Settings pages change goes through here, so the popup
    // needs no file and no trip to Settings. (Settings > Desktop > Plugins shows the same values.)
    function setSetting(key, value) {
        return root.host.setSetting(key, value)
    }

    // A public profile: read-only, needs no sign-in. Returns false for a name AniList can't have.
    function useUsername(text) {
        const u = AL.cleanUsername(text)
        if (u === "" && String(text || "").trim() !== "")
            return false
        root.host.setSetting("username", u)
        return true
    }

    function useClientId(text) {
        const id = AL.cleanClientId(text)
        if (id === "" && String(text || "").trim() !== "")
            return false
        root.host.setSetting("clientId", id)
        return true
    }

    readonly property int callbackPort: AL.portOf(root.host.settings.callbackPort)
    readonly property string redirectUrl: AL.redirectUrl(root.callbackPort)

    // Puts text on the clipboard (the redirect URL, for the API client form).
    function copy(text) {
        root.run(["wl-copy", "--", String(text)], "", () => root.signInNote = "Copied: " + text)
    }

    // ===== signing in =====
    // The token file the manifest names (`secrets.token.file`). The plugin writes it itself.
    readonly property string tokenFile: Quickshell.env("HOME") + "/.config/sekaipop/anilist-token"
    property string signInNote: ""
    // "" | "waiting" (the browser is out, auth-callback.py is listening) | "saving"
    property string authState: ""

    // Sign in with AniList, all the way: auth-callback.py listens on localhost, the browser opens
    // AniList's consent page, AniList sends it back to http://localhost:<port>/callback with the
    // token, the page hands the token to the helper, and it lands here (onAuthLine). Needs an API
    // client whose redirect URL is `redirectUrl`; its ID is the clientId setting.
    function startSignIn() {
        const url = AL.authorizeUrl(root.host.settings.clientId)
        if (url === "") {
            root.signInNote = "Enter your API client's ID first (step 2)"
            return false
        }
        if (authServer.running)
            authServer.running = false
        root.authUrl = url
        root.authState = "waiting"
        root.signInNote = "Starting…"
        authServer.command = ["python3", root.host.path("auth-callback.py"), String(root.callbackPort), "300"]
        authServer.running = true
        authWatch.restart()
        return true
    }

    function cancelSignIn() {
        authServer.running = false
        root.authState = ""
        root.signInNote = ""
    }

    property string authUrl: ""
    property bool authGotToken: false

    function onAuthLine(line) {
        const a = AL.authLine(line)
        if (a.kind === "ready") {
            authWatch.stop()
            Qt.openUrlExternally(root.authUrl)
            root.signInNote = "Approve SekaiPop in your browser…"
        } else if (a.kind === "token") {
            root.authGotToken = true
            root.saveToken(a.value)
        } else if (a.kind === "error") {
            root.authState = ""
            root.signInNote = "Couldn't listen for AniList (" + a.value + ") · change the callback port in Settings"
        } else if (a.kind === "timeout") {
            root.authState = ""
            root.signInNote = "Sign in timed out · try again"
        }
    }

    property Process authServer: Process {
        stdout: SplitParser { onRead: line => root.onAuthLine(line) }
        onStarted: root.authGotToken = false
        onExited: (code, status) => {
            if (root.authState === "waiting" && !root.authGotToken && root.signInNote === "Approve SekaiPop in your browser…") {
                root.authState = ""
                root.signInNote = "Sign in stopped · try again"
            }
        }
    }

    // The helper says "ready" within a moment; silence means it could not start (no python3).
    property Timer authWatch: Timer {
        interval: 3000
        onTriggered: {
            if (root.authState === "waiting" && root.signInNote === "Starting…") {
                authServer.running = false
                root.authState = ""
                root.signInNote = "Signing in needs python3 · or copy a token from AniList and press Paste token"
            }
        }
    }

    // Keeps a token in the token file (mode 600, written whole then moved into place) and has the
    // shell read the plugin's secrets again. It reaches the helper through stdin, never argv.
    function saveToken(raw) {
        const tok = AL.cleanToken(raw)
        if (tok === "") {
            root.authState = ""
            root.signInNote = "That isn't an AniList token · copy the whole thing and try again"
            return
        }
        root.authState = "saving"
        root.signInNote = "Saving…"
        root.run(["sh", "-c", 'IFS= read -r tok; umask 077; mkdir -p "$(dirname "$1")" && printf "%s\\n" "$tok" > "$1.tmp" && mv "$1.tmp" "$1"',
                  "sh", root.tokenFile], tok + "\n", () => {
            root.authState = ""
            root.signInNote = "Signed in"
            root.viewerId = 0
            root.host.reloadSecrets()
        })
    }

    // The other way in: a token copied from AniList's pin page (a client whose redirect URL is
    // AL.PIN_URL), taken from the clipboard.
    function pasteToken() {
        root.signInNote = "Reading the clipboard…"
        root.run(["wl-paste", "-n"], "", out => root.saveToken(out))
    }

    function signOut() {
        root.run(["rm", "-f", root.tokenFile], "", () => {
            root.viewerId = 0
            root.user = null
            root.entries = []
            root.unread = 0
            root.signInNote = "Signed out"
            root.host.reloadSecrets()
        })
    }

    // ===== processes =====
    // One short-lived Process per call (so two never share a collector), destroyed when done.
    // `input` goes to its stdin as the process starts.
    property Component runner: Component {
        Process {
            id: proc
            property var done: null
            property string input: ""
            property bool finished: false
            stdinEnabled: true
            // (Every helper reads one line, so nothing waits for the end of stdin.)
            onStarted: proc.write(proc.input)
            stdout: StdioCollector {
                onStreamFinished: {
                    if (proc.finished)
                        return
                    proc.finished = true
                    if (proc.done)
                        proc.done(text)
                    Qt.callLater(() => proc.destroy())
                }
            }
            onExited: (code, status) => {
                // No output at all (the program is missing): still answer, once.
                if (!proc.finished) {
                    proc.finished = true
                    if (proc.done)
                        proc.done("")
                    Qt.callLater(() => proc.destroy())
                }
            }
        }
    }

    function run(command, input, done) {
        const p = root.runner.createObject(root, { command: command, input: input, done: done })
        p.running = true
    }

    // One GraphQL call; `done(curl's output, ending in "\n<http code>")`.
    function request(bodyJson, done) {
        const script = 'IFS= read -r tok\n'
            + 'set -- -sS --max-time 20 -X POST "$1" -H "Content-Type: application/json" -H "Accept: application/json"'
            + ' --data-binary "$2" -w "\\n%{http_code}"\n'
            + 'if [ -n "$tok" ]; then printf "Authorization: Bearer %s\\n" "$tok" | curl "$@" -H @-; else curl "$@"; fi'
        root.run(["sh", "-c", script, "sh", AL.ENDPOINT, bodyJson], root.token + "\n", done)
    }

    // ===== when =====
    property Timer poll: Timer {
        running: root.host.working && root.configured
        repeat: true
        triggeredOnStart: true
        interval: Math.max(5, Number(root.host.settings.refreshMinutes) || 15) * 60000
        onTriggered: root.refresh()
    }

    // The countdowns move while something shows them.
    property Timer tick: Timer {
        running: root.host.working
        repeat: true
        interval: 30000
        onTriggered: root.now = Date.now()
    }

    // The popup opening on old data asks again (and puts the countdowns right at once).
    onPopupUpChanged: {
        root.now = Date.now()
        if (root.popupUp && Date.now() - root.updatedAt > 60000)
            root.refresh()
    }

    // A different account or list: start over.
    function restart() {
        root.viewerId = 0
        root.user = null
        root.entries = []
        root.unread = 0
        root.error = ""
        root.updatedAt = 0
        if (root.host.working)
            Qt.callLater(root.refresh)
    }
    onTokenChanged: root.restart()
    onUsernameChanged: root.restart()
    onListTypeChanged: root.restart()
}
