import QtQuick 2.15
import QtGraphicalEffects 1.15

// Stand-in for a Qt 6 MultiEffect used as a layer effect with blur and saturation.
Item {
    id: fx
    property variant source
    property real blur: 1.0             // 0..1 of blurMax, like MultiEffect
    property real blurMax: 32
    property real saturation: 0

    HueSaturation {
        id: sat
        anchors.fill: parent
        source: fx.source
        saturation: fx.saturation
        visible: false
    }
    FastBlur {
        anchors.fill: parent
        source: sat
        radius: fx.blur * fx.blurMax
    }
}
