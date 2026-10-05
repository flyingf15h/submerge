import QtQuick 2.15

// Separable Gaussian blur of a small texture. The glows and the out-of-focus fish are soft
// enough to be blurred at a fraction of screen resolution and stretched back up, which costs
// a tiny fraction of a full-resolution blur. `output` is the blurred texture.
Item {
    id: sb
    property variant source             // texture provider at the working resolution
    property real deviation: 3          // in texels of the working resolution
    readonly property alias output: vTex

    readonly property string shader: "
        varying highp vec2 qt_TexCoord0;
        uniform sampler2D source;
        uniform highp vec2 dir;
        uniform highp float deviation;
        uniform lowp float qt_Opacity;
        void main() {
            highp float k = -0.5 / (deviation * deviation);
            lowp vec4 sum = vec4(0.0);
            highp float wsum = 0.0;
            for (int i = -10; i <= 10; i++) {
                highp float fi = float(i);
                highp float w = exp(fi * fi * k);
                sum += texture2D(source, qt_TexCoord0 + dir * fi) * w;
                wsum += w;
            }
            gl_FragColor = sum / wsum * qt_Opacity;
        }"

    ShaderEffect {
        id: hPass
        width: sb.width; height: sb.height
        visible: false
        property variant source: sb.source
        property vector2d dir: Qt.vector2d(1 / Math.max(1, width), 0)
        property real deviation: sb.deviation
        fragmentShader: sb.shader
    }
    ShaderEffectSource { id: hTex; sourceItem: hPass; hideSource: true; visible: false; smooth: true }
    ShaderEffect {
        id: vPass
        width: sb.width; height: sb.height
        visible: false
        property variant source: hTex
        property vector2d dir: Qt.vector2d(0, 1 / Math.max(1, height))
        property real deviation: sb.deviation
        fragmentShader: sb.shader
    }
    ShaderEffectSource { id: vTex; sourceItem: vPass; hideSource: true; visible: false; smooth: true }
}
