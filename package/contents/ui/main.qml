import QtQuick 2.15
import org.kde.plasma.core 2.0 as PlasmaCore

Item {
    id: root

    Pond {
        anchors.fill: parent
        fishCount: wallpaper.configuration.FishCount
        fishSize: wallpaper.configuration.FishSize / 100
        fishSpeed: wallpaper.configuration.FishSpeed / 100
        lights: wallpaper.configuration.Lights
        motes: wallpaper.configuration.Motes
        ripples: wallpaper.configuration.Ripples
        foreground: wallpaper.configuration.Foreground
        filmLook: wallpaper.configuration.FilmLook
        hud: wallpaper.configuration.Hud
        title: wallpaper.configuration.Title
        player: wallpaper.configuration.Player
        textScale: wallpaper.configuration.TextScale / 100
        running: root.visible
    }
}
