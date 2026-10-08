import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import org.kde.kirigami 2.20 as Kirigami

Kirigami.FormLayout {
    property alias cfg_FishCount: fishCount.value
    property alias cfg_FishSize: fishSize.value
    property alias cfg_FishSpeed: fishSpeed.value
    property alias cfg_Lights: lights.checked
    property alias cfg_Motes: motes.checked
    property alias cfg_Ripples: ripples.checked
    property alias cfg_Foreground: foreground.checked
    property alias cfg_FilmLook: film.checked
    property alias cfg_Hud: hud.checked
    property alias cfg_Title: title.text
    property alias cfg_Player: player.text
    property alias cfg_TextScale: textScale.value
    property alias cfg_PauseWhenCovered: pauseCovered.checked
    property alias cfg_PauseOnBattery: pauseBattery.checked
    property alias cfg_ActiveScreenOnly: activeScreen.checked

    QQC2.SpinBox { id: fishCount; Kirigami.FormData.label: "Fish:"; from: 1; to: 40 }
    QQC2.SpinBox { id: fishSize; Kirigami.FormData.label: "Fish size (%):"; from: 40; to: 250; stepSize: 10 }
    QQC2.SpinBox { id: fishSpeed; Kirigami.FormData.label: "Swim speed (%):"; from: 20; to: 300; stepSize: 10 }

    QQC2.CheckBox { id: hud; Kirigami.FormData.label: "Loading screen:"; text: "Show menu and readouts" }
    QQC2.TextField { id: title; Kirigami.FormData.label: "Title:"; enabled: hud.checked }
    QQC2.TextField { id: player; Kirigami.FormData.label: "User name:"; enabled: hud.checked }
    QQC2.SpinBox { id: textScale; Kirigami.FormData.label: "Text size (%):"; from: 60; to: 200; stepSize: 10; enabled: hud.checked }

    QQC2.CheckBox { id: film; Kirigami.FormData.label: "Effects:"; text: "Film look (grain, colour fringing)" }
    QQC2.CheckBox { id: foreground; text: "Blurry goldfish close to the glass" }
    QQC2.CheckBox { id: lights; text: "Drifting tank lights" }
    QQC2.CheckBox { id: motes; text: "Glowing particles" }
    QQC2.CheckBox { id: ripples; text: "Ripples" }

    QQC2.CheckBox { id: pauseBattery; Kirigami.FormData.label: "Performance:"; text: "Hold a still frame on battery (otherwise 15 fps; on AC it runs at the screen's refresh rate)" }
    QQC2.CheckBox { id: activeScreen; text: "With several screens, only animate the one in use" }
    QQC2.CheckBox { id: pauseCovered; text: "Pause while a maximized or fullscreen window covers the screen" }
}
