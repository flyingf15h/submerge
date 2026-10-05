import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

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
    property alias cfg_SlowWhenUnfocused: slowUnfocused.checked
    property alias cfg_SlowOnBattery: slowBattery.checked
    property alias cfg_FreezeOnBattery: freezeBattery.checked
    property alias cfg_LowFrameRate: lowFrameRate.value
    property alias cfg_FrameRate: frameRate.value

    QQC2.SpinBox { id: fishCount; Kirigami.FormData.label: "Fish:"; from: 1; to: 40 }
    QQC2.SpinBox { id: fishSize; Kirigami.FormData.label: "Fish size (%):"; from: 40; to: 250; stepSize: 10 }
    QQC2.SpinBox { id: fishSpeed; Kirigami.FormData.label: "Swim speed (%):"; from: 20; to: 300; stepSize: 10 }

    QQC2.CheckBox { id: hud; Kirigami.FormData.label: "Loading screen:"; text: "Show menu and readouts" }
    QQC2.TextField { id: title; Kirigami.FormData.label: "Title:"; enabled: hud.checked }
    QQC2.TextField { id: player; Kirigami.FormData.label: "User name:"; enabled: hud.checked }
    QQC2.SpinBox { id: textScale; Kirigami.FormData.label: "Text size (%):"; from: 60; to: 200; stepSize: 10; enabled: hud.checked }

    QQC2.CheckBox { id: pauseCovered; Kirigami.FormData.label: "Performance:"; text: "Pause when a maximized window covers the desktop" }
    QQC2.CheckBox { id: slowUnfocused; text: "Lower frame rate while you're using a window" }
    QQC2.CheckBox { id: slowBattery; text: "Lower frame rate on battery" }
    QQC2.CheckBox { id: freezeBattery; text: "Hold a still frame while on battery (uses no extra power)" }
    QQC2.SpinBox { id: frameRate; Kirigami.FormData.label: "Frame rate (fps):"; from: 5; to: 60; stepSize: 5 }
    QQC2.SpinBox { id: lowFrameRate; Kirigami.FormData.label: "Lower frame rate (fps):"; from: 2; to: 30; stepSize: 2 }
    QQC2.CheckBox { id: film; Kirigami.FormData.label: "Effects:"; text: "Film look (grain, colour fringing)" }
    QQC2.CheckBox { id: foreground; text: "Blurry goldfish close to the glass" }
    QQC2.CheckBox { id: lights; text: "Drifting tank lights" }
    QQC2.CheckBox { id: motes; text: "Glowing particles" }
    QQC2.CheckBox { id: ripples; text: "Ripples" }
}
