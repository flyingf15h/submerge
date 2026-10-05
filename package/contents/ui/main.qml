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
        // the part of the screen not taken by panels, so the HUD clears the taskbar
        // (there are no panels on the lock screen, where this isn't available)
        bottomInset: Plasmoid.availableScreenRect ? Math.max(0, root.height - (Plasmoid.availableScreenRect.y + Plasmoid.availableScreenRect.height)) : 0
        pauseWhenCovered: root.configuration.PauseWhenCovered
        slowWhenUnfocused: root.configuration.SlowWhenUnfocused
        lockScreen: root.configuration.LockScreen
        slowOnBattery: root.configuration.SlowOnBattery
        freezeOnBattery: root.configuration.FreezeOnBattery
        lowFps: root.configuration.LowFrameRate
        fps: root.configuration.FrameRate
    }
}
