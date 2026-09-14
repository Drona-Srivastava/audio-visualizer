import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Wayland
import qs.Commons
import qs.Ui

PanelWindow {
    id: root

    property var shell: null
    property var manifest: null
    property bool opened: false
    readonly property color bg: Color.popups.background
    readonly property color ink: Color.popups.text
    readonly property color seal: Color.accent
    readonly property color sumiHi: Qt.rgba(ink.r, ink.g, ink.b, 0.58)
    readonly property color pill: Color.menu.selectedBackground
    readonly property color pillBorder: Color.popups.border
    readonly property int pillBorderW: 1
    readonly property string mono: "monospace"

    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    color: "transparent"
    visible: root.opened
    // Keep the overlay shallow so the card sits immediately below the top bar
    // instead of appearing at the bottom of the screen.
    anchors { top: true; left: true; right: true }
    implicitHeight: 330
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MprisSelect {
        id: selector
        selectionMode: "latest"
    }
    readonly property var player: selector.player
    readonly property bool active: selector.active
    readonly property bool playing: selector.playing

    function open(payload) { root.opened = true }
    function close() { root.opened = false }

    function clean(value) {
        return String(value || "").replace(/[\r\n\t]+/g, " ").trim()
    }

    function playerName() {
        if (!root.player) return ""
        return clean(root.player.identity || root.player.desktopEntry || root.player.dbusName || "")
            .replace(/^org\.mpris\.MediaPlayer2\./, "")
    }

    property string pendingTransport: ""

    function sendTransport(command) {
        root.pendingTransport = command
        octaveControl.command = ["python3", "-c",
            "import os,socket,sys; " +
            "p=os.path.join(os.environ.get('XDG_RUNTIME_DIR','/tmp'),'octave-control.sock'); " +
            "s=socket.socket(socket.AF_UNIX,socket.SOCK_STREAM); s.settimeout(0.35); " +
            "s.connect(p); s.sendall((sys.argv[1]+'\\n').encode()); s.recv(16); s.close()",
            command]
        octaveControl.running = true
    }

    function fallbackTransport(command) {
        if (!root.player) return
        if (command === "next") root.player.next()
        else if (command === "previous") root.player.previous()
        else if (command === "pause") root.player.togglePlaying()
    }

    Process {
        id: octaveControl
        running: false
        onExited: function(code) {
            if (code !== 0) root.fallbackTransport(root.pendingTransport)
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    Rectangle {
        id: card
        width: 350
        height: content.implicitHeight + 34
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Style.bar.sizeHorizontal + Style.space(8)
        radius: Math.max(12, Style.cornerRadius)
        color: root.bg
        border.color: root.pillBorder
        border.width: root.pillBorderW

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: content
            anchors.fill: parent
            anchors.margins: Style.space(16)
            spacing: Style.space(12)

            Row {
                width: parent.width
                spacing: Style.space(12)

                Rectangle {
                    width: 72
                    height: 72
                    radius: Math.max(8, Style.cornerRadius)
                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: root.player ? (root.player.trackArtUrl || "") : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: status === Image.Ready
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: !root.player || !parent.children[0].visible
                        text: "♫"
                        font.pixelSize: 30
                        font.family: "sans-serif"
                        color: root.seal
                    }
                }

                Column {
                    width: parent.width - 84
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(4)

                    Text {
                        width: parent.width
                        text: root.player ? (root.player.trackTitle || "Unknown title") : "No media playing"
                        color: root.ink
                        font.family: Style.font.menuFamily
                        font.pixelSize: Style.font.title
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: root.player ? (root.player.trackArtist || root.player.trackAlbum || "") : ""
                        color: root.sumiHi
                        font.family: Style.font.menuFamily
                        font.pixelSize: Style.font.bodySmall
                        elide: Text.ElideRight
                        visible: text !== ""
                    }
                    Text {
                        width: parent.width
                        text: root.player ? root.playerName() : ""
                        color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.5)
                        font.family: Style.font.menuFamily
                        font.pixelSize: Style.font.caption
                        elide: Text.ElideRight
                        visible: text !== ""
                    }
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Style.space(10)

                Rectangle {
                    width: 44; height: 34; radius: Math.max(8, Style.cornerRadius)
                    color: root.pill
                    Text { anchors.centerIn: parent; text: "‹"; color: root.ink; font.pixelSize: 22 }
                    MouseArea { anchors.fill: parent; enabled: root.player !== null; onClicked: root.sendTransport("previous") }
                }
                Rectangle {
                    width: 64; height: 34; radius: Math.max(8, Style.cornerRadius)
                    color: root.seal
                    Text { anchors.centerIn: parent; text: root.playing ? "Ⅱ" : "▶"; color: root.bg; font.family: Style.font.family; font.pixelSize: Style.font.icon }
                    MouseArea { anchors.fill: parent; enabled: root.player !== null; onClicked: root.sendTransport("pause") }
                }
                Rectangle {
                    width: 44; height: 34; radius: Math.max(8, Style.cornerRadius)
                    color: root.pill
                    Text { anchors.centerIn: parent; text: "›"; color: root.ink; font.pixelSize: 22 }
                    MouseArea { anchors.fill: parent; enabled: root.player !== null; onClicked: root.sendTransport("next") }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Right-click the bar widget to switch between Cava and title scroll"
                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.55)
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.caption
            }
        }
    }
}
