#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float phase;
    float sway;
    float lean;
    float fog;
    vec4 baseColor;
    vec4 tipColor;
};
const vec3 FOG = vec3(0.012, 0.045, 0.16);
void main() {
    float t = 1.0 - qt_TexCoord0.y;
    float x = abs(qt_TexCoord0.x - 0.5) * 2.0;
    float w = 0.9 * smoothstep(1.0, 0.7, t) + 0.08;
    float a = smoothstep(w, w - 0.15, x);
    vec3 c = mix(baseColor.rgb, tipColor.rgb, t);
    c *= 0.75 + 0.35 * smoothstep(0.35, 0.0, abs(qt_TexCoord0.x - 0.45));   // light catching one side
    c = mix(c, FOG, fog);
    fragColor = vec4(c * a, a) * qt_Opacity;
}
