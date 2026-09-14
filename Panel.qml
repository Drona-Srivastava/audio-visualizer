import QtQuick
import QtQuick.Controls
import Quickshell
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
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MprisSelect { id: selector }
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

    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    Rectangle {
        id: card
        width: 360
        height: content.implicitHeight + 34
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 48
        radius: 14
        color: root.bg
        border.color: root.pillBorder
        border.width: root.pillBorderW

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: content
            anchors.fill: parent
            anchors.margins: 17
            spacing: 12

            Row {
                width: parent.width
                spacing: 12

                Rectangle {
                    width: 76
                    height: 76
                    radius: 8
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
                        text: ""
                        font.pixelSize: 30
                        font.family: "sans-serif"
                        color: root.seal
                    }
                }

                Column {
                    width: parent.width - 88
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Text {
                        width: parent.width
                        text: root.player ? (root.player.trackTitle || "Unknown title") : "No media playing"
                        color: root.ink
                        font.family: root.mono
                        font.pixelSize: 14
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: root.player ? (root.player.trackArtist || root.player.trackAlbum || "") : ""
                        color: root.sumiHi
                        font.family: root.mono
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        visible: text !== ""
                    }
                    Text {
                        width: parent.width
                        text: root.player ? root.playerName() : ""
                        color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.5)
                        font.family: root.mono
                        font.pixelSize: 10
                        elide: Text.ElideRight
                        visible: text !== ""
                    }
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                Rectangle {
                    width: 42; height: 32; radius: 8
                    color: root.pill
                    Text { anchors.centerIn: parent; text: ""; color: root.ink; font.pixelSize: 18 }
                    MouseArea { anchors.fill: parent; onClicked: if (root.player && root.player.canGoPrevious) root.player.previous() }
                }
                Rectangle {
                    width: 60; height: 32; radius: 8
                    color: root.seal
                    Text { anchors.centerIn: parent; text: root.playing ? "" : ""; color: root.bg; font.pixelSize: 20 }
                    MouseArea { anchors.fill: parent; onClicked: if (root.player && root.player.canTogglePlaying) root.player.togglePlaying() }
                }
                Rectangle {
                    width: 42; height: 32; radius: 8
                    color: root.pill
                    Text { anchors.centerIn: parent; text: ""; color: root.ink; font.pixelSize: 18 }
                    MouseArea { anchors.fill: parent; onClicked: if (root.player && root.player.canGoNext) root.player.next() }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Right-click the bar widget to switch between Cava and title scroll"
                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.55)
                font.family: root.mono
                font.pixelSize: 9
            }
        }
    }
}
