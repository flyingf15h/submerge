import QtQuick 2.15
import QtGraphicalEffects 1.15

// Stand-in for a Qt 6 MultiEffect used as a layer effect with only a centred shadow (and
// optionally brightness): a blurred, tinted copy of the alpha drawn under the source.
Item {
    id: fx
    property variant source
    property color shadowColor: "black"
    property real shadowBlur: 1.0       // 0..1 of blurMax, like MultiEffect
    property real shadowOpacity: 1.0
    property real shadowScale: 1.0
    property real blurMax: 32
    property real brightness: 0

    // MultiEffect's blur spreads further than GaussianBlur's default deviation (radius / 3.3),
    // so use a deviation of half the blur size and a kernel wide enough to hold it
    readonly property real spread: shadowBlur * blurMax
    readonly property int radius: Math.round(spread * 1.5)

    GaussianBlur {
        id: blur
        anchors.fill: parent
        source: fx.source
        radius: fx.radius
        samples: fx.radius * 2 + 1
        deviation: fx.spread / 2
        visible: false
    }
    ShaderEffectSource {
        id: blurTex
        sourceItem: blur
        hideSource: true
        visible: false
    }
    ShaderEffect {
        anchors.fill: parent
        property variant source: fx.source
        property variant shadow: blurTex
        property color shadowColor: fx.shadowColor
        property real shadowOpacity: fx.shadowOpacity
        property real shadowScale: fx.shadowScale
        property real brightness: fx.brightness
        fragmentShader: "
            varying highp vec2 qt_TexCoord0;
            uniform sampler2D source;
            uniform sampler2D shadow;
            uniform lowp vec4 shadowColor;
            uniform lowp float shadowOpacity;
            uniform highp float shadowScale;
            uniform lowp float brightness;
            uniform lowp float qt_Opacity;
            void main() {
                vec4 c = texture2D(source, qt_TexCoord0);
                c.rgb = clamp(c.rgb + brightness * c.a, 0.0, 1.0);
                vec2 su = (qt_TexCoord0 - 0.5) / shadowScale + 0.5;
                float a = texture2D(shadow, su).a * shadowOpacity;
                vec4 s = shadowColor * a;
                gl_FragColor = (c + s * (1.0 - c.a)) * qt_Opacity;
            }"
    }
}
