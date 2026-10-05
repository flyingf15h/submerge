/*
    Breeze's SDDM background with the Submerge pond drawn over the still image.
    Based on Background.qml from the Breeze SDDM theme (LGPL-2.0-or-later).
*/

import QtQuick 2.15
import "pond/ui"

FocusScope {
    id: sceneBackground

    property var sceneBackgroundType
    property alias sceneBackgroundColor: sceneColorBackground.color
    property alias sceneBackgroundImage: sceneImageBackground.source

    Rectangle {
        id: sceneColorBackground
        anchors.fill: parent
        visible: sceneBackgroundType !== "image"
    }

    // still frame underneath, shown until the pond is ready (and if it fails to load)
    Image {
        id: sceneImageBackground
        anchors.fill: parent
        sourceSize.width: parent.width
        sourceSize.height: parent.height
        fillMode: Image.PreserveAspectCrop
        smooth: true
        visible: sceneBackgroundType === "image"
    }

    // no HUD here: the system readouts need services that only run once you're logged in
    Pond {
        id: pond
        anchors.fill: parent
        hud: false
        maxFps: 10
        // there's no ksystemstats before login to read the boot time from, so roll the tank
        // conditions from the date instead of waiting for the sensor to time out
        Component.onCompleted: rollConditions(Math.floor(Date.now() / 86400000))
    }
}
