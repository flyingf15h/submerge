#version 440
// Bends a straight koi sprite with a travelling wave so it swims smoothly instead of swapping frames.
layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 qt_TexCoord0;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float phase;    // swim cycle, radians
    float amp;      // tail swing in item pixels
    float bend;     // how far the back half folds when turning, radians
    float headV;    // texture v of the head (anchor)
    float tailV;    // texture v of the tail tip
    float fog;      // how much the water haze covers it
    float pivotX;   // body centreline, item pixels
    float itemH;    // item height in pixels
    vec4 tint;      // rgb to recolour toward, a = how much (used for coloured shadows)
    float glitchy;  // 1 = shadow coloured in uneven cyan/magenta/blue bands
};
out gl_PerVertex { vec4 gl_Position; };
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
