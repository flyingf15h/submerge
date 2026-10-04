#version 440
// One plant blade, anchored at the bottom edge, swaying more toward the tip.
layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 qt_TexCoord0;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float phase;
    float sway;      // tip sway in item pixels
    float lean;      // constant lean in item pixels
    float fog;
    vec4 baseColor;
    vec4 tipColor;
};
out gl_PerVertex { vec4 gl_Position; };
void main() {
    qt_TexCoord0 = qt_MultiTexCoord0;
    float t = 1.0 - qt_MultiTexCoord0.y;
    vec4 p = qt_Vertex;
    p.x += (sin(time * 0.7 + phase + t * 1.8) * sway + lean) * t * t;
    gl_Position = qt_Matrix * p;
}
