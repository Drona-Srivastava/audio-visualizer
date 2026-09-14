# Omarchy Audio Visualizer

An Omarchy bar plugin that combines Cava spectrum bars, scrolling MPRIS media
titles, album art, and playback controls.

## Install

```bash
omarchy plugin add https://github.com/Drona-Srivastava/audio-visualizer --enable
```

After enabling, place the widget wherever you want with the normal Omarchy bar
controls.

## Controls

- Left-click: open the playback popup.
- Right-click: cycle between Cava and title-scroll modes.
- Popup controls: previous, play/pause, next.

The plugin follows Omarchy's active MPRIS player, so it can work with Chrome or
YouTube, MPV, VLC, Cliamp, and other compatible players. It displays the
available title, artist, album art, and player identity. If a browser does not
publish an exact site name through MPRIS, its browser/player identity is used
as the fallback.

Cava mode reads the default audio sink monitor. If Cava is unavailable or
cannot start, the widget falls back to title-scroll mode.

## Validate locally

```bash
omarchy plugin validate .
qmllint -I /usr/share/omarchy/shell BarWidget.qml Panel.qml
```
