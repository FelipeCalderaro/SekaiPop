import QtQuick
import Quickshell.Wayland
import Quickshell.Services.Mpris

// What the pet reacts to (docs/PLUGINS.md, "A service"): whether music is playing (any MPRIS
// player) and whether you've been idle for `sleepMinutes` (Wayland's idle notification, the one
// hypridle uses; an inhibitor such as Keep Awake or a playing video keeps it awake too).
QtObject {
    id: svc
    required property var host

    readonly property bool playing: {
        const list = Mpris.players.values
        for (let i = 0; i < list.length; i++)
            if (list[i].playbackState === MprisPlaybackState.Playing)
                return true
        return false
    }
    readonly property bool idle: idleMon.isIdle

    property IdleMonitor idleMon: IdleMonitor {
        enabled: svc.host.working
        timeout: Math.max(1, svc.host.settings.sleepMinutes) * 60
        respectInhibitors: true
    }
}
