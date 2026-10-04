import QtQuick 2.15

// Boot screen in the same tank-monitor style as the wallpaper HUD.
Rectangle {
    id: root
    color: "#020818"
    property int stage

    readonly property real u: height / 1080
    readonly property color ink: "#eef4ff"
    readonly property color line: "#a9c2ff"

    onStageChanged: {
        if (stage === 1) intro.start();
        bar.target = Math.min(1, stage / 6);
    }

    gradient: Gradient {
        GradientStop { position: 0; color: "#06163f" }
        GradientStop { position: 1; color: "#01040e" }
    }

    Item {
        id: content
        anchors.fill: parent
        opacity: 0

        Column {
            anchors.centerIn: parent
            spacing: 18 * root.u

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "// INITIALISING TANK"
                color: root.ink
                opacity: 0.85
                font.family: "IBM Plex Mono"
                font.pixelSize: 12 * root.u
                font.letterSpacing: 3 * root.u
            }
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: title.width
                height: title.height * 1.45
                Text {
                    id: title
                    text: "SUBMERGE"
                    color: root.ink
                    font.family: "IBM Plex Sans Condensed"
                    font.weight: Font.ExtraLight
                    font.pixelSize: 84 * root.u
                    font.letterSpacing: 14 * root.u
                    transform: Scale { yScale: 1.45 }
                }
            }
            Item {
                id: bar
                property real target: 0
                property real value: 0
                Behavior on value { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
                onTargetChanged: value = target
                anchors.horizontalCenter: parent.horizontalCenter
                width: 360 * root.u
                height: 6 * root.u
                Rectangle { anchors.fill: parent; color: "transparent"; border.color: root.line; border.width: Math.max(1, root.u); opacity: 0.7 }
                Rectangle {
                    x: 2 * root.u; y: 2 * root.u
                    height: Math.max(1, parent.height - 4 * root.u)
                    width: (parent.width - 4 * root.u) * Math.max(0.04, bar.value)
                    color: root.ink
                }
            }
        }
    }

    OpacityAnimator {
        id: intro
        target: content
        from: 0; to: 1
        duration: 800
        easing.type: Easing.InOutQuad
    }
}
