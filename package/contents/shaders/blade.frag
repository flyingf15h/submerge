#version 120
varying vec2 qt_TexCoord0;
uniform mat4 qt_Matrix;
uniform float qt_Opacity;
uniform float time;
uniform float phase;
uniform float sway;
uniform float lean;
uniform float fog;
uniform vec4 baseColor;
uniform vec4 tipColor;
const vec3 FOG = vec3(0.012, 0.045, 0.16);
void main() {
    float t = 1.0 - qt_TexCoord0.y;
    float x = abs(qt_TexCoord0.x - 0.5) * 2.0;
    float w = 0.9 * smoothstep(1.0, 0.7, t) + 0.08;
    float a = smoothstep(w, w - 0.15, x);
    vec3 c = mix(baseColor.rgb, tipColor.rgb, t);
    c *= 0.75 + 0.35 * smoothstep(0.35, 0.0, abs(qt_TexCoord0.x - 0.45));   // light catching one side
    c = mix(c, FOG, fog);
    gl_FragColor = vec4(c * a, a) * qt_Opacity;
}
