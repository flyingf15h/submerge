import QtQuick 2.15

// Stand-in for a Qt 6 MultiEffect used as a layer effect with only a centred shadow (and
// optionally brightness): a blurred, tinted copy of the alpha drawn under the source.
// The shadow is blurred at quarter resolution (see SoftBlur.qml); only the final composite
// runs at full size.
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
    // so use a deviation of half the blur size
    readonly property real spread: shadowBlur * blurMax
    readonly property int downscale: 4

    // 4x4 box average of the alpha in four bilinear taps
    ShaderEffect {
        id: down
        width: Math.max(1, Math.ceil(fx.width / fx.downscale))
        height: Math.max(1, Math.ceil(fx.height / fx.downscale))
        visible: false
        property variant source: fx.source
        property vector2d px: Qt.vector2d(1 / Math.max(1, fx.width), 1 / Math.max(1, fx.height))
        fragmentShader: "
            varying highp vec2 qt_TexCoord0;
            uniform sampler2D source;
            uniform highp vec2 px;
            uniform lowp float qt_Opacity;
            void main() {
                lowp float a = texture2D(source, qt_TexCoord0 + vec2(-px.x, -px.y)).a
                             + texture2D(source, qt_TexCoord0 + vec2( px.x, -px.y)).a
                             + texture2D(source, qt_TexCoord0 + vec2(-px.x,  px.y)).a
                             + texture2D(source, qt_TexCoord0 + vec2( px.x,  px.y)).a;
                gl_FragColor = vec4(0.0, 0.0, 0.0, a * 0.25);
            }"
    }
    ShaderEffectSource { id: downTex; sourceItem: down; hideSource: true; visible: false; smooth: true }
    SoftBlur {
        id: blur
        width: down.width; height: down.height
        source: downTex
        deviation: Math.max(0.5, fx.spread / 2 / fx.downscale)
    }
    ShaderEffect {
        anchors.fill: parent
        property variant source: fx.source
        property variant shadow: blur.output
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
