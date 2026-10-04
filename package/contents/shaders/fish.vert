#version 120
// Bends a straight koi sprite with a travelling wave so it swims smoothly instead of swapping frames.
attribute vec4 qt_Vertex;
attribute vec2 qt_MultiTexCoord0;
varying vec2 qt_TexCoord0;
uniform mat4 qt_Matrix;
uniform float qt_Opacity;
uniform float phase;    // swim cycle, radians
uniform float amp;      // tail swing in item pixels
uniform float bend;     // how far the back half folds when turning, radians
uniform float headV;    // texture v of the head (anchor)
uniform float tailV;    // texture v of the tail tip
uniform float fog;      // how much the water haze covers it
uniform float pivotX;   // body centreline, item pixels
uniform float itemH;    // item height in pixels
uniform vec4 tint;      // rgb to recolour toward, a = how much (used for coloured shadows)
uniform float glitchy;  // 1 = shadow coloured in uneven cyan/magenta/blue bands
void main() {
    qt_TexCoord0 = qt_MultiTexCoord0;
    float w = clamp((qt_MultiTexCoord0.y - headV) / (tailV - headV), 0.0, 1.0);
    // the head barely moves, the wave grows toward the tail and lags behind it
    float swing = sin(phase - w * 3.2) * (0.06 + w * w) - sin(phase) * 0.06;
    vec4 p = qt_Vertex;
    p.x += amp * swing;
    // turning: the back of the body folds at a hip a little behind the head and swings round
    // as one piece, so a turning fish makes an -l / l- shape instead of being skewed sideways
    float hipV = headV + (tailV - headV) * 0.36;
    vec2 hip = vec2(pivotX, hipV * itemH);
    float a = bend * smoothstep(0.36, 0.62, w);
    vec2 d = p.xy - hip;
    p.xy = hip + vec2(d.x * cos(a) - d.y * sin(a), d.x * sin(a) + d.y * cos(a));
    gl_Position = qt_Matrix * p;
}
