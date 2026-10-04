#version 120
// One plant blade, anchored at the bottom edge, swaying more toward the tip.
attribute vec4 qt_Vertex;
attribute vec2 qt_MultiTexCoord0;
varying vec2 qt_TexCoord0;
uniform mat4 qt_Matrix;
uniform float qt_Opacity;
uniform float time;
uniform float phase;
uniform float sway;      // tip sway in item pixels
uniform float lean;      // constant lean in item pixels
uniform float fog;
uniform vec4 baseColor;
uniform vec4 tipColor;
void main() {
    qt_TexCoord0 = qt_MultiTexCoord0;
    float t = 1.0 - qt_MultiTexCoord0.y;
    vec4 p = qt_Vertex;
    p.x += (sin(time * 0.7 + phase + t * 1.8) * sway + lean) * t * t;
    gl_Position = qt_Matrix * p;
}
