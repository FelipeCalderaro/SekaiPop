import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "CoverWall.js" as CW

// The cover wall's one watcher (docs/PLUGINS.md, "A service"): which player is playing what, and
// the albums you played lately (with their covers), kept in
// ${XDG_CACHE_HOME:-~/.cache}/sekaipop/cover-wall/history.json so the wall survives a restart.
// It listens to the players' own signals (MPRIS); nothing is polled.
QtObject {
    id: svc
    required property var host

    readonly property int max: 24

    // the player to show: the one playing, else the last one with a title
    readonly property var player: {
        const list = Mpris.players.values
        let paused = null
        for (let i = 0; i < list.length; i++) {
            if (list[i].playbackState === MprisPlaybackState.Playing)
                return list[i]
            if (paused === null && list[i].trackTitle !== "")
                paused = list[i]
        }
        return paused
    }
    readonly property bool playing: svc.player !== null && svc.player.playbackState === MprisPlaybackState.Playing
    readonly property var now: svc.player === null ? null : ({
        title: svc.player.trackTitle || "",
        artist: svc.player.trackArtist || "",
        album: svc.player.trackAlbum || "",
        art: svc.player.trackArtUrl || "",
        player: svc.player.identity || ""
    })
    readonly property string nowKey: svc.now ? CW.albumKey(svc.now) : ""
    readonly property bool canNext: svc.player !== null && svc.player.canGoNext
    readonly property bool canToggle: svc.player !== null && svc.player.canTogglePlaying

    property var history: []

    function togglePlaying() { if (svc.canToggle) svc.player.togglePlaying() }
    function next() { if (svc.canNext) svc.player.next() }

    // a new track with a cover goes on the wall (only while it is actually playing, so scrolling
    // through a paused queue doesn't fill it)
    onNowChanged: rememberSoon.restart()
    onPlayingChanged: rememberSoon.restart()
    property Timer rememberSoon: Timer {
        interval: 1500          // let title, album and art arrive together
        onTriggered: {
            if (!svc.playing || !svc.now)
                return
            const next = CW.remember(svc.history, svc.now, Date.now(), svc.max)
            if (next !== svc.history && (next.length !== svc.history.length || next[0].key !== (svc.history[0] || {}).key)) {
                svc.history = next
                file.setText(JSON.stringify(svc.history))
            }
        }
    }

    readonly property string dir: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/sekaipop/cover-wall"
    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", svc.dir])
    property FileView file: FileView {
        path: svc.dir + "/history.json"
        blockLoading: false
        printErrors: false
        onLoaded: svc.history = CW.load(text(), svc.max)
    }
}
