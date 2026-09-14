import QtQuick
import Quickshell
import Quickshell.Services.Mpris

QtObject {
    id: selector

    property string selectionMode: "latest"
    property var playOrder: ({})
    property var wasPlaying: ({})
    property int playSerial: 0
    property int revision: 0

    function playerKey(playerObject) {
        return String(playerObject.dbusName || playerObject.desktopEntry || playerObject.identity || "")
    }

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

    function syncOrder() {
        var values = Mpris.players.values
        var nextOrder = Object.assign({}, selector.playOrder)
        var nextPlaying = ({})

        for (var i = 0; i < values.length; i++) {
            var candidate = values[i]
            if (!isReal(candidate)) continue

            var key = playerKey(candidate)
            var playingNow = candidate.playbackState === MprisPlaybackState.Playing
            if (playingNow && selector.wasPlaying[key] !== true) {
                selector.playSerial += 1
                nextOrder[key] = selector.playSerial
            } else if (nextOrder[key] === undefined) {
                selector.playSerial += 1
                nextOrder[key] = selector.playSerial
            }
            nextPlaying[key] = playingNow
        }

        selector.playOrder = nextOrder
        selector.wasPlaying = nextPlaying
        selector.revision += 1
    }

    property Timer orderTimer: Timer {
        interval: 400
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: selector.syncOrder()
    }

    readonly property var player: {
        var orderRevision = selector.revision
        var values = Mpris.players.values
        var selected = null
        var paused = null
        var selectedOrder = -1
        var pausedOrder = -1
        for (var i = 0; i < values.length; i++) {
            var candidate = values[i]
            if (!isReal(candidate)) continue

            var order = selector.playOrder[playerKey(candidate)] || 0
            if (candidate.playbackState === MprisPlaybackState.Playing && order > selectedOrder) {
                selected = candidate
                selectedOrder = order
            } else if (candidate.playbackState === MprisPlaybackState.Paused && order > pausedOrder) {
                paused = candidate
                pausedOrder = order
            }
        }
        return selected || paused
    }

    readonly property bool active: player !== null
    readonly property bool playing: active && player.playbackState === MprisPlaybackState.Playing
}
