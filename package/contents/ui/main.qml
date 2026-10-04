import QtQuick
import org.kde.plasma.plasmoid

WallpaperItem {
    id: root

    Pond {
        anchors.fill: parent
        fishCount: root.configuration.FishCount
        fishSize: root.configuration.FishSize / 100
        fishSpeed: root.configuration.FishSpeed / 100
        lights: root.configuration.Lights
        motes: root.configuration.Motes
        ripples: root.configuration.Ripples
        foreground: root.configuration.Foreground
        filmLook: root.configuration.FilmLook
        hud: root.configuration.Hud
        title: root.configuration.Title
        player: root.configuration.Player
        textScale: root.configuration.TextScale / 100
        running: root.visible
    }
}
