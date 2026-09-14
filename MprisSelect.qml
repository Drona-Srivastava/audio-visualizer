import QtQuick
import Quickshell
import Quickshell.Services.Mpris

QtObject {
    id: selector

    function isProxy(playerObject) {
        var value = (playerObject.dbusName || "") + " " + (playerObject.identity || "")
        return /playerctld/i.test(value)
    }

    function isReal(playerObject) {
        if (!playerObject || isProxy(playerObject)) return false
        if (playerObject.playbackState === MprisPlaybackState.Stopped) return false
        return !!(playerObject.trackTitle || playerObject.trackArtist)
            || playerObject.playbackState === MprisPlaybackState.Playing
    }

    readonly property var player: {
        var values = Mpris.players.values
        var paused = null
        for (var i = 0; i < values.length; i++) {
            var candidate = values[i]
            if (!isReal(candidate)) continue
            if (candidate.playbackState === MprisPlaybackState.Playing) return candidate
            if (candidate.playbackState === MprisPlaybackState.Paused && paused === null)
                paused = candidate
        }
        return paused
    }

    readonly property bool active: player !== null
    readonly property bool playing: active && player.playbackState === MprisPlaybackState.Playing
}
