import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.Commons
import qs.Ui

BarWidget {
    id: root

    moduleName: "audio-visualizer"

    property string mode: {
        var configured = String(setting("mode", "cava")).toLowerCase()
        return configured === "title" ? "title" : "cava"
    }
    property bool cavaAvailable: true
    property var levels: []
    property int bands: 16
    property string marqueeText: ""
    property string mediaText: ""
    property string sourceText: ""
    property int widgetWidth: 144
    readonly property string effectiveMode: mode === "cava" && cavaAvailable ? "cava" : "title"
    readonly property color ink: Color.foreground
    readonly property color seal: Color.accent
    readonly property color pill: Qt.rgba(ink.r, ink.g, ink.b, 0.08)
    readonly property color pillBorder: Qt.rgba(ink.r, ink.g, ink.b, 0.18)
    readonly property int pillBorderW: 1
    readonly property int pillRadius: 8
    readonly property string mono: "monospace"

    MprisSelect {
        id: selector
        selectionMode: String(setting("sourceSelection", "latest"))
    }
    readonly property var player: selector.player
    readonly property bool active: selector.active
    readonly property bool playing: selector.playing

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

    function currentPlayer() {
        return selector.player
    }

    function sourceName(playerObject) {
        if (!playerObject) return ""
        var value = playerObject.identity || playerObject.desktopEntry || playerObject.dbusName || ""
        return String(value).replace(/^org\.mpris\.MediaPlayer2\./, "")
    }

    function clean(value) {
        return String(value || "").replace(/[\r\n\t]+/g, " ").trim()
    }

    function updateMediaText() {
        var current = currentPlayer()
        var title = current ? clean(current.trackTitle) : ""
        var artist = current ? clean(current.trackArtist) : ""
        root.sourceText = sourceName(current)
        root.mediaText = title || root.sourceText || "No media playing"
        root.marqueeText = title ? (artist ? title + " · " + artist : title) : root.mediaText
    }

    function resetLevels() {
        var values = []
        for (var i = 0; i < root.bands; i++) values.push(0.08)
        root.levels = values
    }

    function cycleMode() {
        root.mode = root.mode === "cava" ? "title" : "cava"
        root.cavaAvailable = true
        if (root.mode === "cava" && root.playing) cavaProcess.running = true
    }

    function openPopup() {
        if (root.bar) root.bar.run("omarchy-shell shell toggle audio-visualizer")
    }

    // Reserve one stable slot so mode changes and the play button never push
    // into the neighboring bar widget.
    implicitWidth: root.widgetWidth
    implicitHeight: Style.bar.sizeHorizontal

    Component.onCompleted: root.resetLevels()
    onPlayerChanged: root.updateMediaText()
    onModeChanged: root.updateMediaText()
    onPlayingChanged: {
        root.updateMediaText()
        if (root.mode === "cava") cavaProcess.running = root.playing
    }

    Timer {
        interval: 500
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.updateMediaText()
    }

    Process {
        id: cavaProcess
        running: root.mode === "cava" && root.playing && root.cavaAvailable
        command: ["bash", "-c",
            "sink=$(pactl get-default-sink 2>/dev/null); " +
            "src=auto; [ -n \"$sink\" ] && src=\"${sink}.monitor\"; " +
            "cfg=$(mktemp); " +
            "printf '%s\\n' " +
            "'[general]' 'bars = 16' 'framerate = 30' " +
            "'[input]' 'method = pulse' \"source = $src\" " +
            "'[output]' 'method = raw' 'raw_target = /dev/stdout' " +
            "'data_format = ascii' 'ascii_max_range = 100' > \"$cfg\"; " +
            "trap 'rm -f \"$cfg\"' EXIT; " +
            "command -v cava >/dev/null 2>&1 || exit 127; exec cava -p \"$cfg\""
        ]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) {
                var parts = String(line).split(";")
                var next = []
                for (var i = 0; i < root.bands; i++) {
                    var value = parseInt(parts[i])
                    value = isNaN(value) ? 0 : Math.max(0, Math.min(100, value)) / 100
                    var previous = root.levels[i] === undefined ? 0.08 : root.levels[i]
                    next.push(previous * 0.35 + value * 0.65)
                }
                root.levels = next
            }
        }
        onExited: function(code) {
            if (root.mode === "cava" && root.playing && code !== 0) {
                root.cavaAvailable = false
                root.resetLevels()
            }
        }
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: Style.space(6)

        Item {
            id: displayArea
            width: root.widgetWidth - Style.bar.iconSlot - Style.space(6)
            height: Style.bar.sizeHorizontal
            anchors.verticalCenter: parent.verticalCenter
            clip: true

        Rectangle {
            id: spectrum
            width: parent.width
            height: 19
            anchors.centerIn: parent
            color: "transparent"
            clip: true
            visible: root.effectiveMode === "cava"

            Row {
                anchors.fill: parent
                spacing: 2
                Repeater {
                    model: root.bands
                    Rectangle {
                        width: 2
                        height: Math.max(2, (root.levels[index] || 0.08) * 18)
                        anchors.bottom: parent.bottom
                        radius: 1.5
                        color: root.cavaAvailable ? root.seal : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.35)
                    }
                }
            }
        }

        Item {
            id: titleClip
            anchors.fill: parent
            visible: root.effectiveMode === "title"
            clip: true

            Text {
                id: titleText
                text: root.marqueeText
                color: root.ink
                font.family: root.mono
                font.pixelSize: 11
                anchors.verticalCenter: parent.verticalCenter
                x: titleClip.width >= implicitWidth ? (titleClip.width - implicitWidth) / 2 : -scrollDistance
                width: implicitWidth

                property real scrollDistance: Math.max(0, implicitWidth - titleClip.width)
                SequentialAnimation on x {
                    running: titleClip.visible && titleText.scrollDistance > 0
                    loops: Animation.Infinite
                    PauseAnimation { duration: 1100 }
                    NumberAnimation { to: -titleText.scrollDistance; duration: Math.max(1800, titleText.scrollDistance * 35); easing.type: Easing.Linear }
                    PauseAnimation { duration: 500 }
                    PropertyAction { property: "x"; value: titleClip.width }
                }
            }
        }

        Text {
            id: idleIcon
            anchors.centerIn: parent
            visible: !root.active
            text: "♫"
            font.pixelSize: Style.font.icon
            font.family: Style.font.family
            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.55)
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: function(mouse) {
                if (mouse.button === Qt.RightButton) root.cycleMode()
                else root.openPopup()
            }
        }
        }

    Rectangle {
        id: playButton
        width: Style.bar.iconSlot
        height: Style.bar.iconSlot
        radius: Style.space(6)
        anchors.verticalCenter: parent.verticalCenter
        visible: root.active
        color: playMouse.containsMouse
            ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.18)
            : "transparent"
        border.color: playMouse.containsMouse
            ? root.seal
            : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.18)
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: root.playing ? "Ⅱ" : "▶"
            color: root.seal
            font.family: Style.font.family
            font.pixelSize: Style.font.iconSmall
        }

        MouseArea {
            id: playMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (root.player && root.player.canTogglePlaying) root.player.togglePlaying()
        }
    }

    }
}
